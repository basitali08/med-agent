"""ChromaDB vector store wrapper for the MED AGENT diagnosis knowledge base.

Provides a thin abstraction over ChromaDB for indexing and querying diagnosis records
using vector similarity search.  ChromaDB handles embedding generation internally via
its default embedding function (onnxruntime-backed all-MiniLM-L6-v2).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

import chromadb
from chromadb.config import Settings as ChromaSettings

# Persistent storage lives alongside this module
_DEFAULT_INDEX_DIR = Path(__file__).resolve().parent / "index" / "chroma_db"
_COLLECTION_NAME = "diagnoses"


class DiagnosisVectorStore:
    """Lightweight vector store backed by ChromaDB for diagnosis retrieval."""

    def __init__(self, persist_directory: Optional[str] = None):
        self._persist_dir = str(persist_directory or _DEFAULT_INDEX_DIR)
        os.makedirs(self._persist_dir, exist_ok=True)

        self._client = chromadb.PersistentClient(
            path=self._persist_dir,
            settings=ChromaSettings(anonymized_telemetry=False),
        )
        self._collection = self._client.get_or_create_collection(
            name=_COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )

    # ------------------------------------------------------------------
    # Write
    # ------------------------------------------------------------------

    def add_diagnoses(self, records: list[dict]) -> int:
        """Bulk-add diagnosis records to the collection.

        Each record must contain at least: id, name, and a combined ``document``
        string that was produced by the indexer (see build_index.py).

        Returns the number of records successfully added.
        """
        if not records:
            return 0

        ids = [r["id"] for r in records]
        documents = [r["document"] for r in records]
        metadatas = [
            {
                "name": r.get("name", ""),
                "icd10": r.get("icd10", ""),
                "specialties": r.get("specialties", ""),
                "prevalence": r.get("prevalence", ""),
                "urgency": r.get("urgency", ""),
                "red_flags": r.get("red_flags", ""),
            }
            for r in records
        ]

        # ChromaDB has a batch limit; chunk into groups of 500
        batch_size = 500
        added = 0
        for i in range(0, len(ids), batch_size):
            chunk_ids = ids[i : i + batch_size]
            chunk_docs = documents[i : i + batch_size]
            chunk_meta = metadatas[i : i + batch_size]
            self._collection.add(
                ids=chunk_ids,
                documents=chunk_docs,
                metadatas=chunk_meta,
            )
            added += len(chunk_ids)

        return added

    def clear(self) -> None:
        """Delete the collection and recreate it empty."""
        self._client.delete_collection(_COLLECTION_NAME)
        self._collection = self._client.get_or_create_collection(
            name=_COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )

    # ------------------------------------------------------------------
    # Read
    # ------------------------------------------------------------------

    def count(self) -> int:
        """Return the number of records in the collection."""
        return self._collection.count()

    def search(self, query: str, top_k: int = 10) -> list[dict]:
        """Semantic search over the diagnosis knowledge base.

        Returns a list of dicts sorted by relevance (most relevant first).
        Each dict contains: id, name, icd10, specialties, prevalence, urgency,
        red_flags, document, and distance.
        """
        if self._collection.count() == 0:
            return []

        results = self._collection.query(
            query_texts=[query],
            n_results=min(top_k, self._collection.count()),
            include=["documents", "metadatas", "distances"],
        )

        output = []
        for i in range(len(results["ids"][0])):
            output.append(
                {
                    "id": results["ids"][0][i],
                    "document": results["documents"][0][i],
                    "distance": results["distances"][0][i],
                    **results["metadatas"][0][i],
                }
            )
        return output
