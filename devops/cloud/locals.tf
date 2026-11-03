locals {
  # Cloud Run, Artifact Registry, service account: "<prefisso>-<app_name>".
  app_name = "${var.resource_prefix}-${var.app_name}"

  # account_id di un service account: massimo 30 caratteri. Se "<app_name>-run" non ci sta,
  # si tronca e si aggiunge un hash del nome completo per mantenerlo univoco e stabile.
  sage_run_account_id = (
    length("${local.app_name}-run") <= 30
    ? "${local.app_name}-run"
    : "${substr(local.app_name, 0, 17)}-${substr(md5(local.app_name), 0, 8)}-run"
  )
}
