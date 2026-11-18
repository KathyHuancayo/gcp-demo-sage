# Bucket con il file istruzioni.md: Sage lo legge da qui a ogni richiesta e ne aggiunge il
# contenuto al prompt (vedi sources/backend/src/sage/integrations/storage/instructions.py).
# Il file si carica a mano: gcloud storage cp istruzioni.md gs://<prefisso>-instructions/
resource "google_storage_bucket" "instructions" {
  name     = "${var.resource_prefix}-instructions"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  force_destroy = true

  depends_on = [google_project_service.apis]
}

# Il service account con cui gira Sage deve poter leggere il file (solo lettura, solo su
# questo bucket: privilegio minimo).
resource "google_storage_bucket_iam_member" "sage_run_instructions_reader" {
  bucket = google_storage_bucket.instructions.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.sage_run.email}"
}
