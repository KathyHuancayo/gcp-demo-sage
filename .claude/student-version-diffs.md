# Versione studenti vs versione docente

Questo repo esiste in due versioni dello stesso codice:

- **Docente** (`feat/sage-common`, poi `teacher`): completa e funzionante. Si lavora e si
  testa qui.
- **Studenti** (`main`, il branch forkato): la stessa codebase senza le parti che gli
  studenti scrivono durante il corso. Non si edita a mano: si genera.

La versione studenti deriva dalla docente con `.claude/student-version.sh`. Il commit
`6470f5d` ("Initial version") era la stessa trasformazione fatta a mano.

## Differenze

| Cosa | Docente | Studenti | Come si ottiene |
|---|---|---|---|
| `devops/cloud/*.tf` e `.terraform.lock.hcl` (13 file, incl. `locals.tf`, `variables.tf`) | presenti | assenti: li scrivono gli studenti | elencati in `student-version/remove.txt` |
| `integrations/__init__.py`, `llm/{__init__,embeddings,generate}.py` | chiamate reali a Vertex AI | mock (vettore di zeri, stringa fissa) | overlay in `student-version/overlay/` |
| `integrations/firestore/{__init__,chunks}.py` | `find_nearest` e scritture reali | store in memoria | overlay |
| `integrations/bigquery/{__init__,question_log}.py` | `insert_rows_json` reale | log su logger | overlay |
| `README.md`, passo 4 | testo "applica con Terraform" | spiega che i `.tf` vanno scritti | marker `teacher-only` / `student-only` |

Tutto il resto (workflow, script di bootstrap, `config.py`, client Firestore/BigQuery, esempi
`.example`, documentazione) è identico nelle due versioni.

## Uso

```bash
.claude/student-version.sh status         # in quale versione è l'albero di lavoro
.claude/student-version.sh apply          # albero di lavoro -> versione studenti (serve albero pulito)
.claude/student-version.sh restore        # ritorno alla versione docente
.claude/student-version.sh export <dir>   # versione studenti di HEAD in <dir>, senza toccare nulla
.claude/student-version.sh check          # manifest e overlay ancora coerenti con il codice?
```

Pubblicare agli studenti: dal branch docente, `export` in una cartella e committare quel
contenuto su `main`.

## Manutenzione

- Si modifica **sempre** la versione docente.
- Un file nuovo che gli studenti non devono vedere -> aggiungerlo a `remove.txt`.
- Un file che per gli studenti è un mock -> metterne la versione mock in
  `overlay/<stesso path>`. Se la versione docente cambia in modo rilevante, aggiornare anche
  l'overlay a mano: `check` ricorda solo se un path non esiste più.
- Testo diverso in un file condiviso (solo `README.md` oggi, vedi `MARKER_FILES` nello
  script):
  ```
  <!-- teacher-only -->  testo docente  <!-- /teacher-only -->
  <!-- student-only
  testo studenti
  student-only -->
  ```

## Cose da sapere

- Nella versione studenti non c'è `variables.tf`, quindi la variabile `resource_prefix` e le
  regole di naming (`locals.tf`) non esistono. Il README di `devops/cloud` le descrive.
- `devops/cloud/README.md` elenca ancora i file `.tf` anche nella versione studenti.
- Il file `.gitignore` ignora `.claude/*` tranne `student-version*`; l'export toglie questi
  file dalla versione studenti.
