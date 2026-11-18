"""Reads and writes on the `chunks` collection: vector search at request time, and the
writes used by utils/ingest_documents.py to populate the knowledge base.
"""

from datetime import UTC, datetime

from google.cloud.firestore_v1.base_vector_query import DistanceMeasure
from google.cloud.firestore_v1.vector import Vector

from sage.config import get_app_config
from sage.domain.qa.models import Chunk
from sage.integrations.firestore.client import get_firestore_client


def find_nearest_chunks(embedding: list[float]) -> list[Chunk]:
    config = get_app_config()
    collection = get_firestore_client().collection(config.firestore_collection)

    query = collection.find_nearest(
        vector_field="embedding",
        query_vector=Vector(embedding),
        distance_measure=DistanceMeasure.COSINE,
        limit=config.top_k,
    )

    return [
        Chunk(
            id=doc.id,
            text=doc.get("text"),
            source=doc.get("source"),
            section=doc.get("section"),
            chunk_index=doc.get("chunk_index"),
        )
        for doc in query.stream()
    ]


def delete_chunks_for_source(source: str) -> None:
    """Remove existing chunks for a document, so re-running the ingestion script is safe."""
    config = get_app_config()
    collection = get_firestore_client().collection(config.firestore_collection)

    for doc in collection.where("source", "==", source).stream():
        doc.reference.delete()


def add_chunk(
    chunk_id: str,
    text: str,
    embedding: list[float],
    source: str,
    section: str | None,
    chunk_index: int,
) -> None:
    config = get_app_config()
    collection = get_firestore_client().collection(config.firestore_collection)

    collection.document(chunk_id).set(
        {
            "text": text,
            "embedding": Vector(embedding),
            "source": source,
            "section": section,
            "chunk_index": chunk_index,
            "created_at": datetime.now(UTC),
        }
    )
