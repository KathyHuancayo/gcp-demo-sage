"""Cloud Storage client factory."""

from functools import lru_cache

from google.cloud import storage

from sage.config import get_app_config


@lru_cache
def get_storage_client() -> storage.Client:
    config = get_app_config()
    return storage.Client(project=config.project_id)
