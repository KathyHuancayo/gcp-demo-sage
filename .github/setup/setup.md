# Setup delle pipeline GitHub Actions

Da fare una volta sola per il tuo repository, dopo aver creato il tuo progetto GCP.

## 1. Esegui il bootstrap GCP

```bash
gcloud auth login
gcloud config set project <IL_TUO_PROJECT_ID>

./.github/setup/setup-gcp-once.sh <IL_TUO_PROJECT_ID> <tuo-utente-github>/<nome-repo>

# Progetto condiviso tra più persone: aggiungi il tuo prefisso come terzo argomento
./.github/setup/setup-gcp-once.sh <PROJECT_ID_CONDIVISO> <tuo-utente-github>/<nome-repo> its-ict-sage-<nome>-<cognome>
```

Lo script crea il Workload Identity Pool/Provider e il service account `github-deployer`
usati dalle pipeline, e stampa in output i valori da usare al passo successivo.

## 2. Configura le variabili GitHub Actions

Nel repository su GitHub: **Settings → Secrets and variables → Actions → Variables**,
aggiungi (repository variables, non secrets — non sono informazioni sensibili):

| Nome | Valore | Esempio |
|---|---|---|
| `PROJECT_ID` | Il tuo project id GCP | `its-ict-mario-rossi` |
| `PROJECT_NUMBER` | Stampato dallo script | `123456789012` |
| `RESOURCE_PREFIX` | Solo progetto condiviso: il tuo prefisso. In un progetto dedicato **non creare la variabile** | `its-ict-sage-mario-rossi` |
| `REGION` | Regione del corso | `europe-west6` |
| `WIF_PROVIDER` | Stampato dallo script | `projects/.../workloadIdentityPools/github-actions-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | Stampato dallo script | `github-deployer@its-ict-mario-rossi.iam.gserviceaccount.com` |
| `APPROVERS` | Il tuo username GitHub | `mariorossi` |

Nessun secret da configurare: l'autenticazione verso GCP è keyless (Workload Identity
Federation), e Sage non usa API key esterne (Vertex AI si autentica con Application
Default Credentials / il service account del servizio).

## 3. Permessi dei workflow

**Settings → Actions → General → Workflow permissions**: seleziona *"Read and write
permissions"* e abilita *"Allow GitHub Actions to create and approve pull requests"* — il
job `approval` di `terraform.yml` deve poter aprire una issue per il gate di approvazione.

## 4. (Consigliato) Protezione del branch main

**Settings → Branches**: aggiungi una regola su `main` che richieda una pull request prima
del merge, così ogni modifica a `devops/cloud/**` passa da una review prima di lanciare
manualmente `terraform.yml` (tab **Actions** → *Run workflow*) per il `plan` e la successiva
approvazione prima di `apply`.

> Su repository **privati** con un account GitHub Free questa regola non è disponibile
> (l'API risponde `403 Upgrade to GitHub Pro or make this repository public`): è comunque
> solo un consiglio, il resto del setup funziona lo stesso senza.

## Troubleshooting

- **I workflow non compaiono nel tab Actions / `gh workflow run` dice "workflow not found
  on the default branch"** — GitHub può impiegare qualche minuto a indicizzare workflow con
  solo `workflow_dispatch` su un repository appena creato. Un commit che tocchi direttamente
  i file in `.github/workflows/` forza la re-indicizzazione.
- **`terraform.yml` fallisce su "permission denied" (`Policy update access denied` /
  `setIamPolicy`) durante `plan` o `apply`** — il service account `github-deployer` non ha
  (o ha perso) `roles/owner`: ricontrolla il passo 4 dello script di bootstrap.
- **Il job `approval` resta bloccato** — verifica che `APPROVERS` contenga esattamente il
  tuo username GitHub (case-sensitive) e che il repository possa creare issue (passo 3).
- **`deploy.yml` fallisce su "repository not found" in Artifact Registry** — assicurati di
  aver già fatto un `terraform apply` che crea la risorsa `google_artifact_registry_repository.sage`
  prima di eseguire questa pipeline.
