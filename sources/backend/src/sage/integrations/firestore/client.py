"""Firestore client factory."""

from functools import lru_cache

from google.cloud import firestore

from sage.config import get_app_config


@lru_cache
def get_firestore_client() -> firestore.Client:
    config = get_app_config()
    return firestore.Client(project=config.project_id, database=config.firestore_database)
