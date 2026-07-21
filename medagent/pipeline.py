"""MED AGENT pipeline orchestration + CLI.

Chains Agent 1 -> 2 -> 3 -> 4, with the Supervisor validating each stage before it may
advance. Each agent receives only the previous agent's output (the raw text is only ever
seen by Agent 1), preserving the privacy boundary from the spec.

Run:
    python -m medagent.pipeline --input "I'm 35, had chest pain since this morning..."
    python -m medagent.pipeline --interactive
    python -m medagent.pipeline --input-file case.txt --json
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from typing import Optional

from medagent.agents import (
    run_agent1, run_agent2, run_agent3, run_agent4, agent1_json,
)
from medagent.ollama_client import OllamaClient
from medagent.supervisor import Supervisor

# RAG (Retrieval-Augmented Generation) — imported lazily to avoid hard dependency
_RAG_RETRIEVER = None  # module-level singleton, initialised on first use

def _get_rag_retriever():
    """Return the RAG retriever singleton, initialising it on first call."""
    global _RAG_RETRIEVER
    if _RAG_RETRIEVER is None:
        try:
            from medagent.rag.retriever import RAGRetriever
            _RAG_RETRIEVER = RAGRetriever()
        except Exception:
            # RAG is optional — pipeline continues without it if unavailable
            _RAG_RETRIEVER = _NoopRAG()
    return _RAG_RETRIEVER


class _NoopRAG:
    """Fallback when RAG is unavailable — always returns empty context."""
    def retrieve(self, clinical_summary: str) -> str:
        return ""
    @property
    def available(self):
        return False

DEFAULT_MODEL = "qwen2.5:1.5b"
MAX_FAILS_BEFORE_HALT = 2


@dataclass
class StageResult:
    agent: str
    output: str
    supervisor: dict
    attempts: int


@dataclass
class PipelineResult:
    stages: list = field(default_factory=list)
    halted: bool = False
    halt_reason: str = ""
    beta: bool = False  # True when the pipeline continued past validation failures (lenient mode)


def run_pipeline(
    client: OllamaClient,
    supervisor: Supervisor,
    raw_text: str,
    *,
    extract_model: str = DEFAULT_MODEL,
    analyzer_model: str = DEFAULT_MODEL,
    verbose: bool = True,
    lenient: bool = False,
    use_rag: bool = True,
) -> PipelineResult:
    result = PipelineResult()

    # Initialise RAG retriever if enabled
    rag = _get_rag_retriever() if use_rag else None
    if rag and rag.available and verbose:
        print("  [RAG] Diagnosis knowledge base loaded.", file=sys.stderr)

    # (agent_label, model, runner, current_input)
    steps = [
        ("agent_1", extract_model, lambda txt, corr: run_agent1(client, extract_model, txt, corr), raw_text),
        ("agent_2", extract_model, lambda txt, corr: run_agent2(client, extract_model, txt, corr), None),
        ("agent_3", analyzer_model, lambda txt, corr: run_agent3(client, analyzer_model, txt, corr), None),
        ("agent_4", analyzer_model, lambda txt, corr: run_agent4(client, analyzer_model, txt, corr), None),
    ]

    context: dict = {"raw_text": raw_text, "agent3_text": ""}
    previous_output = raw_text  # becomes Agent 1 output, then Agent 2 input, etc.
    feed = raw_text
    rag_context: str = ""  # RAG context to inject before Agent 3

    for idx, (agent, model, runner, _ignored) in enumerate(steps):
        attempts = 0
        correction = ""

        # ── RAG step: after Agent 2 passes, search the knowledge base ──
        if agent == "agent_3" and rag is not None and rag.available and feed:
            rag_context = rag.retrieve(feed)
            if rag_context and verbose:
                print("  [RAG] Retrieved diagnosis candidates for Agent 3.", file=sys.stderr)

        while True:
            attempts += 1
            # Inject RAG context into Agent 3's runner
            if agent == "agent_3" and rag_context:
                output = run_agent3(client, model, feed, correction, rag_context=rag_context)
            else:
                output = runner(feed, correction)
            sup = supervisor.validate(agent, output, context=context)
            result.stages.append(StageResult(agent, output, sup, attempts))

            if sup["status"] == "PASS":
                break

            if verbose:
                print(
                    f"  [Supervisor] {agent} FAIL (attempt {attempts}): "
                    f"{'; '.join(sup['issues'])}",
                    file=sys.stderr,
                )

            if attempts >= MAX_FAILS_BEFORE_HALT:
                if lenient:
                    # Beta mode: keep the (unvalidated) output but flag it so the UI can
                    # label it clearly as limited-accuracy, and continue the pipeline.
                    result.beta = True
                    if verbose:
                        print(
                            f"  [Supervisor] {agent} FAILED twice -- continuing in BETA "
                            f"(unvalidated) mode.",
                            file=sys.stderr,
                        )
                    break
                result.halted = True
                result.halt_reason = (
                    "This case requires direct human clinical review -- automated pipeline "
                    "could not produce a safe, compliant output."
                )
                if verbose:
                    print(f"\nHALTED: {result.halt_reason}", file=sys.stderr)
                return result

            correction = "Validation issues to fix:\n- " + "\n- ".join(sup["issues"])

        # Advance the feed for the next agent
        if agent == "agent_1":
            context["agent1_json"] = output
            feed = output
        elif agent == "agent_2":
            feed = output
        elif agent == "agent_3":
            context["agent3_text"] = output
            feed = output
        elif agent == "agent_4":
            feed = output

    return result


def extract_history(
    client: OllamaClient,
    supervisor: Supervisor,
    raw_text: str,
    *,
    extract_model: str = DEFAULT_MODEL,
    verbose: bool = True,
) -> dict:
    """Run only Agent 1 (de-identifying history extractor) + Supervisor.

    Used by the lab-report / record ingestion flow where we only need the structured,
    de-identified extraction rather than a full differential.
    """
    output = run_agent1(client, extract_model, raw_text)
    sup = supervisor.validate("agent_1", output, context={"raw_text": raw_text})
    return {"output": output, "json": agent1_json(output), "supervisor": sup}


def _print_human(result: PipelineResult) -> None:
    if result.halted:
        print("\n" + "=" * 70)
        print("PIPELINE HALTED — DIRECT HUMAN CLINICAL REVIEW REQUIRED")
        print("=" * 70)
        print(result.halt_reason)
        return

    print("\n" + "=" * 70)
    print("MED AGENT — VALIDATED PIPELINE OUTPUT")
    print("=" * 70)
    for stage in result.stages:
        print(f"\n----- {stage.agent.upper()} (validated in {stage.attempts} attempt(s)) -----")
        print(stage.output)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="MED AGENT clinical pipeline (Ollama-backed).")
    parser.add_argument("--input", help="Raw patient text to analyze.")
    parser.add_argument("--input-file", help="Path to a text file with raw patient text.")
    parser.add_argument("--interactive", action="store_true", help="Prompt for text at runtime.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model for Agents 1/2 (extraction).")
    parser.add_argument(
        "--analyzer-model", default=None,
        help="Model for Agents 3/4 (defaults to --model). Use a larger model for better reasoning.",
    )
    parser.add_argument("--host", default="http://localhost:11434", help="Ollama base URL.")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON report.")
    parser.add_argument(
        "--beta", action="store_true",
        help="Lenient mode: continue past validation failures, flagging output as BETA "
             "(limited accuracy) instead of halting. For use with weaker local models.",
    )
    parser.add_argument(
        "--no-rag", action="store_true",
        help="Disable RAG (Retrieval-Augmented Generation) diagnosis knowledge base lookup.",
    )
    args = parser.parse_args(argv)

    if args.interactive:
        raw_text = input("Enter patient description (end with Ctrl+Z / Ctrl+D on an empty line):\n")
    elif args.input_file:
        with open(args.input_file, "r", encoding="utf-8") as fh:
            raw_text = fh.read()
    elif args.input:
        raw_text = args.input
    else:
        parser.error("Provide --input, --input-file, or --interactive.")
        return 2

    analyzer_model = args.analyzer_model or args.model
    client = OllamaClient(base_url=args.host)
    supervisor = Supervisor(client=client, model=args.model)

    if not client.is_model_available(args.model):
        print(
            f"Model '{args.model}' not found in Ollama. Pull it with: ollama pull {args.model}",
            file=sys.stderr,
        )
        return 1

    result = run_pipeline(
        client, supervisor, raw_text,
        extract_model=args.model, analyzer_model=analyzer_model,
        verbose=not args.json, lenient=args.beta, use_rag=not args.no_rag,
    )

    if args.json:
        report = {
            "halted": result.halted,
            "halt_reason": result.halt_reason,
            "beta": result.beta,
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
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        _print_human(result)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
