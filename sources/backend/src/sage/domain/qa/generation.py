"""Generation step of the RAG pipeline: build the grounded prompt, call the LLM."""

import asyncio
from pathlib import Path

from sage.domain.qa.models import Chunk
from sage.integrations.llm.generate import generate_text
from sage.integrations.storage.instructions import read_instructions

_PROMPT_TEMPLATE = (Path(__file__).parent / "prompts" / "answer_prompt.txt").read_text(
    encoding="utf-8"
)
_NO_DOCUMENTS_CONTEXT = (
    "Nessun documento disponibile (base di conoscenza non ancora popolata o non configurata)."
)


def build_prompt(question: str, chunks: list[Chunk], instructions: str = "") -> str:
    context = (
        "\n\n".join(f"[{chunk.source}] {chunk.text}" for chunk in chunks)
        if chunks
        else _NO_DOCUMENTS_CONTEXT
    )
    prompt = _PROMPT_TEMPLATE.format(context=context, question=question)

    # The extra instructions are appended AFTER the grounded prompt, so they add to it
    # (e.g. a style) without replacing the retrieval rules above.
    if instructions.strip():
        prompt = f"{prompt.rstrip()}\n\n{instructions.strip()}\n"
    return prompt


async def generate_answer(question: str, chunks: list[Chunk]) -> str:
    # read_instructions uses a blocking (sync) Cloud Storage client, and is called on every
    # request on purpose: the file in the bucket is the source of truth.
    instructions = await asyncio.to_thread(read_instructions)
    prompt = build_prompt(question, chunks, instructions)
    return await generate_text(prompt)
