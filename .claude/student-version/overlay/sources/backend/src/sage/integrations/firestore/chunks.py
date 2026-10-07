"""Reads and writes on the `chunks` collection: vector search at request time, and the
writes used by utils/ingest_documents.py to populate the knowledge base.

MOCK: in-memory placeholder, nothing is persisted across process restarts and
`find_nearest_chunks` never actually ranks by similarity. Replace with a real Firestore
`find_nearest` vector query (see esercizio 12_firestore_dati) and real document writes.
"""

from sage.domain.qa.models import Chunk

_mock_store: dict[str, list[Chunk]] = {}


def find_nearest_chunks(embedding: list[float]) -> list[Chunk]:
    return []


def delete_chunks_for_source(source: str) -> None:
    """Remove existing chunks for a document, so re-running the ingestion script is safe."""
    _mock_store.pop(source, None)


def add_chunk(
    chunk_id: str,
    text: str,
    embedding: list[float],
    source: str,
    section: str | None,
    chunk_index: int,
) -> None:
    _mock_store.setdefault(source, []).append(
        Chunk(id=chunk_id, text=text, source=source, section=section, chunk_index=chunk_index)
    )
