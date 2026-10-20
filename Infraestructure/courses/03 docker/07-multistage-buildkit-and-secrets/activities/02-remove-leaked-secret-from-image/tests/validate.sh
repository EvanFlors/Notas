#!/usr/bin/env bash
# Validate the learner's fix of the leaked-secret Dockerfile under
# /tmp/dkr-07-02.
#
# Checks:
#   1. Dockerfile has `# syntax=docker/dockerfile:1`.
#   2. Dockerfile does NOT contain ARG for a token-shaped name.
#   3. Dockerfile contains `--mount=type=secret`.
#   4. Image builds OK with --secret.
#   5. docker history --no-trunc does NOT contain the FAKE_TOKEN string.
#   6. FORENSIC.md exists with the 4 required sections.
#
# Note: no `set -o pipefail` on purpose — we use `grep -q` on docker output
# and SIGPIPE on the producer would spuriously flip success into failure.
# See the pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh

set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-02}"
IMG="leaky:fixed"
SECRET_FILE="/tmp/dkr-07-02-secret"
TOKEN="FAKE_TOKEN_abcdef0123456789"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

if [ ! -f "$BASE/Dockerfile" ]; then
  echo "FAIL: $BASE/Dockerfile not found. Run starter/bootstrap.sh first." >&2
  exit 1
fi

cd "$BASE"

cleanup() { rm -f "$SECRET_FILE"; }
trap cleanup EXIT

echo "== Check 1: `# syntax=docker/dockerfile:1` =="
if head -1 Dockerfile | grep -q "^# syntax=docker/dockerfile:1"; then
  note_ok "primera linea tiene '# syntax=docker/dockerfile:1'"
else
  note_fail "primera linea NO tiene '# syntax=docker/dockerfile:1'"
fi

echo "== Check 2: no ARG for token-shaped names =="
if grep -E "^ARG[[:space:]]+(API_TOKEN|GITHUB_TOKEN|GH_TOKEN|TOKEN)([[:space:]]|=|$)" Dockerfile >/dev/null 2>&1; then
  note_fail "Dockerfile aun tiene un ARG para un nombre token-shaped (ARG API_TOKEN / GITHUB_TOKEN / etc.)"
else
  note_ok "sin ARG token-shaped"
fi

echo "== Check 3: --mount=type=secret =="
if grep -E "\-\-mount=type=secret" Dockerfile >/dev/null 2>&1; then
  note_ok "Dockerfile usa --mount=type=secret"
else
  note_fail "Dockerfile NO usa --mount=type=secret"
fi

echo "== Check 4: build with --secret =="
printf '%s' "$TOKEN" > "$SECRET_FILE"
docker rmi "$IMG" >/dev/null 2>&1 || true
if DOCKER_BUILDKIT=1 docker build \
     --secret id=github_token,src="$SECRET_FILE" \
     -t "$IMG" . >/tmp/dkr-07-02-build.log 2>&1; then
  note_ok "docker build con --secret id=github_token OK"
else
  note_fail "docker build con --secret id=github_token FAIL (ver /tmp/dkr-07-02-build.log)"
  echo
  printf "%b" "$report"
  echo
  total=$((passed + failed))
  echo "RESULT: $passed/$total checks OK."
  exit 1
fi

echo "== Check 5: token NOT in docker history =="
if docker history --no-trunc "$IMG" 2>/dev/null | grep -q "$TOKEN"; then
  note_fail "token $TOKEN sigue apareciendo en docker history (hay leak)"
else
  note_ok "token NO aparece en docker history"
fi

echo "== Check 6: FORENSIC.md con las 4 secciones =="
if [ ! -f FORENSIC.md ]; then
  note_fail "FORENSIC.md no existe"
else
  missing=""
  for sec in "Reproduccion" "Causa" "Fix" "Verificacion"; do
    if ! grep -q "$sec" FORENSIC.md; then
      missing+=" $sec"
    fi
  done
  if [ -z "$missing" ]; then
    note_ok "FORENSIC.md tiene las 4 secciones"
  else
    note_fail "FORENSIC.md incompleta; faltan secciones:$missing"
  fi
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
