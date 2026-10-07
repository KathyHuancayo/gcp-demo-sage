#!/usr/bin/env bash
set -euo pipefail

# Passa dalla versione "docente" (completa, è quella su cui si lavora e si testa) alla
# versione "studenti" (stessa codebase senza le parti che gli studenti scrivono nel corso).
# Dettagli e motivazioni: .claude/student-version-diffs.md
#
#   student-version.sh status          mostra in quale versione è l'albero di lavoro
#   student-version.sh apply           trasforma l'albero di lavoro in versione studenti
#   student-version.sh restore         torna alla versione docente (git restore dei file toccati)
#   student-version.sh export <dir>    scrive la versione studenti di HEAD in <dir>, senza toccare nulla
#   student-version.sh check           controlla che manifest e overlay siano ancora coerenti
#
# La trasformazione è sempre la stessa funzione (transform) applicata a una cartella:
#   1. toglie i file elencati in student-version/remove.txt
#   2. sostituisce i file presenti in student-version/overlay/ (stesso path relativo)
#   3. nei file con marker, toglie i blocchi docente e "scopre" i blocchi studente:
#        <!-- teacher-only -->  ...  <!-- /teacher-only -->        (solo docente)
#        <!-- student-only     ...     /student-only -->           (solo studenti, commentato)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
CFG="$HERE/student-version"
MARKER_FILES=(README.md)

transform() {
  local root="$1" f
  while IFS= read -r f; do
    [[ -z "$f" || "$f" == \#* ]] && continue
    rm -f "$root/$f"
  done < "$CFG/remove.txt"

  (cd "$CFG/overlay" && find . -type f) | while IFS= read -r f; do
    mkdir -p "$root/$(dirname "$f")"
    cp "$CFG/overlay/$f" "$root/$f"
  done

  for f in "${MARKER_FILES[@]}"; do
    awk '
      /<!-- teacher-only -->/    { skip = 1; next }
      /<!-- \/teacher-only -->/  { skip = 0; next }
      skip                       { next }
      /^<!-- student-only[ ]*$/  { next }
      /^student-only -->[ ]*$/   { next }
      { print }
    ' "$root/$f" > "$root/$f.tmp"
    mv "$root/$f.tmp" "$root/$f"
  done
}

touched_paths() {
  grep -v '^\(#\|$\)' "$CFG/remove.txt"
  (cd "$CFG/overlay" && find . -type f | sed 's|^\./||')
  printf '%s\n' "${MARKER_FILES[@]}"
}

in_student_mode() { [[ ! -e "$REPO/devops/cloud/variables.tf" ]]; }

cmd="${1:-status}"
cd "$REPO"
case "$cmd" in
  status)
    if in_student_mode; then echo "versione STUDENTI (albero di lavoro trasformato)"; else echo "versione DOCENTE"; fi
    git status --short | head -20
    ;;
  apply)
    in_student_mode && { echo "già in versione studenti"; exit 0; }
    [[ -z "$(git status --porcelain -- $(touched_paths | tr '\n' ' '))" ]] || {
      echo "ci sono modifiche non committate nei file toccati: committa o stasha prima (apply le perderebbe al restore)" >&2
      exit 1
    }
    transform "$REPO"
    echo "ok: versione studenti applicata (torna indietro con: $0 restore)"
    ;;
  restore)
    git restore --source=HEAD --staged --worktree -- $(touched_paths | tr '\n' ' ')
    echo "ok: versione docente ripristinata"
    ;;
  export)
    out="${2:?Uso: $0 export <dir>}"
    mkdir -p "$out"
    git archive HEAD | tar -x -C "$out"
    transform "$out"
    rm -rf "$out/.claude/student-version" "$out/.claude/student-version.sh" "$out/.claude/student-version-diffs.md"
    echo "ok: versione studenti di $(git rev-parse --short HEAD) esportata in $out"
    ;;
  check)
    rc=0
    while IFS= read -r f; do
      [[ -z "$f" || "$f" == \#* ]] && continue
      git cat-file -e "HEAD:$f" 2>/dev/null || { echo "remove.txt: $f non esiste più in HEAD"; rc=1; }
    done < "$CFG/remove.txt"
    for f in $(cd "$CFG/overlay" && find . -type f | sed 's|^\./||'); do
      git cat-file -e "HEAD:$f" 2>/dev/null || { echo "overlay: $f non esiste più in HEAD"; rc=1; }
    done
    for f in "${MARKER_FILES[@]}"; do
      t=$(grep -c '<!-- teacher-only -->' "$f" || true); e=$(grep -c '<!-- /teacher-only -->' "$f" || true)
      [[ "$t" == "$e" ]] || { echo "$f: marker teacher-only sbilanciati ($t aperti, $e chiusi)"; rc=1; }
    done
    [[ $rc == 0 ]] && echo "ok"
    exit $rc
    ;;
  *) sed -n '5,12p' "$0"; exit 1 ;;
esac
