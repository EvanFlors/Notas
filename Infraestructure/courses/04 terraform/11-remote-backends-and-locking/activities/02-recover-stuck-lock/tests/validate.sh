#!/usr/bin/env bash
# Validate tf-11-02-recover-stuck-lock.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `aws ... | grep -q ...` or similar; SIGPIPE on the upstream command would
# be promoted to a pipeline failure under pipefail — a false negative.

MODE="${MODE:-local}"
WORK="${WORK_DIR:-/tmp/tf-11-02}"
LS_PORT="${LS_PORT:-4566}"
TABLE="${TABLE:-tf-lock-tf11}"
BUCKET="${BUCKET:-tf-state-tf11}"
KEY="${KEY:-tf-11-02/terraform.tfstate}"
LOCK_ID_FULL="${BUCKET}/${KEY}-md5"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v aws >/dev/null 2>&1; then
  echo "SKIP: aws CLI no instalado."
  exit 0
fi

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker/daemon ausente."
    exit 0
  fi
  if ! curl -fs "http://localhost:${LS_PORT}/_localstack/health" >/dev/null 2>&1; then
    echo "SKIP: localstack no está en :${LS_PORT}."
    exit 0
  fi
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  AWS_DDB="aws --endpoint-url=http://localhost:${LS_PORT} dynamodb"
elif [ "$MODE" = "live" ]; then
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "SKIP: credenciales AWS no disponibles."
    exit 0
  fi
  AWS_DDB="aws dynamodb"
else
  echo "ERROR: MODE debe ser 'local' o 'live'."
  exit 2
fi

echo "== Validando recuperación del lock en: $WORK (MODE=$MODE) =="

# --- 1. WORK existe ---
if [ -d "$WORK" ]; then
  ok "WORK dir $WORK existe"
else
  bad "WORK dir $WORK no existe"
fi

# --- 2. Fila de lock YA NO está en DDB ---
got="$($AWS_DDB get-item --table-name "$TABLE" \
       --key "{\"LockID\":{\"S\":\"${LOCK_ID_FULL}\"}}" \
       --output text 2>/dev/null || true)"
if [ -z "$got" ]; then
  ok "lock '$LOCK_ID_FULL' eliminado de DDB"
else
  bad "la fila de lock '$LOCK_ID_FULL' sigue en DDB — usa 'terraform force-unlock <ID>'"
fi

# --- 3. Postmortem presente y con contenido mínimo ---
pm="$WORK/postmortem.md"
if [ ! -f "$pm" ]; then
  bad "no existe $pm (copia postmortem.template.md y rellénalo)"
else
  ok "$pm existe"
  if grep -qi "force-unlock" "$pm"; then
    ok "postmortem menciona 'force-unlock'"
  else
    bad "postmortem no menciona 'force-unlock'"
  fi
  if grep -qi "LockID" "$pm"; then
    ok "postmortem documenta el LockID"
  else
    bad "postmortem no documenta el LockID"
  fi
  if grep -qi "alice\|Who" "$pm"; then
    ok "postmortem identifica al 'Who' del lock"
  else
    bad "postmortem no identifica al dueño del lock (campo Who)"
  fi
  # Comprobación anti-placeholder: al menos un bullet concreto en 'Verificaciones ANTES'.
  # Heurística: hay una línea que empieza con "- " seguida de >= 20 caracteres.
  if awk '/^- [^<].{20,}/{found=1} END{exit found?0:1}' "$pm"; then
    ok "postmortem incluye al menos una verificación con contenido real"
  else
    bad "postmortem parece vacío/placeholder — añade al menos una verificación concreta"
  fi
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
