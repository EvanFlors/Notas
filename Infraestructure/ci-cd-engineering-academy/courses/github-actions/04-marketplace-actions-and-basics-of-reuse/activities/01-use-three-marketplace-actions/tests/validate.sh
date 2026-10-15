#!/usr/bin/env bash
# Validate gha-04-01-use-three-marketplace-actions.
#
# NOTE: deliberately no `set -o pipefail`. Several checks pipe long producers
# (find/grep over YAML files) into `grep -q` which can emit SIGPIPE (exit 141)
# and would be mis-reported as failures.
# Also: no `mapfile` / `readarray` so this stays bash-3.2 compatible (macOS).

BASE="${1:-${BASE_DIR:-/tmp/gha-04-01-use-three-marketplace-actions}}"
WF_DIR="$BASE/repo/.github/workflows"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating under $BASE =="

if [ ! -d "$WF_DIR" ]; then
  echo "FAIL: $WF_DIR does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# List workflow files
find "$WF_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort > "$TMP/wf_files.txt"
wf_count=$(wc -l < "$TMP/wf_files.txt" | tr -d ' ')

if [ "$wf_count" -eq 0 ]; then
  note_fail "no hay workflow files en $WF_DIR"
fi

# Check 1: YAML parseable
yaml_ok=1
if [ "$wf_count" -gt 0 ]; then
  while IFS= read -r f; do
    if ! python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$f" 2>/dev/null; then
      note_fail "YAML inválido: $f"
      yaml_ok=0
    fi
  done < "$TMP/wf_files.txt"
  if [ "$yaml_ok" = "1" ]; then
    note_ok "todos los workflow YAML cargan sin error ($wf_count archivo(s))"
  fi
fi

# Collect uses: lines
: > "$TMP/uses.txt"
if [ "$wf_count" -gt 0 ]; then
  while IFS= read -r f; do
    grep -hE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^[:space:]]+' "$f" 2>/dev/null >> "$TMP/uses.txt" || true
  done < "$TMP/wf_files.txt"
fi
uses_count=$(wc -l < "$TMP/uses.txt" | tr -d ' ')

# Check 2: at least 3 uses:
if [ "$uses_count" -ge 3 ]; then
  note_ok "hay $uses_count líneas de 'uses:' (>= 3)"
else
  note_fail "solo hay $uses_count 'uses:' (se requieren >= 3)"
fi

# Check 3: distinct owner/repo across uses: lines
distinct_repos=$(sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//' "$TMP/uses.txt" \
                 | awk -F'@' '{print $1}' | sort -u | grep -c . || true)
if [ "$distinct_repos" -ge 3 ]; then
  note_ok "hay $distinct_repos owner/repo distintos (>= 3)"
else
  note_fail "solo hay $distinct_repos owner/repo distintos (se requieren >= 3)"
fi

# Check 4: at least one actions/checkout
if grep -qE 'uses:[[:space:]]*actions/checkout@' "$TMP/uses.txt"; then
  note_ok "se usa actions/checkout"
else
  note_fail "no se usa actions/checkout (requerido)"
fi

# Check 5: every uses: pinned to 40-hex SHA
bad_pin=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  rest="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//')"
  case "$rest" in
    ./*|docker://*)
      bad_pin=1
      report+="         ↳ no permitido en esta actividad: '$rest'\n"
      continue
      ;;
  esac
  ref="$(printf '%s' "$rest" | awk -F'@' '{print $2}' | awk '{print $1}')"
  if ! printf '%s' "$ref" | grep -qE '^[0-9a-f]{40}$'; then
    bad_pin=1
    report+="         ↳ no es SHA40: '$rest'\n"
  fi
done < "$TMP/uses.txt"
if [ "$uses_count" -gt 0 ] && [ "$bad_pin" -eq 0 ]; then
  note_ok "todas las 'uses:' están pinneadas a SHA de 40 chars"
else
  note_fail "al menos una 'uses:' no está pinneada a SHA de 40 chars"
fi

# Check 6: inline comment # vX.Y.Z
bad_comment=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  rest="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//')"
  case "$rest" in
    ./*|docker://*) continue ;;
  esac
  if ! printf '%s' "$rest" | grep -qE '@[0-9a-f]{40}[[:space:]]+#[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+'; then
    bad_comment=1
    report+="         ↳ sin comentario # vX.Y.Z: '$rest'\n"
  fi
done < "$TMP/uses.txt"
if [ "$uses_count" -gt 0 ] && [ "$bad_comment" -eq 0 ]; then
  note_ok "todas las 'uses:' llevan comentario '# vX.Y.Z' en la misma línea"
else
  note_fail "al menos una 'uses:' no tiene comentario '# vX.Y.Z'"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
