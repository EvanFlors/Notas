#!/usr/bin/env bash
# Structural validation for sec-05-02-reduce-cves-by-base-swap.
# Checks the 3 Dockerfiles, COUNTS.md and ADR.md.
# Executable checks (docker/jq scans) SKIP gracefully if the tools are missing.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-05-base-swap}"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Student must create it."
  exit 1
fi

# ---------- app.py ----------
if [ -f "$BASE/app.py" ]; then
  echo "  OK   app.py exists"
else
  echo "  FAIL app.py missing (same app across all 3 variants)"
  fail=$((fail+1))
fi

# ---------- Dockerfiles ----------
check_dockerfile() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if [ ! -f "$f" ]; then
    echo "  FAIL $f missing"
    fail=$((fail+1))
    return
  fi
  echo "  OK   $(basename "$f") exists"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $(basename "$f") uses base $label"
  else
    echo "  FAIL $(basename "$f") does not use expected base $label (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

check_dockerfile "$BASE/Dockerfile.v1" '^FROM[[:space:]]+python:3\.12([[:space:]]|$)' 'python:3.12'
check_dockerfile "$BASE/Dockerfile.v2" '^FROM[[:space:]]+python:3\.12-slim' 'python:3.12-slim'
# v3 accepts chainguard OR distroless fallback (per README allowance).
if [ ! -f "$BASE/Dockerfile.v3" ]; then
  echo "  FAIL Dockerfile.v3 missing"
  fail=$((fail+1))
else
  echo "  OK   Dockerfile.v3 exists"
  if grep -qE '^FROM[[:space:]]+(cgr\.dev/chainguard/python|gcr\.io/distroless/python)' "$BASE/Dockerfile.v3"; then
    echo "  OK   Dockerfile.v3 uses chainguard or distroless base"
  else
    echo "  FAIL Dockerfile.v3 does not use chainguard or distroless base"
    fail=$((fail+1))
  fi
fi

# ---------- COUNTS.md ----------
COUNTS="$BASE/COUNTS.md"
if [ ! -f "$COUNTS" ]; then
  echo "  FAIL COUNTS.md missing"
  fail=$((fail+1))
else
  echo "  OK   COUNTS.md exists"
  rows=$(grep -cE '^\|' "$COUNTS")
  if [ "$rows" -ge 5 ]; then
    echo "  OK   COUNTS.md has >=5 pipe-lines (header + separator + 3 rows)"
  else
    echo "  FAIL COUNTS.md has only $rows pipe-lines (expected >=5)"
    fail=$((fail+1))
  fi
  for v in "v1" "v2" "v3"; do
    if grep -qE "^\|[[:space:]]*${v}[[:space:]]*\|" "$COUNTS"; then
      echo "  OK   COUNTS.md has row for ${v}"
    else
      echo "  FAIL COUNTS.md missing row for ${v}"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'reducci[óo]n' "$COUNTS"; then
    echo "  OK   COUNTS.md mentions 'Reduccion'"
  else
    echo "  FAIL COUNTS.md does not mention 'Reduccion' (expected a reduction % line)"
    fail=$((fail+1))
  fi
  for sev in "CRITICAL" "HIGH" "MEDIUM"; do
    if grep -q "$sev" "$COUNTS"; then
      echo "  OK   COUNTS.md mentions $sev"
    else
      echo "  FAIL COUNTS.md does not mention $sev"
      fail=$((fail+1))
    fi
  done
fi

# ---------- ADR.md ----------
ADR="$BASE/ADR.md"
if [ ! -f "$ADR" ]; then
  echo "  FAIL ADR.md missing"
  fail=$((fail+1))
else
  echo "  OK   ADR.md exists"
  for pair in "Estado|Estado" "Contexto|Contexto" "Decisi[óo]n|Decision" "Alternativas|Alternativas" "Consecuencias|Consecuencias"; do
    pattern="${pair%|*}"
    label="${pair#*|}"
    if grep -qiE "^#+ *${pattern}" "$ADR"; then
      echo "  OK   ADR.md has '${label}' section"
    else
      echo "  FAIL ADR.md missing '${label}' section"
      fail=$((fail+1))
    fi
  done
  if grep -qi 'chainguard\|distroless\|slim' "$ADR"; then
    echo "  OK   ADR.md names at least one target base image"
  else
    echo "  FAIL ADR.md does not name any target base image (chainguard/distroless/slim)"
    fail=$((fail+1))
  fi
fi

# ---------- Optional: scan JSONs ----------
missing_scans=0
for v in v1 v2 v3; do
  if [ ! -f "$BASE/scan-$v.json" ]; then
    missing_scans=$((missing_scans+1))
  fi
done
if [ "$missing_scans" -gt 0 ]; then
  echo "  SKIP $missing_scans/3 scan-vN.json file(s) missing (docker+jq required for the executable path)"
  skipped=$((skipped+1))
else
  echo "  OK   scan-v1.json, scan-v2.json, scan-v3.json all present"
  if command -v jq >/dev/null 2>&1; then
    for v in v1 v2 v3; do
      if jq -e '.Results' "$BASE/scan-$v.json" >/dev/null 2>&1; then
        echo "  OK   scan-$v.json has a .Results key"
      else
        echo "  FAIL scan-$v.json missing .Results key or invalid JSON"
        fail=$((fail+1))
      fi
    done
  else
    echo "  SKIP jq not in PATH — cannot validate JSON structure"
    skipped=$((skipped+1))
  fi
fi

# ---------- Tool availability signals ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "  SKIP docker not in PATH (executable path skipped)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed, $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
if [ "$skipped" -gt 0 ]; then
  echo "OK (with $skipped skipped executable check(s)). Install docker+jq to run the full lab."
else
  echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
fi
exit 0
