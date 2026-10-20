#!/usr/bin/env bash
# Validate dkr-09-01-publish-and-consume-your-image.
#
# MODE=local (default): checks registry at localhost:${REGISTRY_PORT:-5000}
#                       namespace evan, repo publish-demo.
# MODE=live:            checks ghcr.io/${OWNER}/dkr-09-publish-demo.
#
# NOTE: deliberately NO `set -o pipefail`. We pipe long-producing commands
# (docker inspect, curl output, docker images) into greps that may exit early;
# pipefail would surface spurious SIGPIPE on the producer.

BASE="${1:-${BASE_DIR:-/tmp/dkr-09-publish}}"
MODE="${MODE:-local}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

PUBLISH_DIR="$BASE/publish"
DIGEST_FILE="$PUBLISH_DIR/DIGEST"
POLICY_FILE="$PUBLISH_DIR/tag-policy.md"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-09-01-publish-and-consume-your-image ($MODE) under $BASE =="

if [ ! -d "$BASE/repo/.git" ]; then
  echo "FAIL: $BASE/repo no es un repo git. Ejecuta primero starter/bootstrap.sh." >&2
  exit 1
fi

if [ "$MODE" = "local" ]; then
  REG_HOST="localhost:${REGISTRY_PORT}"
  NAMESPACE="evan"
  REPO_NAME="publish-demo"
elif [ "$MODE" = "live" ]; then
  OWNER="${OWNER:-$(gh api user -q .login 2>/dev/null || echo '')}"
  if [ -z "$OWNER" ]; then
    echo "FAIL: MODE=live requiere OWNER (o gh auth status OK). Export OWNER=<usuario>." >&2
    exit 1
  fi
  REG_HOST="ghcr.io"
  NAMESPACE="$OWNER"
  REPO_NAME="dkr-09-publish-demo"
else
  echo "FAIL: MODE desconocido '$MODE' (usa local|live)" >&2
  exit 1
fi

REF="${REG_HOST}/${NAMESPACE}/${REPO_NAME}"

# ---- Check 1: registry reachable + repo exists with 4 expected tags ----
EXPECTED_TAGS="v1.0.0 v1.0 v1"
# the sha-* tag varies; we match it by prefix.
if [ "$MODE" = "local" ]; then
  TAGS_JSON="$(curl -fsS "http://${REG_HOST}/v2/${NAMESPACE}/${REPO_NAME}/tags/list" 2>/dev/null || echo '')"
else
  # GHCR tags list is behind auth; approximate by relying on `docker image ls` + `--digests`.
  TAGS_JSON=""
fi

tags_present=""
if [ -n "$TAGS_JSON" ]; then
  tags_present="$(printf '%s' "$TAGS_JSON" | python3 -c "
import json,sys
try:
  d=json.loads(sys.stdin.read() or '{}')
  for t in (d.get('tags') or []): print(t)
except Exception:
  pass
" 2>/dev/null || true)"
else
  # Fallback: use locally present tags (requires student not to have pruned).
  tags_present="$(docker image ls --format '{{.Tag}}' "$REF" 2>/dev/null || true)"
fi

missing=""
for t in $EXPECTED_TAGS; do
  if ! printf '%s\n' "$tags_present" | grep -qx "$t"; then
    missing+="$t "
  fi
done

sha_tag_count="$(printf '%s\n' "$tags_present" | grep -c '^sha-' || true)"

if [ -z "$missing" ] && [ "$sha_tag_count" -ge 1 ]; then
  note_ok "4 tags publicados en ${REF} (v1.0.0, v1.0, v1, sha-*)"
else
  reason=""
  [ -n "$missing" ] && reason+=" faltan tags: $missing;"
  [ "$sha_tag_count" -lt 1 ] && reason+=" no hay tag sha-*;"
  note_fail "tags en ${REF}:$reason  (vistos: $(printf '%s' "$tags_present" | tr '\n' ' '))"
fi

# ---- Check 2: DIGEST file exists and is well-formed ----
if [ ! -f "$DIGEST_FILE" ]; then
  note_fail "publish/DIGEST no existe"
  digest_line=""
else
  digest_line="$(head -n1 "$DIGEST_FILE" | tr -d '[:space:]')"
  if printf '%s' "$digest_line" | grep -qE "^${REG_HOST}/${NAMESPACE}/${REPO_NAME}@sha256:[0-9a-f]{64}$"; then
    note_ok "publish/DIGEST tiene formato correcto: $digest_line"
  else
    note_fail "publish/DIGEST malformado o apunta a otro registry/repo: '$digest_line'"
    digest_line=""
  fi
fi

# ---- Check 3: digest actually resolvable from registry ----
if [ -n "$digest_line" ]; then
  if docker pull "$digest_line" >/dev/null 2>&1; then
    note_ok "pull por digest OK ($digest_line)"
  else
    note_fail "pull por digest fallo ($digest_line)"
  fi
fi

# ---- Check 4: running the digest-pinned image prints the identifier ----
if [ -n "$digest_line" ]; then
  out="$(docker run --rm "$digest_line" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "^publish-demo "; then
    note_ok "contenedor imprime cadena identificadora 'publish-demo ...'"
  else
    note_fail "contenedor NO imprimio 'publish-demo ...' (salida: $(printf '%s' "$out" | head -c 120))"
  fi
fi

# ---- Check 5: tag-policy.md exists with required sections ----
if [ ! -f "$POLICY_FILE" ]; then
  note_fail "publish/tag-policy.md no existe"
else
  missing_sec=""
  for sec in "Tags publicados" "Cual usa produccion" "Cual usan los humanos"; do
    # tolerant: '##' or '#' heading, case-insensitive, ignore accents by matching substring.
    if ! grep -qi "$sec" "$POLICY_FILE"; then
      missing_sec+="'$sec' "
    fi
  done
  if [ -z "$missing_sec" ]; then
    note_ok "tag-policy.md con las 3 secciones requeridas"
  else
    note_fail "tag-policy.md faltan secciones: $missing_sec"
  fi
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT ($MODE): $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
