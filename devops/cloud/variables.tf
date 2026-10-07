variable "project_id" {
  description = "ID del progetto GCP. Ogni studente lo sostituisce con il proprio (its-ict-<nome>-<cognome>)."
  type        = string
  default     = "its-ict-template-sage"
}

variable "resource_prefix" {
  description = "Prefisso dei nomi delle risorse. Vuoto (default) = progetto dedicato: le risorse usano nomi fissi e i nomi globali (bucket) derivano da project_id. Valorizzato = progetto condiviso tra più persone: ogni nome di risorsa parte da questo prefisso (its-ict-sage-<nome>-<cognome>), così nessuno collide con gli altri."
  type        = string
  default     = ""

  validation {
    condition     = var.resource_prefix == "" || can(regex("^[a-z][a-z0-9-]{2,38}[a-z0-9]$", var.resource_prefix))
    error_message = "resource_prefix: 4-40 caratteri, minuscole/cifre/trattini, inizia con una lettera e non finisce con un trattino."
  }
}

variable "region" {
  description = "Regione GCP per tutte le risorse."
  type        = string
  default     = "europe-west6"
}

variable "app_name" {
  description = "Nome base usato per Cloud Run, Artifact Registry e il service account applicativo."
  type        = string
  default     = "sage"
}

variable "docs_bucket_suffix" {
  description = "Suffisso del bucket dei documenti sorgente. Il nome finale è <project_id>-<suffisso>."
  type        = string
  default     = "sage-docs"
}

variable "firestore_collection" {
  description = "Nome della collection Firestore che contiene i chunk indicizzati."
  type        = string
  default     = "chunks"
}

variable "embedding_dimension" {
  description = "Dimensione del vettore embedding: deve corrispondere al modello configurato nel backend (SAGE_EMBEDDING_MODEL)."
  type        = number
  default     = 768
}

variable "bq_dataset" {
  description = "Dataset BigQuery per l'analytics delle domande."
  type        = string
  default     = "sage_analytics"
}

variable "bq_table" {
  description = "Tabella BigQuery in cui il backend scrive una riga per ogni domanda."
  type        = string
  default     = "question_log"
}

variable "container_image" {
  description = "Immagine container servita da Cloud Run. Un placeholder pubblico al primo apply: la pipeline di deploy (.github/workflows/deploy.yml) la aggiorna dopo la prima build."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "allow_unauthenticated" {
  description = "Se true, l'API di Sage è raggiungibile senza autenticazione (comodo per il corso). Metti false per richiedere IAM invoker su Cloud Run."
  type        = bool
  default     = true
}
