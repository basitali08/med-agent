"""The four pipeline agents.

Each agent receives only the previous agent's output (Agent 1 receives the raw text),
enforcing the privacy boundary. The Supervisor validates each output before the pipeline
advances (see supervisor.py).
"""

from __future__ import annotations

from medagent.ollama_client import OllamaClient, extract_json
from medagent.prompts import (
    AGENT1_SYSTEM,
    AGENT2_SYSTEM,
    AGENT3_SYSTEM,
    AGENT4_SYSTEM,
)


def run_agent1(client: OllamaClient, model: str, raw_text: str, correction: str = "") -> str:
    prompt = (
        "Extract the structured, de-identified history from the patient text below.\n\n"
        f"PATIENT TEXT:\n{raw_text}"
    )
    if correction:
        prompt += (
            f"\n\nYour previous output failed validation. Fix it:\n{correction}"
        )
    return client.generate(model, AGENT1_SYSTEM, prompt)


def run_agent2(client: OllamaClient, model: str, agent1_json: str, correction: str = "") -> str:
    prompt = (
        "Convert the following de-identified JSON into a clinical summary.\n\n"
        f"AGENT 1 OUTPUT:\n{agent1_json}"
    )
    if correction:
        prompt += f"\n\nYour previous output failed validation. Fix it:\n{correction}"
    return client.generate(model, AGENT2_SYSTEM, prompt)


def run_agent3(client: OllamaClient, model: str, agent2_summary: str, correction: str = "", rag_context: str = "") -> str:
    prompt = (
        "Produce a ranked differential and specialty routing from this summary.\n\n"
        f"AGENT 2 OUTPUT:\n{agent2_summary}"
    )
    if rag_context:
        prompt += f"\n\n{rag_context}"
    if correction:
        prompt += f"\n\nYour previous output failed validation. Fix it:\n{correction}"
    return client.generate(model, AGENT3_SYSTEM, prompt)


def run_agent4(client: OllamaClient, model: str, agent3_diff: str, correction: str = "") -> str:
    prompt = (
        "Turn the following differential into concrete, physician-reviewed actions.\n\n"
        f"AGENT 3 OUTPUT:\n{agent3_diff}"
    )
    if correction:
        prompt += f"\n\nYour previous output failed validation. Fix it:\n{correction}"
    output = client.generate(model, AGENT4_SYSTEM, prompt)

    # Ensure mandatory disclaimer is present (small models sometimes skip it)
    disclaimer = "This output is AI-generated decision-support based on limited data. It is not a diagnosis or prescription. All recommendations must be reviewed and approved by a licensed physician before acting on them."
    if "disclaimer" not in output.lower() and "AI-generated" not in output:
        output += f"\n\nMandatory Disclaimer:\n\"{disclaimer}\""
    return output


def agent1_json(agent1_text: str) -> dict:
    """Parse Agent 1's output to JSON; callers should have passed Supervisor validation."""
    return extract_json(agent1_text)
