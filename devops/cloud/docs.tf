resource "google_storage_bucket" "sage_docs" {
  name     = "${var.resource_prefix}-sage-docs"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  force_destroy = true
}
