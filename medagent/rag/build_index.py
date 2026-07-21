"""Build (or rebuild) the ChromaDB diagnosis knowledge base index.

Usage:
    python -m medagent.rag.build_index          # Build from default data
    python -m medagent.rag.build_index --rebuild # Clear and rebuild
    python -m medagent.rag.build_index --stats   # Show collection stats
"""

from __future__ import annotations

import argparse
import sys
import time

from medagent.rag.diagnosis_data import DIAGNOSIS_DATABASE
from medagent.rag.vector_store import DiagnosisVectorStore


def _build_document(record: dict) -> str:
    """Combine record fields into a single embeddable document string.

    The document includes the condition description, symptoms, risk factors,
    and demographics — everything an embedding model needs to find semantic
    matches against a clinical summary.
    """
    parts = [
        f"{record['name']}: {record.get('description', '')}",
        f"Symptoms: {record.get('symptoms', '')}",
        f"Risk factors: {record.get('risk_factors', '')}",
        f"Demographics: {record.get('demographics', '')}",
    ]
    return " | ".join(p for p in parts if p)


def build(force_rebuild: bool = False) -> DiagnosisVectorStore:
    """Build or rebuild the diagnosis vector store index.

    Args:
        force_rebuild: If True, clear existing data before adding records.

    Returns:
        The populated DiagnosisVectorStore instance.
    """
    print("Initializing vector store...")
    store = DiagnosisVectorStore()

    if force_rebuild:
        print("Clearing existing index...")
        store.clear()

    existing = store.count()
    if existing > 0 and not force_rebuild:
        print(f"Index already contains {existing} records. Use --rebuild to recreate.")
        return store

    # Prepare documents
    print(f"Preparing {len(DIAGNOSIS_DATABASE)} diagnosis records...")
    records = []
    for entry in DIAGNOSIS_DATABASE:
        doc = _build_document(entry)
        records.append(
            {
                "id": entry["id"],
                "document": doc,
                "name": entry["name"],
                "icd10": entry.get("icd10", ""),
                "specialties": entry.get("specialties", ""),
                "prevalence": entry.get("prevalence", ""),
                "urgency": entry.get("urgency", ""),
                "red_flags": entry.get("red_flags", ""),
            }
        )

    # Add to vector store
    print("Adding records to ChromaDB (this may take a moment on first run)...")
    start = time.time()
    added = store.add_diagnoses(records)
    elapsed = time.time() - start

    print(f"Done! Added {added} diagnosis records in {elapsed:.1f}s")
    print(f"Total records in index: {store.count()}")

    return store


def show_stats() -> None:
    """Display statistics about the current index."""
    store = DiagnosisVectorStore()
    count = store.count()
    print(f"Diagnosis index: {count} records")
    if count == 0:
        print("  (Index is empty — run without --stats to build)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build MED AGENT diagnosis knowledge base index.")
    parser.add_argument("--rebuild", action="store_true", help="Clear and rebuild the index.")
    parser.add_argument("--stats", action="store_true", help="Show index statistics.")
    args = parser.parse_args(argv)

    if args.stats:
        show_stats()
        return 0

    build(force_rebuild=args.rebuild)
    return 0


if __name__ == "__main__":
    sys.exit(main())
