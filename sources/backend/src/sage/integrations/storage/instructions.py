"""Reads the additional-instructions file (istruzioni.md) from Cloud Storage.

The file is read on EVERY request (no caching of the content): editing the file in the
bucket changes Sage's answers right away, without redeploying the service.

Like the Firestore and BigQuery integrations, a failure here (bucket or file missing, no
permissions, ...) is logged and swallowed: Sage keeps answering, just without the extra
instructions, instead of turning a working answer into a 500.
"""

import logging

from google.api_core.exceptions import GoogleAPICallError

from sage.config import get_app_config
from sage.integrations.storage.client import get_storage_client

log = logging.getLogger(__name__)


def read_instructions() -> str:
    """Return the text of the instructions file, or "" if it cannot be read."""
    config = get_app_config()
    bucket_name = config.instructions_bucket
    file_name = config.instructions_file

    try:
        blob = get_storage_client().bucket(bucket_name).blob(file_name)
        return blob.download_as_text(encoding="utf-8")
    except GoogleAPICallError:
        log.warning(
            "Impossibile leggere gs://%s/%s: rispondo senza istruzioni aggiuntive",
            bucket_name,
            file_name,
            exc_info=True,
        )
        return ""
