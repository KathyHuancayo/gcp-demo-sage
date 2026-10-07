# Service account con cui gira l'API su Cloud Run. Privilegio minimo: solo i ruoli che
# servono davvero all'app (leggere/scrivere chunk su Firestore, chiamare Vertex AI,
# scrivere righe su BigQuery) — mai roles/owner o roles/editor a runtime.
resource "google_service_account" "sage_run" {
  project      = var.project_id
  account_id   = local.sage_run_account_id
  display_name = "Sage Cloud Run runtime"
}

locals {
  sage_run_roles = [
    "roles/datastore.user",
    "roles/aiplatform.user",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
  ]
}

resource "google_project_iam_member" "sage_run" {
  for_each = toset(local.sage_run_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.sage_run.email}"
}
