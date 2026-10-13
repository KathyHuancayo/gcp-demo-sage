# Sage

Sage è l'assistente Q&A del corso ITS ICT — GCP 2026: risponde a domande in linguaggio
naturale su un insieme di documenti, usando il pattern RAG (Retrieval-Augmented
Generation). Ogni domanda è indipendente dalle altre: nessuna memoria di conversazione.

Questo repository è il **template di partenza**: uno scheletro completo e funzionante che
copi come base e adatti al tuo progetto GCP personale.

## Architettura

```
Utente ──POST /api/ask──▶ API FastAPI su Cloud Run
                                │
                    1. calcola l'embedding della domanda (Vertex AI)
                    2. cerca i chunk più simili in Firestore (vector search, find_nearest)
                    3. genera la risposta con Gemini a partire da quei chunk (Vertex AI)
                    4. logga la domanda su BigQuery (sincrono, dentro la richiesta)
                                │
                                ▼
                     { answer, sources[] }
```

| Componente | Servizio GCP | Ruolo |
|---|---|---|
| API | Cloud Run | Servizio HTTP stateless, `POST /api/ask` + `GET /health` |
| Base di conoscenza | Firestore (Native mode) | Collection `chunks`: testo + embedding + metadati, interrogata con `find_nearest` |
| LLM ed embedding | Vertex AI (Gemini) | Nessuna API key: autenticazione via ADC / service account |
| Documenti sorgente | Cloud Storage | Bucket `<project_id>-sage-docs` |
| Analytics | BigQuery | Tabella `question_log`, scritta in modo sincrono nella richiesta |
| Immagini container | Artifact Registry | Popolato dalla pipeline di deploy |

La pipeline di chunking/embedding **non gira dentro l'API**: è lo script
`sources/backend/utils/ingest_documents.py`, eseguito manualmente per popolare Firestore a
partire dai file Markdown in `sources/backend/data/`.

### Firestore e BigQuery sono opzionali

Firestore e BigQuery sono pensati per essere aggiunti **passo dopo passo**: l'API funziona
anche su Cloud Run da sola, prima ancora che quelle risorse esistano.

- Se Firestore (o la collection `chunks`) non esiste ancora, la ricerca dei chunk viene
  saltata e al modello viene passato "nessun documento disponibile" al posto del contesto:
  Gemini risponde comunque (userà la sua conoscenza generale, o dirà che non ha informazioni),
  invece di far fallire la richiesta.
- Se BigQuery (dataset/tabella) non esiste ancora, la scrittura del log viene saltata: non fa
  mai fallire la risposta all'utente.

In entrambi i casi l'evento viene loggato (livello `WARNING`) sui log di Cloud Run/Cloud
Logging, così è sempre visibile cosa sta succedendo e quale integrazione manca ancora — vedi
`sources/backend/src/sage/domain/qa/retrieval.py` e
`sources/backend/src/sage/integrations/bigquery/question_log.py`.

## Struttura del repository

```
sources/backend/    API FastAPI (Python, uv) + script di ingestion + test
  src/sage/          webapp/ (router HTTP) → domain/ (logica RAG) → integrations/ (client GCP)
  utils/              ingest_documents.py — legge data/*.md, calcola gli embedding, popola Firestore
  data/               documenti .md da indicizzare (due file di esempio inclusi)
devops/cloud/        Terraform: tutte le risorse GCP, un solo ambiente
.github/workflows/    terraform.yml (plan → approvazione → apply) e deploy.yml (build & deploy)
.github/setup/        script e runbook per il bootstrap una tantum del progetto GCP
```

## Prerequisiti

