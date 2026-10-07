"""Writes one row per question to BigQuery for analytics (see devops/cloud/bigquery.tf).

Called synchronously from the request path (see webapp/apis/qa/service.py) rather than as a
FastAPI background task: on Cloud Run, CPU is only guaranteed to be allocated while a request
is in flight, so a background write could be frozen or killed once the response is sent.

This integration is meant to be added incrementally: any failure here (dataset/table not
provisioned yet, no permissions, ...) should be logged and swallowed rather than propagated,
so it never turns a working answer into a 502 for the caller.

MOCK: logs to the application logger instead of writing to BigQuery. Replace with a real
`insert_rows_json` call (see esercizio 13_bigquery_analytics), keeping the same
log-and-swallow behavior described above.
"""

import logging

from sage.domain.qa.models import Chunk

log = logging.getLogger(__name__)


def log_question(question: str, chunks: list[Chunk], latency_ms: int) -> None:
    log.info(
        "[MOCK] question=%r sources=%d latency_ms=%d", question, len(chunks), latency_ms
    )
