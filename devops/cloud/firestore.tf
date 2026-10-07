# Firestore in modalità Native: contiene i chunk di documento già indicizzati con il loro
# embedding (vedi sources/backend/utils/ingest_documents.py). Nessun database vettoriale
# separato:
# l'indice sotto abilita `find_nearest` direttamente sul campo `embedding`.
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = local.firestore_database
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  # Il default del provider è ABANDON: un destroy lascerebbe il database in piedi.
  deletion_policy = "DELETE"

  depends_on = [google_project_service.apis]
}

resource "google_firestore_index" "chunks_embedding" {
  project     = var.project_id
  database    = google_firestore_database.database.name
  collection  = var.firestore_collection
  query_scope = "COLLECTION"

  fields {
    field_path = "embedding"

    vector_config {
      dimension = var.embedding_dimension
      flat {}
    }
  }
}
