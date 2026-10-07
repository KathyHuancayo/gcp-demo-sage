"""Thin async wrapper around the Gemini text-generation call.

MOCK: returns a canned string instead of calling Vertex AI. Replace with a real call to
the Google Gen AI SDK's `generate_content` (see esercizio 09_librerie_python).
"""


async def generate_text(prompt: str) -> str:
    return "[MOCK] Nessun modello collegato: implementa integrations/llm/generate.py."
