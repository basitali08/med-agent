"""Wraps the medagent ai_pipeline so Django can call the 4-agent + Supervisor flow."""

from medagent.ollama_client import OllamaClient
from medagent.supervisor import Supervisor
from medagent.pipeline import run_pipeline, extract_history
from django.conf import settings


def analyze_text(text, *, model=None, analyzer_model=None, host=None, beta=False, use_rag=True):
    """Run the full pipeline and return a JSON-serializable report.

    `score` from the Supervisor is the 1-10 rating (<5 FAIL, >=5 PASS).
    `beta=True` enables lenient mode (continues past validation failures, flagging the
    output as limited-accuracy) instead of the strict Supervisor halt.
    `use_rag=True` enables RAG (diagnosis knowledge base lookup) to enhance Agent 3.
    """
    model = model or settings.DEFAULT_EXTRACT_MODEL
    analyzer_model = analyzer_model or settings.DEFAULT_ANALYZER_MODEL
    host = host or settings.OLLAMA_BASE_URL

    client = OllamaClient(base_url=host)
    supervisor = Supervisor(client=client, model=model)

    if not client.is_model_available(model):
        return {
            "error": f"Model '{model}' not available at {host}. Run: ollama pull {model}",
            "stages": [],
            "halted": True,
            "beta": False,
            "halt_reason": "Model unavailable.",
        }

    result = run_pipeline(
        client, supervisor, text,
        extract_model=model, analyzer_model=analyzer_model,
        verbose=False, lenient=beta, use_rag=use_rag,
    )
    return {
        "halted": result.halted,
        "beta": result.beta,
        "halt_reason": result.halt_reason,
        "stages": [
            {
                "agent": s.agent,
                "attempts": s.attempts,
                "supervisor": s.supervisor,
                "output": s.output,
            }
            for s in result.stages
        ],
    }


def extract_lab_text(text, *, model=None, host=None):
    """Run Agent 1 (de-identifying extractor) on OCR'd/raw lab text.

    The OCR step is a phase-2 integration; this accepts already-extracted text and returns
    the de-identified structured history.
    """
    model = model or settings.DEFAULT_EXTRACT_MODEL
    host = host or settings.OLLAMA_BASE_URL
    client = OllamaClient(base_url=host)
    supervisor = Supervisor(client=client, model=model)
    if not client.is_model_available(model):
        return {"error": f"Model '{model}' not available at {host}."}
    return extract_history(client, supervisor, text, extract_model=model)
