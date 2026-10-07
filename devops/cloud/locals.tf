# Naming: unico punto in cui si decide come si chiamano le risorse.
#
# - resource_prefix vuoto  -> progetto dedicato (default): nomi fissi, nessun prefisso.
# - resource_prefix valorizzato -> progetto condiviso: tutto ciò che vive a livello di
#   progetto (e quindi potrebbe collidere con altri) porta il prefisso.
#
# Le regole di naming di GCP sono diverse per ogni servizio (trattini, underscore, limiti di
# lunghezza): per questo ogni risorsa ha un local dedicato invece di un'unica concatenazione.
locals {
  shared_project = var.resource_prefix != ""

  # Prefisso dei nomi globali (bucket): project_id se il progetto è dedicato.
  name_prefix = local.shared_project ? var.resource_prefix : var.project_id

  # Cloud Run, Artifact Registry, service account: "sage" oppure "<prefisso>-sage".
  app_name = local.shared_project ? "${var.resource_prefix}-${var.app_name}" : var.app_name

  # Firestore ammette un solo database "(default)" per progetto: in un progetto condiviso
  # ogni persona ha un database con nome proprio.
  firestore_database = local.shared_project ? var.resource_prefix : "(default)"

  # I dataset BigQuery ammettono solo lettere, cifre e underscore (niente trattini).
  bq_dataset = local.shared_project ? "${replace(var.resource_prefix, "-", "_")}_${var.bq_dataset}" : var.bq_dataset

  # account_id di un service account: massimo 30 caratteri. Se "<app_name>-run" non ci sta,
  # si tronca e si aggiunge un hash del nome completo per mantenerlo univoco e stabile.
  sage_run_account_id = (
    length("${local.app_name}-run") <= 30
    ? "${local.app_name}-run"
    : "${substr(local.app_name, 0, 17)}-${substr(md5(local.app_name), 0, 8)}-run"
  )
}
