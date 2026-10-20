#!/usr/bin/env bash
# Validate structure of tag-strategy.md for dkr-09-02-tag-strategy-design.
# Does NOT judge the content; checks that the 9 sections exist, that each
# "Decision:" section has non-trivial content (not the TODO placeholder), and
# that the Rationale mentions >=3 key concepts.
#
# NOTE: deliberately NO `set -o pipefail`. We pipe awk output into greps that
# may exit early (SIGPIPE on the producer); pipefail would surface spurious
# failures.

BASE="${1:-${BASE_DIR:-/tmp/dkr-09-strategy}}"
FILE="$BASE/tag-strategy.md"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-09-02-tag-strategy-design under $BASE =="

if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE no existe. Ejecuta primero starter/bootstrap.sh y editalo." >&2
  exit 1
fi

# ---- Check 1: 9 required sections present (match by heading substring) ----
required_sections=(
  "Context"
  "Decision: immutable tags"
  "Decision: mutable tags"
  "Decision: production pin"
  "Decision: staging and dev pin"
  "Decision: base image rotation"
  "Decision: latest"
  "Rationale"
  "Trade-offs"
)

missing=""
for s in "${required_sections[@]}"; do
  if ! grep -qE "^##[[:space:]]+${s}[[:space:]]*$" "$FILE"; then
    missing+="'$s' "
  fi
done
if [ -z "$missing" ]; then
  note_ok "9 secciones requeridas presentes"
else
  note_fail "faltan secciones: $missing"
fi

# ---- Check 2: each 'Decision:' section has non-trivial content ----
# Extract body of each section (between its heading and the next '## ') and
# verify >= 20 non-whitespace chars AND not the exact TODO placeholder.
extract_section() {
  local title="$1"
  awk -v t="## $title" '
    $0==t { capture=1; next }
    capture && /^## / { exit }
    capture { print }
  ' "$FILE"
}

non_trivial() {
  local body="$1"
  # strip HTML comments
  local cleaned
  cleaned="$(printf '%s' "$body" | sed -E 's/<!--.*//g')"
  # count non-whitespace chars
  local chars
  chars="$(printf '%s' "$cleaned" | tr -d '[:space:]' | wc -c | tr -d ' ')"
  # reject if body is only a TODO placeholder
  if printf '%s' "$cleaned" | grep -qE '^[[:space:]]*TODO[:\.]'; then
    return 1
  fi
  if [ "$chars" -ge 20 ]; then
    return 0
  fi
  return 1
}

decision_titles=(
  "Decision: immutable tags"
  "Decision: mutable tags"
  "Decision: production pin"
  "Decision: staging and dev pin"
  "Decision: base image rotation"
  "Decision: latest"
)
empty_decisions=""
for t in "${decision_titles[@]}"; do
  body="$(extract_section "$t")"
  if ! non_trivial "$body"; then
    empty_decisions+="'$t' "
  fi
done
if [ -z "$empty_decisions" ]; then
  note_ok "6 secciones Decision tienen contenido no trivial"
else
  note_fail "secciones Decision vacias o solo TODO: $empty_decisions"
fi

# ---- Check 3: Context and Trade-offs non-trivial too ----
non_trivial_sections=""
for t in "Context" "Trade-offs" "Rationale"; do
  body="$(extract_section "$t")"
  if ! non_trivial "$body"; then
    non_trivial_sections+="'$t' "
  fi
done
if [ -z "$non_trivial_sections" ]; then
  note_ok "Context, Rationale y Trade-offs tienen contenido"
else
  note_fail "secciones vacias o solo TODO: $non_trivial_sections"
fi

# ---- Check 4: Rationale mentions >=3 key concepts ----
rationale_body="$(extract_section "Rationale")"
rationale_lower="$(printf '%s' "$rationale_body" | tr '[:upper:]' '[:lower:]')"
hits=0
matched=""
for kw in "reproducib" "trazabil" "digest" "rate-limit" "rate limit" "preview" "rollback" "soc"; do
  if printf '%s' "$rationale_lower" | grep -q "$kw"; then
    hits=$((hits+1))
    matched+="$kw, "
  fi
done
if [ "$hits" -ge 3 ]; then
  note_ok "Rationale menciona $hits conceptos clave ($matched)"
else
  note_fail "Rationale menciona solo $hits conceptos clave (se requieren >=3; busca: reproducibilidad, trazabilidad, digest, rate-limit, preview, rollback, SOC)"
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
