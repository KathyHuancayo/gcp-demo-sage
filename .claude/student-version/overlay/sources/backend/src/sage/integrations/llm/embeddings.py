"""Text embedding via Vertex AI.

MOCK: returns a fixed-size zero vector instead of calling Vertex AI. Replace with a real
call to the Google Gen AI SDK's `embed_content` (see esercizio 09_librerie_python).
"""

from sage.config import get_app_config


def embed_text(text: str) -> list[float]:
    config = get_app_config()
    return [0.0] * config.embedding_dimension
