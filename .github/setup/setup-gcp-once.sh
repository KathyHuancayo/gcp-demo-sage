#!/usr/bin/env bash
set -euo pipefail

# Bootstrap one-time: crea Workload Identity Federation + un service account CI per UN
# progetto GCP, così le pipeline GitHub Actions possono autenticarsi senza chiavi statiche
# (mai una chiave di service account salvata come secret).
#
# Uso:
#   ./setup-gcp-once.sh <PROJECT_ID> <GITHUB_OWNER>/<GITHUB_REPO> [RESOURCE_PREFIX]
#
# Esempio (progetto dedicato):
#   ./setup-gcp-once.sh its-ict-mario-rossi mario-rossi/gcp-demo-sage
#
# Esempio (progetto condiviso tra più persone: ognuno ha il proprio prefisso):
#   ./setup-gcp-once.sh its-ict-sage-csp26 mario-rossi/gcp-demo-sage its-ict-sage-mario-rossi
#
# Con RESOURCE_PREFIX valorizzato, anche pool WIF e service account CI prendono un nome
# derivato dal prefisso, così più persone possono eseguire lo script sullo stesso progetto.
# Il prefisso si può passare anche come variabile d'ambiente RESOURCE_PREFIX.
#
# Va eseguito una sola volta per progetto, da un account con i permessi per gestire IAM
# (es. il Project Owner assegnato quando crei il progetto).

PROJECT_ID="${1:?Uso: $0 <PROJECT_ID> <GITHUB_OWNER>/<GITHUB_REPO>}"
GITHUB_REPO="${2:?Uso: $0 <PROJECT_ID> <GITHUB_OWNER>/<GITHUB_REPO> [RESOURCE_PREFIX]}"
RESOURCE_PREFIX="${3:-${RESOURCE_PREFIX:-}}"

if [[ -z "$RESOURCE_PREFIX" ]]; then
  POOL_ID="github-actions-pool"
  SA_NAME="github-deployer"
else
  # Limiti GCP: id del pool 4-32 caratteri, account_id del service account 6-30. Il prefisso
  # completo non ci sta, quindi lo si tronca e si aggiunge un hash del prefisso intero
  # (deterministico: rilanciare lo script ritrova le stesse risorse).
  SHORT="$(echo "${RESOURCE_PREFIX:0:17}" | sed 's/-*$//')-$(printf '%s' "$RESOURCE_PREFIX" | sha1sum | cut -c1-6)"
  POOL_ID="${SHORT}-pool"
  SA_NAME="${SHORT}-ci"
fi
PROVIDER_ID="github-provider"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Abilito le API necessarie al bootstrap"
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  --project "$PROJECT_ID"

echo "==> Creo il Workload Identity Pool (se non esiste già)"
gcloud iam workload-identity-pools create "$POOL_ID" \
  --project "$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions" \
  || echo "    Pool già esistente, continuo"

echo "==> Creo il provider OIDC per GitHub, ristretto a questo repository"
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project "$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" \
  --display-name="GitHub provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  || echo "    Provider già esistente, continuo"

echo "==> Creo il service account usato dalle pipeline CI/CD"
gcloud iam service-accounts create "$SA_NAME" \
  --project "$PROJECT_ID" \
  --display-name="GitHub Actions deployer" \
  || echo "    Service account già esistente, continuo"

# NOTA didattica: roles/owner è volutamente ampio, per tenere semplice il bootstrap di un
# progetto usa-e-getta a uso corso. roles/editor non basta: esclude i permessi setIamPolicy
# (misura anti-escalation di GCP), necessari ai binding IAM creati da Terraform
# (devops/cloud/iam.tf, cloud_run.tf). In un progetto reale si userebbe un set di ruoli
# granulari (run.admin, artifactregistry.writer, datastore.owner, bigquery.admin,
# storage.admin, iam.serviceAccountUser, serviceusage.serviceUsageAdmin,
# resourcemanager.projectIamAdmin). Nota bene: questo è il service account che orchestra
# il deploy, non quello con cui gira l'app — quello (sage_run in devops/cloud/iam.tf) ha
# solo i permessi minimi necessari a runtime.
echo "==> Assegno roles/owner al service account CI (vedi nota nello script)"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/owner" \
  --condition=None

echo "==> Collego il service account al Workload Identity Pool"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project "$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_REPO}"

echo
echo "Fatto. Configura queste variabili nell'ambiente GitHub Actions del repository"
echo "(Settings -> Secrets and variables -> Actions -> Variables):"
echo
echo "  PROJECT_ID         = ${PROJECT_ID}"
echo "  RESOURCE_PREFIX    = ${RESOURCE_PREFIX:-<lascia la variabile non impostata>}"
echo "  PROJECT_NUMBER     = ${PROJECT_NUMBER}"
echo "  REGION             = europe-west6"
echo "  WIF_PROVIDER       = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo "  WIF_SERVICE_ACCOUNT = ${SA_EMAIL}"
echo "  APPROVERS          = <il tuo username GitHub>"
echo
echo "Vedi setup.md per il resto della configurazione."
