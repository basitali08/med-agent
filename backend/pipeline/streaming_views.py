"""Streaming SSE endpoint for live diagnosis progress."""

import json
from django.http import StreamingHttpResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from medagent.ollama_client import OllamaClient
from medagent.supervisor import Supervisor
from medagent.pipeline import run_pipeline
from medagent.agents import run_agent1, run_agent2, run_agent3, run_agent4
from django.conf import settings


AGENT_LABELS = {
    "agent_1": "History Extractor",
    "agent_2": "Clinical Summarizer",
    "agent_3": "Clinical Analyst",
    "agent_4": "Action & Treatment",
}

AGENT_ICONS = {
    "agent_1": "🔬",
    "agent_2": "📋",
    "agent_3": "🩺",
    "agent_4": "💊",
}


class StreamAnalyzeView(APIView):
    """SSE endpoint that streams each agent stage in real-time.

    Each event has the shape:
      data: {"type": "stage_start"|"stage_output"|"stage_validated"|"pipeline_done"|"error",
             "agent": "agent_1", ...}
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        text = (request.data.get("text") or "").strip()
        if not text:
            return StreamingHttpResponse(
                _error_stream("'text' is required."),
                content_type="text/event-stream",
                status=400,
            )

        model = request.data.get("model") or settings.DEFAULT_EXTRACT_MODEL
        analyzer_model = request.data.get("analyzer_model") or settings.DEFAULT_ANALYZER_MODEL
        host = request.data.get("host") or settings.OLLAMA_BASE_URL
        beta = bool(request.data.get("beta", False))

        return StreamingHttpResponse(
            _stream_pipeline(text, model, analyzer_model, host, beta),
            content_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",
            },
        )


def _sse(event_type: str, data: dict) -> str:
    """Format a Server-Sent Event."""
    payload = json.dumps({"type": event_type, **data})
    return f"data: {payload}\n\n"


def _error_stream(message: str):
    yield _sse("error", {"message": message})


def _stream_pipeline(text, model, analyzer_model, host, beta):
    """Generator that yields SSE events for each pipeline stage."""
    client = OllamaClient(base_url=host)
    supervisor = Supervisor(client=client, model=model)

    # Check model availability
    if not client.is_model_available(model):
        yield _sse("error", {
            "message": f"Model '{model}' not available at {host}. Run: ollama pull {model}",
        })
        return

    # Pipeline config: (agent_label, model_to_use, runner_func)
    steps = [
        ("agent_1", model, lambda t, c: run_agent1(client, model, t, c)),
        ("agent_2", model, lambda t, c: run_agent2(client, model, t, c)),
        ("agent_3", analyzer_model, lambda t, c: run_agent3(client, analyzer_model, t, c)),
        ("agent_4", analyzer_model, lambda t, c: run_agent4(client, analyzer_model, t, c)),
    ]

    feed = text
    correction = ""
    context = {"raw_text": text, "agent3_text": ""}
    halted = False
    beta_mode = False
    stages = []
    max_attempts = 2

    for agent_label, model_used, runner in steps:
        attempts = 0
        stage_output = ""

        # Signal stage start
        yield _sse("stage_start", {
            "agent": agent_label,
            "name": AGENT_LABELS[agent_label],
            "icon": AGENT_ICONS[agent_label],
        })

        while True:
            attempts += 1

            # Run the agent
            try:
                output = runner(feed, correction)
            except Exception as e:
                yield _sse("error", {"message": f"{AGENT_LABELS[agent_label]} failed: {e}"})
                halted = True
                break

            # Stream the output as it arrives
            yield _sse("stage_output", {
                "agent": agent_label,
                "name": AGENT_LABELS[agent_label],
                "output": output,
                "attempt": attempts,
            })

            # Supervisor validation
            sup = supervisor.validate(agent_label, output, context=context)

            yield _sse("stage_validated", {
                "agent": agent_label,
                "name": AGENT_LABELS[agent_label],
                "status": sup["status"],
                "score": sup["score"],
                "issues": sup["issues"],
                "attempts": attempts,
            })

            stage_output = output
            stages.append({
                "agent": agent_label,
                "attempts": attempts,
                "supervisor": sup,
                "output": output,
            })

            if sup["status"] == "PASS":
                break

            if attempts >= max_attempts:
                if beta:
                    beta_mode = True
                    yield _sse("beta_fallback", {
                        "agent": agent_label,
                        "message": f"{AGENT_LABELS[agent_label]} failed validation — continuing in BETA mode.",
                    })
                    break
                else:
                    halted = True
                    yield _sse("pipeline_halted", {
                        "reason": "Pipeline halted — direct human clinical review required.",
                        "halted_agent": agent_label,
                    })
                    return

            correction = "Validation issues to fix:\n- " + "\n- ".join(sup["issues"])

        if halted:
            break

        # Advance feed
        if agent_label == "agent_1":
            context["agent1_json"] = stage_output
        elif agent_label == "agent_3":
            context["agent3_text"] = stage_output
        feed = stage_output

    yield _sse("pipeline_done", {
        "halted": halted,
        "beta": beta_mode,
        "stages": stages,
    })
