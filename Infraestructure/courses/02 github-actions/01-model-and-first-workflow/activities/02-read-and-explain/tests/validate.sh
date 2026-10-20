#!/usr/bin/env bash
# Validate gha-01-02-read-and-explain.
#
# NOTE: deliberately NO `set -o pipefail`. Many checks pipe long-producing
# commands into `grep -q`; pipefail would surface spurious SIGPIPE (exit 141)
# on the producer when grep exits early.

BASE="${1:-${BASE_DIR:-/tmp/gha-01-read-and-explain}}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ANSWERS="$BASE/ANSWERS.md"
WF="$BASE/workflow-under-review.yml"
WF_REF="$SCRIPT_DIR/starter/workflow-under-review.yml"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating gha-01-02-read-and-explain under $BASE =="

if [ ! -f "$ANSWERS" ]; then
  echo "FAIL: $ANSWERS no existe. Ejecuta starter/bootstrap.sh primero." >&2
  exit 1
fi
if [ ! -f "$WF" ]; then
  echo "FAIL: $WF no existe. Ejecuta starter/bootstrap.sh primero." >&2
  exit 1
fi

# ---- Check 0: workflow intact (hash match with starter) ----
if [ -f "$WF_REF" ]; then
  h1="$(shasum -a 256 "$WF" | awk '{print $1}')"
  h2="$(shasum -a 256 "$WF_REF" | awk '{print $1}')"
  if [ "$h1" = "$h2" ]; then
    note_ok "workflow-under-review.yml intacto (no modificado)"
  else
    note_fail "workflow-under-review.yml fue modificado (no debes editarlo)"
  fi
fi

# Helpers
section_body() {
  local q="$1"
  # Print lines after the "## $q" header until next ## header or EOF
  awk -v q="$q" '
    $0 ~ "^## "q"[[:space:]]*$" { capture=1; next }
    /^## / { if (capture) exit }
    capture { print }
  ' "$ANSWERS"
}

has_heading() {
  local q="$1"
  grep -Eq "^## ${q}[[:space:]]*\$" "$ANSWERS"
}

contains_any() {
  # args: body, regex1, regex2, ...
  local body="$1"; shift
  for pat in "$@"; do
    if printf '%s' "$body" | grep -Eiq "$pat"; then
      return 0
    fi
  done
  return 1
}

contains_all() {
  local body="$1"; shift
  for pat in "$@"; do
    if ! printf '%s' "$body" | grep -Eiq "$pat"; then
      return 1
    fi
  done
  return 0
}

# ---- Headings present ----
for q in Q1 Q2 Q3 Q4 Q5 Q6; do
  if has_heading "$q"; then
    note_ok "ANSWERS.md tiene heading '## $q'"
  else
    note_fail "ANSWERS.md NO tiene heading '## $q'"
  fi
done

# ---- Q1 — push + pull_request + main; 1 vs 1 (push to main triggers 1; PR to main triggers 1) ----
body="$(section_body Q1)"
if [ -n "$body" ]; then
  if contains_all "$body" '\bpush\b' '\bpull[_ -]request\b' '\bmain\b'; then
    note_ok "Q1 menciona push, pull_request y main"
  else
    note_fail "Q1 debe mencionar: push, pull_request, main"
  fi
fi

# ---- Q2 — needs: publish depende de build; corren en secuencia; si build falla, publish no corre ----
body="$(section_body Q2)"
if [ -n "$body" ]; then
  if contains_all "$body" '\bneeds\b|\bdepend|\bsecuenc|\border' '\bbuild\b' '\bpublish\b'; then
    note_ok "Q2 identifica relación de dependencia build→publish"
  else
    note_fail "Q2 debe explicar needs/dependencia entre build y publish"
  fi
else
  note_fail "Q2 vacío"
fi

# ---- Q3 — publish sin checkout = workspace vacío; es bug para este caso ----
body="$(section_body Q3)"
if [ -n "$body" ]; then
  if contains_any "$body" 'workspace' 'vac[ií]o' 'empty' 'sin[ -]c[óo]digo' 'no.*clona' 'no.*checkout' 'otro runner|otra vm|otra m[áa]quina|distinta vm'; then
    if contains_any "$body" 'bug|error|problem|antipattern|incorrect|falla|no funcion'; then
      note_ok "Q3 explica que sin checkout no hay workspace y es un bug"
    else
      note_fail "Q3 debe calificar que la ausencia de checkout aquí es un bug/antipattern"
    fi
  else
    note_fail "Q3 debe explicar que sin checkout el workspace está vacío (otra VM, no comparten disco)"
  fi
else
  note_fail "Q3 vacío"
fi

# ---- Q4 — 3 steps del build: uses, uses, run ----
body="$(section_body Q4)"
if [ -n "$body" ]; then
  # Look for 2 "uses" labels and 1 "run" label
  uses_count="$(printf '%s' "$body" | grep -Eoi '\buses\b' | wc -l | tr -d ' ')"
  run_count="$(printf '%s' "$body" | grep -Eoi '\brun\b' | wc -l | tr -d ' ')"
  if [ "$uses_count" -ge 2 ] && [ "$run_count" -ge 1 ]; then
    if contains_any "$body" 'checkout' && contains_any "$body" 'setup[- ]python|python'; then
      note_ok "Q4 clasifica 2 uses (checkout + setup-python) y 1 run (build)"
    else
      note_fail "Q4 debe mencionar actions/checkout y setup-python explícitamente"
    fi
  else
    note_fail "Q4 debe etiquetar al menos 2 'uses' y 1 'run' (encontrados: uses=$uses_count, run=$run_count)"
  fi
else
  note_fail "Q4 vacío"
fi

# ---- Q5 — contexto github / runner agent / payload del evento ----
body="$(section_body Q5)"
if [ -n "$body" ]; then
  if contains_any "$body" 'contexto\s*github|github\s*context|runner|payload|evento|variables?\s*de\s*entorno|env(ironment)?\s*var'; then
    note_ok "Q5 refiere al contexto github / runner / payload"
  else
    note_fail "Q5 debe mencionar contexto github, runner, o payload del evento"
  fi
else
  note_fail "Q5 vacío"
fi

# ---- Q6 — re-run usa el YAML del commit disparador, no main ----
body="$(section_body Q6)"
if [ -n "$body" ]; then
  if contains_any "$body" 'commit\s*disparador|disparador|original|mismo\s*commit|sha\s*(del\s*)?run|same\s*sha|triggering\s*commit|workflow\s*(de|del)\s*(ese|aquel|original)|not\s*main|no.*main'; then
    note_ok "Q6 identifica que re-run usa el YAML del commit disparador"
  else
    note_fail "Q6 debe explicar que re-run usa el YAML del commit disparador (no 'main' actual)"
  fi
else
  note_fail "Q6 vacío"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
