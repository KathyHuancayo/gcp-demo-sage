variable "container_image" {
  description = "Immagine iniziale del servizio. Le release successive le pubblica la pipeline deploy.yml."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

resource "google_artifact_registry_repository" "sage" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.resource_prefix}-sage-backend"
  description   = "Immagini Docker di Sage"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}


resource "google_cloud_run_v2_service" "sage_backend" {
  project  = var.project_id
  location = var.region

  name     = "${var.resource_prefix}-sage-backend"
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

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

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
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
    }
  }

  # L'immagine reale è pubblicata dalla pipeline applicativa, non da Terraform.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.sage_run_vertex,
  ]
}

resource "google_service_account" "sage_run" {
  project      = var.project_id
  account_id   = "${var.resource_prefix}-sage-backend"
  display_name = "Sage - runtime Cloud Run"

  depends_on = [google_project_service.apis]
}

# Permesso di chiamare Vertex AI (modelli Gemini).
resource "google_project_iam_member" "sage_run_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.sage_run.email}"
}
