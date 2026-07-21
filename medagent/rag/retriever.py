"""RAG retriever — bridges the diagnosis vector store with Agent 3's prompt.

Given a clinical summary (from Agent 2), this module:
1. Searches the diagnosis knowledge base for the most similar conditions.
2. Formats the results into a structured context block that is injected into
   Agent 3's prompt, enriching its analysis with evidence-based candidates.
"""

from __future__ import annotations

import logging
from typing import Optional

from medagent.rag.vector_store import DiagnosisVectorStore

logger = logging.getLogger(__name__)

# Number of diagnosis candidates to retrieve for Agent 3
DEFAULT_TOP_K = 8


def format_rag_context(results: list[dict]) -> str:
    """Format retrieved diagnosis records into a prompt-friendly context block.

    The output is a plain-text block that will be injected into Agent 3's user
    prompt *after* the clinical summary.  It is intentionally formatted so the
    LLM can read it naturally.
    """
    if not results:
        return ""

    lines = [
        "--- MEDICAL KNOWLEDGE BASE REFERENCE ---",
        "The following diagnoses were retrieved from a curated medical knowledge base ",
        "based on symptom similarity with the clinical summary above.",
        "",
    ]

    for rank, r in enumerate(results, start=1):
        name = r.get("name", "Unknown")
        icd10 = r.get("icd10", "N/A")
        specialties = r.get("specialties", "General")
        prevalence = r.get("prevalence", "unknown")
        urgency = r.get("urgency", "routine")
        red_flags = r.get("red_flags", "none noted")
        doc = r.get("document", "")

        lines.append(f"{rank}. {name} (ICD-10: {icd10})")
        lines.append(f"   Specialties: {specialties}")
        lines.append(f"   Prevalence: {prevalence} | Urgency: {urgency}")
        lines.append(f"   Key symptoms/signs: {doc}")
        lines.append(f"   Red flags: {red_flags}")
        lines.append("")

    lines.append("--- END KNOWLEDGE BASE ---")
    lines.append("")
    lines.append(
        "INSTRUCTIONS FOR USING THIS REFERENCE:\n"
        "- These are SYMPTOM-LEVEL matches only — they do NOT account for patient history, "
        "medications, or demographics.\n"
        "- You MUST evaluate each one based on the FULL clinical picture.\n"
        "- You MAY add conditions NOT listed here if your analysis suggests them.\n"
        "- You MAY exclude conditions listed here if they don't fit the clinical picture.\n"
        "- Your clinical reasoning is PRIMARY — the knowledge base is SUPPORTING."
    )
    return "\n".join(lines)


class RAGRetriever:
    """High-level retriever that wraps the vector store and formatting logic.

    Designed to fail silently — if the vector store is unavailable or empty,
    the pipeline continues without RAG context rather than crashing.
    """

    def __init__(self, persist_directory: Optional[str] = None, top_k: int = DEFAULT_TOP_K):
        self.top_k = top_k
        self._store: Optional[DiagnosisVectorStore] = None
        try:
            self._store = DiagnosisVectorStore(persist_directory=persist_directory)
        except Exception as exc:
            logger.warning("RAG vector store unavailable: %s", exc)

    @property
    def available(self) -> bool:
        """True if the vector store exists and contains records."""
        if self._store is None:
            return False
        try:
            return self._store.count() > 0
        except Exception:
            return False

    def retrieve(self, clinical_summary: str) -> str:
        """Search the knowledge base and return a formatted context block.

        Returns an empty string if the store is unavailable, empty, or the
        query fails — the pipeline should always be able to continue without RAG.
        """
        if not self.available:
            return ""

        try:
            results = self._store.search(clinical_summary, top_k=self.top_k)
            return format_rag_context(results)
        except Exception as exc:
            logger.warning("RAG retrieval failed: %s", exc)
            return ""

    def get_stats(self) -> dict:
        """Return basic stats about the knowledge base."""
        if self._store is None:
            return {"available": False, "count": 0}
        try:
            return {"available": True, "count": self._store.count()}
        except Exception:
            return {"available": False, "count": 0}
