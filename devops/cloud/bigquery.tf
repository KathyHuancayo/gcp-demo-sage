# Log delle domande per analytics. Scritto in modo sincrono dentro la richiesta (su Cloud Run
# la CPU è garantita solo mentre una richiesta è in corso, quindi un background task rischia
# di essere congelato prima di completare la scrittura): un problema con BigQuery viene solo
# loggato, non fa mai fallire la risposta all'utente (vedi
# sources/backend/src/sage/integrations/bigquery/question_log.py).
resource "google_bigquery_dataset" "sage_analytics" {
  project    = var.project_id
  dataset_id = local.bq_dataset
  location   = var.region

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_table" "question_log" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sage_analytics.dataset_id
  table_id   = var.bq_table

  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }

  schema = jsonencode([
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "question", type = "STRING", mode = "REQUIRED" },
    { name = "sources", type = "STRING", mode = "NULLABLE", description = "JSON array dei documenti sorgente citati nella risposta" },
    { name = "latency_ms", type = "INTEGER", mode = "NULLABLE" },
  ])
}
