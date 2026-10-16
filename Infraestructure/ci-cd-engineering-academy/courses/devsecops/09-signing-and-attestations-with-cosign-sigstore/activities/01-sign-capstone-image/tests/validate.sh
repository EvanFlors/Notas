#!/usr/bin/env bash
# Structural + behavioural validation for sec-09-01-sign-capstone-image.
# Checks that run.sh produced the expected artefacts and that SIGN-LOG.md
# meets a minimal structural bar. If docker/cosign are missing, degrades to
# SKIP for the behavioural parts (artefact checks) and still validates docs.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

BASE="${1:-/tmp/sec-09-01-sign}"
fail=0
skips=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run run.sh first."
  exit 1
fi

# --- Artefactos esperados de run.sh ---
have_docker=0
have_cosign=0
command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && have_docker=1
command -v cosign >/dev/null 2>&1 && have_cosign=1

if [ "$have_docker" -eq 0 ] || [ "$have_cosign" -eq 0 ]; then
  echo "  SKIP docker/cosign no disponibles — se omiten comprobaciones de artefactos binarios."
  skips=$((skips+1))
else
  for f in "run.sh" "cosign.key" "cosign.pub" "wrong.key" "wrong.pub" "IMAGE_DIGEST"; do
    if [ -f "$BASE/$f" ]; then
      echo "  OK   artefacto presente: $f"
    else
      echo "  FAIL artefacto ausente: $f"
      fail=$((fail+1))
    fi
  done

  if [ -f "$BASE/IMAGE_DIGEST" ]; then
    if grep -qE '^sha256:[0-9a-f]{64}$' "$BASE/IMAGE_DIGEST"; then
      echo "  OK   IMAGE_DIGEST tiene formato sha256:<64 hex>"
    else
      echo "  FAIL IMAGE_DIGEST no tiene formato sha256:<64 hex>"
      fail=$((fail+1))
    fi
  fi
fi

# --- SIGN-LOG.md: siempre exigible, es prosa del alumno ---
LOG="$BASE/SIGN-LOG.md"
if [ ! -f "$LOG" ]; then
  echo "  FAIL SIGN-LOG.md ausente"
  fail=$((fail+1))
else
  echo "  OK   SIGN-LOG.md presente"
  lines=$(wc -l < "$LOG" | tr -d ' ')
  if [ "$lines" -ge 5 ]; then
    echo "  OK   SIGN-LOG.md tiene $lines líneas (>=5)"
  else
    echo "  FAIL SIGN-LOG.md tiene $lines líneas (expected >=5)"
    fail=$((fail+1))
  fi

  if grep -qiE 'integridad|integrity' "$LOG"; then
    echo "  OK   SIGN-LOG.md menciona integridad"
  else
    echo "  FAIL SIGN-LOG.md no menciona integridad"
    fail=$((fail+1))
  fi

  if grep -qiE 'autenticidad|authenticity|clave pública|pub key|pubkey' "$LOG"; then
    echo "  OK   SIGN-LOG.md menciona autenticidad / pub key"
  else
    echo "  FAIL SIGN-LOG.md no menciona autenticidad / pub key"
    fail=$((fail+1))
  fi

  if grep -qiE 'no-?repudio|non-?repudiation|rekor|transparency' "$LOG"; then
    echo "  OK   SIGN-LOG.md discute no-repudio / Rekor"
  else
    echo "  FAIL SIGN-LOG.md no discute no-repudio / Rekor"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed. ($skips skip bloque(s).)"
  echo "        Compara con solution/REFERENCE.md para autoevaluarte."
  exit 1
fi
echo "OK: estructura valida. ($skips skip bloque(s).) Compara con solution/REFERENCE.md."
exit 0
