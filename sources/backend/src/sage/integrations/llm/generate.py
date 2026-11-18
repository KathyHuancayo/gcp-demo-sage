"""Thin async wrapper around the Gemini text-generation call (Vertex AI, via the Google Gen AI SDK).

The model comes from SAGE_CHAT_MODEL (see sage/config.py), so it can be changed without
touching the code.
"""

import asyncio

from sage.config import get_app_config
from sage.integrations.llm.client import get_genai_client


async def generate_text(prompt: str) -> str:
    config = get_app_config()
    client = get_genai_client()

    # generate_content is a blocking call: run it in a thread so it doesn't block the event loop.
    response = await asyncio.to_thread(
        client.models.generate_content,
        model=config.chat_model,
        contents=prompt,
    )

    return response.text
