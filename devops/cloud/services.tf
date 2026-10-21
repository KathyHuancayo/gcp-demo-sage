locals {
  required_apis = [
    "run.googleapis.com",              # Cloud Run
    "artifactregistry.googleapis.com", # Artifact Registry (equivalente GCP di ECR)
    "iam.googleapis.com",              # IAM / service account
    "iamcredentials.googleapis.com",   # Workload Identity Federation (pipeline GitHub)
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "aiplatform.googleapis.com", # Vertex AI (Gemini)
    "storage.googleapis.com",    # Bucket dei documenti
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  # Non disabilitare le API quando la risorsa viene distrutta.
  disable_on_destroy = false
}
