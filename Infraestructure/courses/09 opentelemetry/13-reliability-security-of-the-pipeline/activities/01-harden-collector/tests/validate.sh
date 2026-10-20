#!/usr/bin/env bash
# Validate the 7 hardening controls on /tmp/otel13-act01/collector.yaml.
# NOTE: deliberately NO `set -o pipefail`. We pipe grep heavily and pipefail
# would surface SIGPIPE (141) when grep -q exits early.

BASE="${BASE_DIR:-/tmp/otel13-act01}"
CFG="$BASE/collector.yaml"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating otel-13-01-harden-collector =="

if [ ! -f "$CFG" ]; then
  echo "FAIL: no existe $CFG. Ejecuta starter/bootstrap.sh y edita ese archivo." >&2
  exit 1
fi

# 1. TLS server-side: receiver OTLP debe tener cert_file y key_file,
#    y NO debe tener 'insecure: true' bajo receivers.
if grep -A5 -E "^\s*(grpc|http):" "$CFG" | grep -q "cert_file"; then
  if grep -A5 -E "^\s*(grpc|http):" "$CFG" | grep -q "key_file"; then
    # Check that no 'insecure: true' lives inside a receivers block.
    # Heuristic: insecure: true should not appear above the first 'exporters:' line.
    recv_part=$(awk '/^exporters:/{exit} {print}' "$CFG")
    if echo "$recv_part" | grep -q "insecure: true"; then
      note_fail "Receiver OTLP tiene 'insecure: true' (debe quitarse para TLS)"
    else
      note_ok "TLS server-side habilitado en receiver OTLP (cert_file + key_file)"
    fi
  else
    note_fail "Receiver OTLP tiene cert_file pero no key_file"
  fi
else
  note_fail "Receiver OTLP sin cert_file (TLS server-side no configurado)"
fi

# 2. Bearer auth
if grep -q "bearertokenauth" "$CFG" && grep -q "authenticator: bearertokenauth" "$CFG"; then
  note_ok "Autenticacion Bearer configurada (extension + authenticator en receiver)"
else
  note_fail "Falta Bearer auth: declara 'bearertokenauth' en extensions y 'auth.authenticator: bearertokenauth' en receiver"
fi

# 3. memory_limiter
if grep -q "memory_limiter:" "$CFG" && grep -q "limit_mib:" "$CFG"; then
  note_ok "memory_limiter declarado con limit_mib"
else
  note_fail "Falta memory_limiter con limit_mib"
fi

# 4. batch
if grep -q "^\s*batch:" "$CFG" && grep -q "send_batch_size:" "$CFG"; then
  note_ok "batch declarado con send_batch_size"
else
  note_fail "Falta batch con send_batch_size"
fi

# 5. file_storage + sending_queue persistente
if grep -q "file_storage:" "$CFG" && grep -q "storage: file_storage" "$CFG"; then
  if grep -q "sending_queue:" "$CFG"; then
    note_ok "sending_queue persistente via file_storage"
  else
    note_fail "file_storage declarado pero sending_queue falta"
  fi
else
  note_fail "Falta file_storage extension y/o 'storage: file_storage' en sending_queue"
fi

# 6. retry_on_failure
if grep -q "retry_on_failure:" "$CFG"; then
  if grep -A3 "retry_on_failure:" "$CFG" | grep -q "enabled: true"; then
    note_ok "retry_on_failure habilitado"
  else
    note_fail "retry_on_failure declarado pero no 'enabled: true'"
  fi
else
  note_fail "Falta retry_on_failure"
fi

# 7. attributes/pii
if grep -qE "attributes/pii|attributes/scrub" "$CFG"; then
  # Must have at least one hash or delete action
  if grep -qE "action:\s*(hash|delete)" "$CFG"; then
    note_ok "PII scrubbing via attributes processor con accion hash/delete"
  else
    note_fail "attributes/pii existe pero no tiene action: hash o delete"
  fi
else
  note_fail "Falta attributes/pii processor para PII scrubbing"
fi

# Behavioral bonus: if docker available & gateway running, check auth works.
if command -v docker >/dev/null 2>&1 && docker inspect otel13-act01-gateway >/dev/null 2>&1; then
  state=$(docker inspect otel13-act01-gateway --format '{{.State.Status}}')
  if [ "$state" = "running" ]; then
    report+="  INFO -- gateway container running\n"
  else
    report+="  WARN -- gateway container existe pero no esta running (estado: $state)\n"
  fi
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/7 controles OK."
if [ "$passed" -eq 7 ] && [ "$failed" -eq 0 ]; then
  echo "== OK: 7/7 controles verificados =="
  exit 0
fi
exit 1
