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
      max_instance_count = 3
    }

    containers {
      image = var.container_image

      ports {
        container_port = 8080
      }

      env {
        name  = "SAGE_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "SAGE_REGION"
        value = var.region
      }
      env {
        name  = "SAGE_RESOURCE_PREFIX"
        value = var.resource_prefix
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
    ignore_changes = [template[0].containers[0].image]
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
