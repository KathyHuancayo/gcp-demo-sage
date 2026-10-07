# Bucket dei documenti sorgente di Sage. Gestito da Terraform: il suffisso "-sage-docs"
# lo distingue dai bucket creati a mano negli esercizi CLI/Console del corso, che usano
# "-manual-docs" per non entrare mai in conflitto con questa risorsa.
resource "google_storage_bucket" "sage_docs" {
  name          = "${local.name_prefix}-${var.docs_bucket_suffix}"
  project       = var.project_id
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = true # comodo in un progetto didattico usa-e-getta

  depends_on = [google_project_service.apis]
}
