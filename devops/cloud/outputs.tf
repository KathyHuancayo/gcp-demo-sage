output "cloud_run_url" {
  description = "URL pubblico dell'API di Sage"
  value       = google_cloud_run_v2_service.sage.uri
}

output "docs_bucket" {
  description = "Bucket dei documenti sorgente"
  value       = google_storage_bucket.sage_docs.name
}

output "artifact_registry_repository" {
  description = "Repository Docker per le immagini dell'API"
  value       = google_artifact_registry_repository.sage.name
}

output "firestore_database" {
  description = "Database Firestore che contiene la collection dei chunk"
  value       = google_firestore_database.database.name
}

output "firestore_collection" {
  description = "Collection Firestore che contiene i chunk indicizzati"
  value       = var.firestore_collection
}

output "bigquery_table" {
  description = "Tabella BigQuery con il log delle domande"
  value       = "${var.project_id}.${local.bq_dataset}.${var.bq_table}"
}

output "cloud_run_service_name" {
  description = "Nome del servizio Cloud Run (e del repository Artifact Registry) usato dalla pipeline di deploy"
  value       = local.app_name
}

output "sage_run_service_account" {
  description = "Service account con cui gira l'API su Cloud Run"
  value       = google_service_account.sage_run.email
}
