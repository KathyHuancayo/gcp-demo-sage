"""Unit tests for prompt building and the Cloud Storage instructions — no GCP calls."""

from unittest.mock import patch

from google.api_core.exceptions import NotFound

from sage.domain.qa.generation import build_prompt, generate_answer
from sage.domain.qa.models import Chunk
from sage.integrations.storage.instructions import read_instructions

_CHUNK = Chunk(id="a-0", text="Sage usa Firestore.", source="a.md", section=None, chunk_index=0)
_INSTRUCTIONS = "# Istruzioni aggiuntive\n\nRispondi come Dante."


def test_prompt_without_instructions_is_unchanged() -> None:
    assert build_prompt("Cos'è Sage?", [_CHUNK]) == build_prompt("Cos'è Sage?", [_CHUNK], "")


def test_instructions_are_appended_after_the_grounded_prompt() -> None:
    base = build_prompt("Cos'è Sage?", [_CHUNK])

    prompt = build_prompt("Cos'è Sage?", [_CHUNK], _INSTRUCTIONS)

    assert prompt.startswith(base.rstrip())
    assert prompt.rstrip().endswith("Rispondi come Dante.")
    assert "[a.md] Sage usa Firestore." in prompt


async def test_generate_answer_reads_instructions_on_every_call() -> None:
    sent: list[str] = []

    async def fake_generate(prompt: str) -> str:
        sent.append(prompt)
        return "ok"

    with (
        patch("sage.domain.qa.generation.read_instructions", return_value=_INSTRUCTIONS) as read,
        patch("sage.domain.qa.generation.generate_text", fake_generate),
    ):
        await generate_answer("q1", [_CHUNK])
        await generate_answer("q2", [_CHUNK])

    assert read.call_count == 2  # nessuna cache: il file si rilegge a ogni richiesta
    assert all("Rispondi come Dante." in prompt for prompt in sent)


def test_read_instructions_returns_empty_string_when_file_is_missing() -> None:
    with patch("sage.integrations.storage.instructions.get_storage_client") as client:
        client.return_value.bucket.return_value.blob.return_value.download_as_text.side_effect = (
            NotFound("no such object")
        )

        assert read_instructions() == ""
