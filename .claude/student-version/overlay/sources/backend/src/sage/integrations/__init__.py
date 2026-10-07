"""Adapters for external services: Vertex AI (LLM + embeddings), Firestore, BigQuery.

Main areas:
- llm: Google Gen AI SDK client, in Vertex AI mode (text generation + embeddings).
- firestore: chunk storage and vector search (find_nearest).
- bigquery: best-effort analytics logging of questions.

MOCK: all three are currently placeholder implementations (no real GCP calls) — see each
subpackage's docstring. Replace them incrementally as the corresponding course module is
covered.
"""
