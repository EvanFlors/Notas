#!/usr/bin/env bash
# Validate cap-04-01-build-and-compose-up.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `docker compose config | grep -q ...`; if grep matches early,
# the upstream pipeline step may receive SIGPIPE (exit 141), and pipefail would
# turn that into a false negative.
set -eu

STAGE_DIR="${STAGE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1"$'\n'; passed=$((passed+1)); }
bad() { report+="  FAIL $1"$'\n'; failed=$((failed+1)); }

echo "== Validando $STAGE_DIR =="

# --- 1. Archivos esperados en la etapa ---
for f in Dockerfile .dockerignore docker-compose.yml docker-compose.override.yml README.md app/healthz.md resources/links.md; do
  if [ -f "$STAGE_DIR/$f" ]; then
    ok "existe $f"
  else
    bad "no existe $f"
  fi
done

# --- 2. Dockerfile: multi-stage, non-root, healthcheck, honor PORT ---
if [ -f "$STAGE_DIR/Dockerfile" ]; then
  stage_count=$(grep -c '^FROM ' "$STAGE_DIR/Dockerfile" || true)
  if [ "$stage_count" -ge 2 ]; then
    ok "Dockerfile es multi-stage ($stage_count FROM)"
  else
    bad "Dockerfile no parece multi-stage ($stage_count FROM)"
  fi
  grep -qE '^(USER |.*distroless.*nonroot)' "$STAGE_DIR/Dockerfile" && ok "Dockerfile declara usuario no-root" || bad "Dockerfile no declara USER no-root"
  grep -q 'HEALTHCHECK' "$STAGE_DIR/Dockerfile" && ok "Dockerfile define HEALTHCHECK" || bad "Dockerfile no tiene HEALTHCHECK"
  grep -q 'PORT' "$STAGE_DIR/Dockerfile" && ok "Dockerfile honra \$PORT" || bad "Dockerfile no referencia \$PORT"
  grep -qE '(distroless|chainguard|cgr\.dev)' "$STAGE_DIR/Dockerfile" && ok "runtime base distroless/chainguard" || bad "runtime base no es distroless ni chainguard"
fi

# --- 3. .dockerignore recorta lo basico ---
if [ -f "$STAGE_DIR/.dockerignore" ]; then
  for pat in .git .venv __pycache__ .env; do
    if grep -qF "$pat" "$STAGE_DIR/.dockerignore"; then
      ok ".dockerignore excluye $pat"
    else
      bad ".dockerignore no excluye $pat"
    fi
  done
fi

# --- 4. docker-compose.yml tiene los 3 servicios y perfil otel ---
if [ -f "$STAGE_DIR/docker-compose.yml" ]; then
  for svc in "app:" "db:" "otel-collector:"; do
    if grep -qE "^[[:space:]]{2}${svc}" "$STAGE_DIR/docker-compose.yml"; then
      ok "compose declara servicio ${svc%:}"
    else
      bad "compose no declara servicio ${svc%:}"
    fi
  done
  grep -q 'profiles:' "$STAGE_DIR/docker-compose.yml" && ok "compose usa profiles (otel opcional)" || bad "compose no usa profiles"
  grep -q 'postgres:16' "$STAGE_DIR/docker-compose.yml" && ok "db usa postgres:16" || bad "db no usa postgres:16"
  grep -q 'fake-password' "$STAGE_DIR/docker-compose.yml" && ok "credenciales son dummy (fake-password)" || bad "no se encontro credencial dummy fake-password"
  # No real-looking secrets
  if grep -nE '(password|secret).*=.*(prod|real|aws|supersecret)' "$STAGE_DIR/docker-compose.yml" >/dev/null; then
    bad "compose tiene lo que parece una credencial real"
  else
    ok "sin credenciales con pinta real"
  fi
fi

# --- 5. override para dev: bind mount + reload ---
if [ -f "$STAGE_DIR/docker-compose.override.yml" ]; then
  grep -q './app:/app/app' "$STAGE_DIR/docker-compose.override.yml" && ok "override monta ./app (hot-reload)" || bad "override no monta ./app"
  grep -q -- '--reload' "$STAGE_DIR/docker-compose.override.yml" && ok "override activa --reload" || bad "override no activa --reload"
fi

# --- 6. docker compose config valida (si docker esta disponible) ---
if command -v docker >/dev/null 2>&1; then
  if (cd "$STAGE_DIR" && docker compose config -q >/dev/null 2>&1); then
    ok "docker compose config valida"
  else
    bad "docker compose config falla"
  fi
else
  ok "docker no instalado, saltando config check"
fi

# --- 7. activity.yaml de esta actividad ---
AY="$STAGE_DIR/activities/01-build-and-compose-up/activity.yaml"
if [ -f "$AY" ]; then
  ok "activity.yaml existe"
  grep -q '^id: cap-04-01-build-and-compose-up' "$AY" && ok "activity.id correcto" || bad "activity.id incorrecto"
  grep -q '^technology: capstone' "$AY" && ok "technology=capstone" || bad "technology != capstone"
  grep -q '^module: 04-dockerization-compose-dev' "$AY" && ok "module correcto" || bad "module incorrecto"
else
  bad "activity.yaml no existe"
fi

# --- 8. No hay ANALYSIS.md ---
if find "$STAGE_DIR" -name 'ANALYSIS.md' -print -quit | grep -q .; then
  bad "ANALYSIS.md presente (prohibido)"
else
  ok "sin ANALYSIS.md"
fi

printf '%s' "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
