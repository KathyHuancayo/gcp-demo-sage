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
