#!/usr/bin/env bash
# check-jenkinsfile.sh — validación estructural de un Jenkinsfile Declarative.
# No requiere Jenkins. Usa grep/awk sobre el fichero.
#
# Uso:  bash check-jenkinsfile.sh path/to/Jenkinsfile
#
# Reglas verificadas (ver EXAM.md § OP-task-1):
#   R1  Empieza con `pipeline {` y declara `agent none` a nivel pipeline.
#   R2  Al menos un stage usa `agent { kubernetes { yaml ... } }` multi-container (jnlp + build).
#   R3  Stages mínimos: lint, test, build, publish, deploy (case-insensitive).
#   R4  Usa `parallel` para lint y test.
#   R5  Usa `when { ... branch 'main' ... }` para gatear deploy.
#   R6  Usa `post { always ... }` con archiveArtifacts o junit.
#   R7  Usa `input` para aprobación manual y NO dentro de un `node { }`.
#   R8  Usa withCredentials o credentials('...').
#   R9  Carga Shared Library pinneada por tag/sha: @Library('name@vX.Y.Z') o @sha.

set -u

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "ERROR: pasa el path al Jenkinsfile como primer argumento." >&2
  exit 2
fi

CONTENT="$(cat "$FILE")"
PASS=0
FAIL=0

check() {
  local name="$1"; local ok="$2"; local hint="$3"
  if [[ "$ok" == "1" ]]; then
    echo "PASS  $name"
    PASS=$((PASS+1))
  else
    echo "FAIL  $name  -- $hint"
    FAIL=$((FAIL+1))
  fi
}

# R1
R1=0
grep -Eq '^\s*pipeline\s*\{' <<<"$CONTENT" && \
grep -Eq 'agent\s+none' <<<"$CONTENT" && R1=1
check "R1 pipeline { ... agent none" "$R1" \
  "Falta 'pipeline {' o 'agent none' a nivel pipeline."

# R2 agent kubernetes multi-container
R2=0
if grep -Pzoq '(?s)agent\s*\{\s*kubernetes\s*\{[^}]*yaml' <<<"$CONTENT" 2>/dev/null; then
  # count container entries in the first kubernetes block
  CONTAINERS=$(grep -cE '^\s*-\s*name:\s*' <<<"$CONTENT" || true)
  if [[ "$CONTAINERS" -ge 2 ]] && grep -Eq 'name:\s*jnlp' <<<"$CONTENT"; then
    R2=1
  fi
fi
check "R2 agent { kubernetes { yaml ... } } multi-container" "$R2" \
  "Debe haber al menos dos entradas '- name:' y una debe ser 'jnlp'."

# R3 stages mínimos
R3=0
MISSING=()
for S in lint test build publish deploy; do
  if ! grep -Eqi "stage\s*\(\s*['\"].*${S}.*['\"]\s*\)" <<<"$CONTENT"; then
    MISSING+=("$S")
  fi
done
[[ ${#MISSING[@]} -eq 0 ]] && R3=1
check "R3 stages lint/test/build/publish/deploy presentes" "$R3" \
  "Faltan stages: ${MISSING[*]:-ninguno}"

# R4 parallel
R4=0
grep -Eq 'parallel\s*\{' <<<"$CONTENT" && R4=1
check "R4 bloque parallel presente" "$R4" \
  "Lint y Test deben correr dentro de un bloque parallel { }."

# R5 when branch main
R5=0
grep -Pzoq '(?s)when\s*\{[^}]*branch\s*[\x27"]main[\x27"]' <<<"$CONTENT" 2>/dev/null && R5=1
check "R5 when { branch 'main' } gatea Deploy" "$R5" \
  "Falta un bloque when { branch 'main' } (o equivalente) alrededor del Deploy."

# R6 post always con junit o archiveArtifacts
R6=0
grep -Pzoq '(?s)post\s*\{[^}]*always\s*\{[^}]*(archiveArtifacts|junit)' <<<"$CONTENT" 2>/dev/null && R6=1
check "R6 post { always { junit|archiveArtifacts } }" "$R6" \
  "Falta post { always { junit ... } } o archiveArtifacts."

# R7 input fuera de node { }
R7=0
if grep -Eq '(^|[^A-Za-z])input\b' <<<"$CONTENT"; then
  # heurística: no debe haber 'node {' seguido de input antes del cierre
  if ! grep -Pzoq '(?s)node\s*\{[^}]*input\b' <<<"$CONTENT" 2>/dev/null; then
    R7=1
  fi
fi
check "R7 input de aprobación manual sin bloquear executor" "$R7" \
  "Debe existir un step 'input' y NO estar dentro de un 'node { ... }'."

# R8 credenciales via withCredentials o credentials('...')
R8=0
grep -Eq 'withCredentials\s*\(' <<<"$CONTENT" || \
grep -Eq "credentials\s*\(\s*['\"][^'\"]+['\"]\s*\)" <<<"$CONTENT" && R8=1
check "R8 withCredentials() o credentials('id') usados" "$R8" \
  "Las credenciales deben inyectarse con withCredentials o environment { X = credentials('id') }."

# R9 @Library pinned
R9=0
grep -Eq "@Library\s*\(\s*['\"][A-Za-z0-9_.-]+@[A-Za-z0-9_.\-]+['\"]\s*\)" <<<"$CONTENT" && R9=1
check "R9 @Library('name@vX.Y.Z') pinneada" "$R9" \
  "Debe cargar una Shared Library con pin: @Library('platform-lib@v1.4.2')."

echo
echo "Resultado: $PASS pass, $FAIL fail"
[[ "$FAIL" -eq 0 ]]
