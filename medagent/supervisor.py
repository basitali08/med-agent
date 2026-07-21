"""Supervisor Agent: validation + 1-10 rating layer for the MED AGENT pipeline.

Per the spec, the Supervisor is LLM + hard-coded validation rules, but the hard-coded
rules are the *authoritative* safety checks. On top of that, the Supervisor assigns every
agent output a quality/safety RATING from 1 to 10:

    score < 5  -> FAIL  (return_for_correction)
    score >= 5 -> PASS  (forward)

The final score blends the deterministic rule deductions with an LLM quality rating:
  - If hard rules found violations, the score is rule-driven (severe violations drop it
    below 5, forcing a FAIL).
  - If no hard-rule violations were found, the LLM rating decides (a clean-but-low-quality
    output can still be rejected by the LLM score).

Return shape (spec-compatible, extended with scores):
    {
      "agent_checked": "agent_1" | ... | "agent_4",
      "status": "PASS" | "FAIL",
      "score": <int 1-10>,
      "rule_score": <int 1-10>,
      "llm_score": <int 1-10 | null>,
      "issues": [str, ...],
      "action": "forward" | "return_for_correction"
    }
"""

from __future__ import annotations

import json
import re
from typing import Optional

from medagent.ollama_client import OllamaClient, extract_json
from medagent.prompts import SUPERVISOR_SCORING_SYSTEM

# --- hard-coded detection patterns ---------------------------------------------------

EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
CNIC_RE = re.compile(r"\b\d{5}-\d{7}-\d\b")
PHONE_RE = re.compile(r"(\+?92|0)\d{9,11}\b")
DOB_RE = re.compile(r"\b(dob|date of birth|born on)\b", re.IGNORECASE)

# Negative lookbehinds exclude the mandatory safe phrase "NOT a confirmed diagnosis"
# while still catching affirmative claims like "this is a confirmed diagnosis".
CERTAINTY_RE = re.compile(
    r"(?<!not a )(?<!not )"
    r"\b(100%|one hundred percent|definitely|certainly|confirmed diagnosis|"
    r"i am sure|it is certain|guaranteed)\b",
    re.IGNORECASE,
)
NUMERIC_PRECISION_RE = re.compile(r"\b\d{1,3}(\.\d+)?\s?%")  # e.g. "85%", "92.5%"

ALLOWED_LIKELIHOOD = {"high", "moderate", "low"}

REDFLAG_TRIGGER_WORDS = [
    "chest pain", "shortness of breath", "difficulty breathing", "severe bleeding",
    "sudden weakness", "sudden numbness", "slurred speech", "face droop", "severe headache",
    "unconscious", "fainting", "seizure", "stroke", "heart attack", "suicidal",
    "severe abdominal pain", "coughing blood", "vomiting blood", "severe burn",
]

DOSE_RE = re.compile(
    r"\b\d+\s?(mg|mcg|µg|ug|g|ml|l|iu|units?|tablets?|capsules?|drops?|mg/kg|mcg/kg)\b",
    re.IGNORECASE,
)

DISCLAIMER_RE = re.compile(r"not a (diagnosis|confirmed diagnosis|prescription)|AI-generated.*advisory|AI-generated.*decision-support|reviewed and approved.*physician", re.IGNORECASE)

# Deduction weights for rule violations (base score = 10).
W = {
    "invalid_json": 6,
    "missing_keys": 2,
    "pii_not_removed": 3,
    "email": 5, "cnic": 5, "phone": 5, "dob": 5, "name_in_sid": 4,
    "empty": 6, "summary_section": 2,
    "certainty": 5, "numeric_precision": 4, "bad_likelihood": 4,
    "missing_limitations": 4, "missing_redflag": 5,
    "missing_disclaimer": 6, "dosage": 6, "missing_priority": 4,
}

PASS_THRESHOLD = 5  # score >= PASS_THRESHOLD -> PASS


