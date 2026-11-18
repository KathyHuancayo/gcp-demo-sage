"""Text embedding via Vertex AI."""

from sage.config import get_app_config
from sage.integrations.llm.client import get_genai_client


def embed_text(text: str) -> list[float]:
    config = get_app_config()
    client = get_genai_client()
    result = client.models.embed_content(model=config.embedding_model, contents=text)
    return result.embeddings[0].values
