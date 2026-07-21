"""Ollama HTTP API client wrapper.

Talks to a locally running Ollama instance (default http://localhost:11434).
No third-party Ollama SDK dependency required beyond `requests`.
"""

from __future__ import annotations

import json
from typing import Optional

import requests


class OllamaClient:
    def __init__(self, base_url: str = "http://localhost:11434", timeout: int = 300):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def generate(
        self,
        model: str,
        system: str,
        prompt: str,
        *,
        temperature: float = 0.3,
        max_tokens: int = 1500,
    ) -> str:
        """Call Ollama's /api/generate and return the model text response."""
        payload = {
            "model": model,
            "system": system,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens,
            },
        }
        try:
            resp = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=self.timeout,
            )
        except requests.exceptions.ConnectionError as exc:
            raise RuntimeError(
                "Could not reach Ollama at "
                f"{self.base_url}. Is `ollama serve` running and is `{model}` pulled?"
            ) from exc

        if resp.status_code != 200:
            raise RuntimeError(f"Ollama returned {resp.status_code}: {resp.text}")

        data = resp.json()
        return data.get("response", "").strip()

    def is_model_available(self, model: str) -> bool:
        try:
            resp = requests.get(f"{self.base_url}/api/tags", timeout=self.timeout)
        except requests.exceptions.ConnectionError:
            return False
        if resp.status_code != 200:
            return False
        models = [m["name"] for m in resp.json().get("models", [])]
        return model in models


def extract_json(text: str) -> Optional[dict]:
    """Best-effort extraction of a JSON object from model output.

    Handles fenced ```json blocks and bare JSON. Returns None if unparseable.
    """
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # drop opening fence (``` or ```json) and closing fence
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned
        if cleaned.endswith("```"):
            cleaned = cleaned[: -3]
        cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # Try to locate the outermost { ... } span.
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(cleaned[start : end + 1])
        except json.JSONDecodeError:
            return None
    return None