class Supervisor:
    def __init__(self, client: Optional[OllamaClient] = None, model: Optional[str] = None):
        self.client = client
        self.model = model
        self.use_llm = client is not None and model is not None

    # -- public API -----------------------------------------------------------------

    def validate(self, agent: str, output: str, *, context: Optional[dict] = None) -> dict:
        context = context or {}
        issues: list[tuple[str, int]] = []

        if agent == "agent_1":
            issues = self._check_agent1(output)
        elif agent == "agent_2":
            issues = self._check_agent2(output)
        elif agent == "agent_3":
            issues = self._check_agent3(output, context.get("raw_text", ""))
        elif agent == "agent_4":
            issues = self._check_agent4(output, context.get("agent3_text", ""))
        else:
            issues = [("Unknown agent label: " + agent, 6)]

        rule_score = self._rule_score(issues)
        has_violations = len(issues) > 0

        llm_score = None
        if self.use_llm:
            llm_score = self._llm_score(agent, output, context)

        # Hybrid rating:
        #  - violations present -> rule-driven score (safety first)
        #  - no violations -> LLM quality rating decides
        if has_violations:
            final_score = rule_score
        else:
            final_score = llm_score if llm_score is not None else 8

        final_score = max(1, min(10, final_score))
        status = "PASS" if final_score >= PASS_THRESHOLD else "FAIL"

        return {
            "agent_checked": agent,
            "status": status,
            "score": final_score,
            "rule_score": rule_score,
            "llm_score": llm_score,
            "issues": [text for text, _ in issues],
            "action": "forward" if status == "PASS" else "return_for_correction",
        }

    # -- scoring helpers -------------------------------------------------------------

    @staticmethod
    def _rule_score(issues: list[tuple[str, int]]) -> int:
        deduction = sum(w for _, w in issues)
        return max(1, min(10, 10 - deduction))

    def _llm_score(self, agent: str, output: str, context: dict) -> Optional[int]:
        if not (self.client and self.model):
            return None
        prompt = (
            f"Agent being rated: {agent}\n\n"
            f"Agent output:\n{output}\n\n"
            "Return ONLY JSON: {\"score\": <1-10>, \"reason\": \"...\"}."
        )
        try:
            raw = self.client.generate(self.model, SUPERVISOR_SCORING_SYSTEM, prompt,
                                       temperature=0.0, max_tokens=200)
        except Exception:
            return None
        data = extract_json(raw)
        if not data or not isinstance(data.get("score"), int):
            return None
        return max(1, min(10, data["score"]))

    # -- per-agent rule checks (return list of (issue_text, weight)) -----------------

    def _check_agent1(self, output: str) -> list[tuple[str, int]]:
        issues: list[tuple[str, int]] = []
        data = extract_json(output)
        if data is None:
            return [("Agent 1 did not return valid JSON.", W["invalid_json"])]

        required_keys = {
            "session_id", "age_bracket", "current_symptoms",
            "past_conditions", "allergies", "surgeries",
            "medications_history", "medications_current", "raw_extracted_text",
        }
        missing = required_keys - set(data.keys())
        if missing:
            for k in sorted(missing):
                issues.append((f"Agent 1 JSON missing key: {k}", W["missing_keys"]))

        # Check PII removal - name in session_id
        sid = str(data.get("session_id", ""))
        if sid and re.search(r"\b(john|mary|ali|fatima|smith|khan)\b", sid, re.IGNORECASE):
            issues.append(("Agent 1 session_id looks like a real name.", W["name_in_sid"]))

        # Check PII leaks in the output
        if EMAIL_RE.search(output):
            issues.append(("Agent 1 output contains an email address (PII leak).", W["email"]))
        if CNIC_RE.search(output):
            issues.append(("Agent 1 output contains a CNIC/national ID (PII leak).", W["cnic"]))
        if PHONE_RE.search(output):
            issues.append(("Agent 1 output contains a phone number (PII leak).", W["phone"]))
        if DOB_RE.search(output):
            issues.append(("Agent 1 output references date of birth (PII leak).", W["dob"]))
        return issues

    def _check_agent2(self, output: str) -> list[tuple[str, int]]:
        issues: list[tuple[str, int]] = []
        if not output.strip():
            return [("Agent 2 produced empty output.", W["empty"])]
        if EMAIL_RE.search(output):
            issues.append(("Agent 2 reintroduced an email address (PII).", W["email"]))
        if CNIC_RE.search(output):
            issues.append(("Agent 2 reintroduced a CNIC/national ID (PII).", W["cnic"]))
        if PHONE_RE.search(output):
            issues.append(("Agent 2 reintroduced a phone number (PII).", W["phone"]))
        # Check for clinical summary section
        if not re.search(r"Clinical Summary|Key Information|Summary\s*:", output, re.IGNORECASE):
            issues.append(("Agent 2 output missing a summary section.", W["summary_section"]))
        return issues

    def _check_agent3(self, output: str, raw_text: str) -> list[tuple[str, int]]:
        issues: list[tuple[str, int]] = []
        if not output.strip():
            return [("Agent 3 produced empty output.", W["empty"])]

        if CERTAINTY_RE.search(output):
            issues.append(("Agent 3 used certainty language (100%/definitely/confirmed).", W["certainty"]))
        if NUMERIC_PRECISION_RE.search(output):
            issues.append(("Agent 3 used fake numeric precision (e.g. '85%').", W["numeric_precision"]))

        # Check for red flags when complaint warrants them
        if any(w in raw_text.lower() for w in REDFLAG_TRIGGER_WORDS):
            if "red flag" not in output.lower():
                issues.append(("Agent 3 omitted a Red Flags section for a complaint that warrants one.", W["missing_redflag"]))
        return issues

    def _check_agent4(self, output: str, agent3_text: str) -> list[tuple[str, int]]:
        issues: list[tuple[str, int]] = []
        if not output.strip():
            return [("Agent 4 produced empty output.", W["empty"])]

        if not DISCLAIMER_RE.search(output):
            issues.append(("Agent 4 missing the mandatory disclaimer.", W["missing_disclaimer"]))

        if DOSE_RE.search(output):
            issues.append(("Agent 4 included exact dosages (medication CLASSES only).", W["dosage"]))

        if agent3_text and "red flag" in agent3_text.lower():
            if "priority action" not in output.lower():
                issues.append(("Agent 3 raised a red flag but Agent 4 has no Priority Action.", W["missing_priority"]))
        return issues
