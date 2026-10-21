# Repository Docker per le immagini dell'API di Sage, popolato dalla pipeline di deploy
# (.github/workflows/deploy.yml), separata dalla pipeline Terraform.
resource "google_artifact_registry_repository" "sage" {
  project       = var.project_id
  location      = var.region
  repository_id = local.app_name
  format        = "DOCKER"
  description   = "Immagini container dell'API di Sage"

  depends_on = [google_project_service.apis]
}

# Servizio HTTP stateless: riceve la domanda, fa retrieval su Firestore, chiama l'LLM,
# risponde. Nessuna orchestrazione multi-componente, quindi niente GKE: Cloud Run basta.
resource "google_cloud_run_v2_service" "sage" {
  project  = var.project_id
  name     = local.app_name
  location = var.region

  template {
    service_account = google_service_account.sage_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.container_image

      ports {
        container_port = 8080
      }

      env {
        name  = "SAGE_FIRESTORE_COLLECTION"
        value = var.firestore_collection
      }
      env {
        name  = "SAGE_BQ_DATASET"
        value = var.bq_dataset
      }
      env {
        name  = "SAGE_BQ_TABLE"
        value = var.bq_table
      }
    }
  }

  # L'immagine viene aggiornata da .github/workflows/deploy.yml (gcloud run deploy), non
  # da Terraform: senza questo, ogni apply riporterebbe il servizio al placeholder.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      # Il blocco scaling a livello di servizio è valorizzato dall'API (0) ma non da noi: senza
      # questo ogni plan propone di toglierlo.
      scaling,
      # Valorizzati da `gcloud run deploy` (deploy.yml), non da Terraform.
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.apis]
}

# Pubblico di default per semplicità didattica. Per richiedere autenticazione IAM
# (roles/run.invoker sui soli account autorizzati), imposta allow_unauthenticated = false
# in terraform.tfvars e ri-applica: è uno degli esercizi del corso.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.sage.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

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