- Un progetto GCP con billing attivo, nome nella forma `its-ict-<nome>-<cognome>`
- [`gcloud` CLI](https://cloud.google.com/sdk/docs/install), autenticato (`gcloud auth login`)
- [`uv`](https://docs.astral.sh/uv/) (gestione dipendenze Python)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.9
- Docker (per build e test locali dell'immagine)
- Un account GitHub con questo repository forkato/copiato

## Cosa devi fare per rendere Sage funzionante

### 1. Crea il tuo progetto GCP

```bash
gcloud projects create its-ict-<nome>-<cognome> --name="Sage"
gcloud billing projects link its-ict-<nome>-<cognome> --billing-account=<ID_BILLING_ACCOUNT>
gcloud config set project its-ict-<nome>-<cognome>
```

> **Progetto condiviso tra più persone?** Se il progetto GCP è uno solo per tutti (invece di
> uno a testa), usa un **prefisso** per distinguere le tue risorse da quelle degli altri:
> `its-ict-sage-<nome>-<cognome>`. Vedi [Progetto dedicato o condiviso](#progetto-dedicato-o-condiviso).

### 2. Configura le variabili locali e Terraform

```bash
cp sources/backend/.env.example sources/backend/.env
cp devops/cloud/terraform.tfvars.example devops/cloud/terraform.tfvars
cp devops/cloud/backend.hcl.example devops/cloud/backend.hcl
```

In tutti e tre i file sostituisci `its-ict-sage-csp26` con il tuo project id reale
(`its-ict-<nome>-<cognome>`); in un progetto condiviso usa il progetto condiviso come
`project_id` e valorizza anche il prefisso (`SAGE_RESOURCE_PREFIX` in `.env`,
`resource_prefix` in `terraform.tfvars`, nome del bucket in `backend.hcl`). Questi tre file
sono nel `.gitignore`: restano solo sulla tua macchina/nel tuo ambiente CI, non finiscono mai nel repository.

### 3. Bootstrap una tantum del progetto GCP e delle pipeline

Segui `.github/setup/setup.md`: esegue `setup-gcp-once.sh` (crea Workload Identity
Federation + il service account usato dalle GitHub Actions, senza mai generare chiavi
statiche) e ti guida nella configurazione delle variabili del repository GitHub.

### 4. Crea l'infrastruttura con Terraform

`devops/cloud/` parte senza risorse: i file `.tf` (bucket, Firestore, BigQuery, Cloud Run,
IAM, Artifact Registry, ...) li scrivi tu, modulo per modulo, seguendo gli esercizi del
corso. Restano già pronti solo i file di configurazione (`backend.hcl`, `terraform.tfvars`,
copiati dai rispettivi `.example` al passo 2).

Una volta scritte le risorse, il flusso resta questo, in locale (oppure lanciando
manualmente il workflow `terraform.yml` — tab **Actions** del repository → *terraform* →
*Run workflow* — che fa `plan` e poi richiede un'approvazione manuale su una issue prima di
applicare):

```bash
cd devops/cloud
# <il-tuo-prefisso> = project id (progetto dedicato) oppure resource prefix (progetto condiviso)
gcloud storage buckets create gs://<il-tuo-prefisso>-tfstate \
  --project <il-tuo-project-id> --location europe-west6 --uniform-bucket-level-access

terraform init -backend-config=backend.hcl
terraform apply -var-file=terraform.tfvars
```

Vedi `devops/cloud/README.md` per il dettaglio di ogni risorsa creata.

### 5. Popola la base di conoscenza

Metti i tuoi documenti `.md` in `sources/backend/data/` (o usa quelli di esempio già presenti),
poi:

```bash
cd sources/backend
uv sync
uv run python utils/ingest_documents.py
```

Lo script chunka ogni documento, calcola l'embedding di ogni chunk con Vertex AI e lo
scrive nella collection Firestore `chunks`. Rilanciarlo dopo aver modificato un file è
sicuro: i chunk di quel documento vengono sostituiti, non duplicati.

> Su un progetto appena creato la quota Vertex AI per le richieste di embedding può essere
> molto bassa nei primi minuti (`429 RESOURCE_EXHAUSTED`): riprova dopo circa un minuto.

### 6. Avvia e testa l'API in locale

```bash
cd sources/backend
gcloud auth application-default login   # ADC: nessuna chiave, nessun secret
uv run uvicorn sage.webapp.app:app --reload
```

```bash
curl -X POST http://localhost:8000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Cos'\''è Sage?"}'
```

### 7. Build e deploy su Cloud Run

In locale:

```bash
cd sources/backend
docker build -t europe-west6-docker.pkg.dev/<il-tuo-project-id>/sage/sage:manual .
docker push europe-west6-docker.pkg.dev/<il-tuo-project-id>/sage/sage:manual
gcloud run deploy sage --project <il-tuo-project-id> --region europe-west6 \
  --image europe-west6-docker.pkg.dev/<il-tuo-project-id>/sage/sage:manual
```

Oppure lascia fare alla pipeline: un push su `main` che tocca `sources/backend/**` avvia
automaticamente `deploy.yml` (build dell'immagine, push su Artifact Registry, deploy).

Questo deploy funziona anche prima di aver creato Firestore/BigQuery con Terraform (passo 4):
Sage risponde comunque, vedi [Firestore e BigQuery sono opzionali](#firestore-e-bigquery-sono-opzionali).

### 8. Testa l'API deployata

```bash
SAGE_URL=$(gcloud run services describe sage --project <il-tuo-project-id> \
  --region europe-west6 --format='value(status.url)')

curl -X POST "$SAGE_URL/api/ask" \
  -H "Content-Type: application/json" \
  -d '{"question": "Perché Sage usa Firestore invece di un database vettoriale separato?"}'
```

## Progetto dedicato o condiviso

Il **project id** (`PROJECT_ID`) e il **prefisso dei nomi** (`RESOURCE_PREFIX`) sono due
concetti distinti, anche se in un progetto dedicato coincidono:

| | Progetto dedicato (default) | Progetto condiviso |
|---|---|---|
| `RESOURCE_PREFIX` | vuoto | `its-ict-sage-<nome>-<cognome>` |
| Bucket documenti / state | `<project_id>-sage-docs` / `<project_id>-tfstate` | `<prefisso>-sage-docs` / `<prefisso>-tfstate` |
| Cloud Run, Artifact Registry | `sage` | `<prefisso>-sage` |
| Service account runtime | `sage-run` | `<prefisso>-sage-run` (accorciato con un hash oltre i 30 caratteri) |
| Database Firestore | `(default)` | `<prefisso>` |
| Dataset BigQuery | `sage_analytics` | `<prefisso, con _ al posto di ->_sage_analytics` |
| Pool WIF e SA di CI (bootstrap) | `github-actions-pool`, `github-deployer` | derivati dal prefisso |

Dove si imposta: `SAGE_RESOURCE_PREFIX` (`sources/backend/.env`), `resource_prefix`
(`devops/cloud/terraform.tfvars`), variabile di repository GitHub `RESOURCE_PREFIX`, terzo
argomento di `setup-gcp-once.sh`. Se non è valorizzato, tutto si comporta come prima.

## Pulizia risorse

Quando hai finito, evita costi residui:

```bash
cd devops/cloud
terraform destroy -var-file=terraform.tfvars
```

Le risorse di questo template restano nel livello gratuito o quasi per un uso didattico
normale (Cloud Run scala a zero, Firestore/BigQuery hanno una soglia gratuita mensile), ma
`terraform destroy` è comunque la buona pratica a fine corso o tra un esercizio e l'altro
prolungato.

## Sviluppo del backend

```bash
cd sources/backend
uv run pytest          # test
uv run ruff check .    # lint
uv run ruff format .   # formattazione
```

La struttura del codice segue tre livelli con dipendenza a senso unico
`webapp → domain → integrations` (vedi i docstring dei rispettivi `__init__.py` per il
dettaglio): `webapp/` è il solo livello che conosce FastAPI, `domain/` contiene la logica
RAG pura, `integrations/` isola le chiamate a Vertex AI, Firestore e BigQuery.
