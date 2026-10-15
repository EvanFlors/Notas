#!/usr/bin/env bash
# Valida la actividad 02: ARC en kind + ADR.
# NOTE: no usamos `set -o pipefail` globalmente para evitar SIGPIPE con
# productores largos (kubectl, helm) + grep -q (lesson gh-02).
set -eu

ROOT="${1:-${ARC_MINI_ROOT:-/tmp/arc-mini}}"
MODE="${MODE:-auto}"
fail=0

echo "== Validating $ROOT (MODE=$MODE) =="

# ---------- Chequeo del layout ----------
if [ ! -d "$ROOT/docs" ] || [ ! -d "$ROOT/manifests" ]; then
  echo "  FAIL layout: $ROOT no fue inicializado. Corre starter/bootstrap.sh"
  exit 1
fi

# ---------- Detectar modo ----------
have_tool() { command -v "$1" >/dev/null 2>&1; }
missing=""
for t in docker kind kubectl helm; do
  have_tool "$t" || missing="$missing $t"
done

if [ "$MODE" = "auto" ]; then
  if [ -z "$missing" ]; then
    MODE=infra+adr
  else
    MODE=docs-only
    echo "  SKIP infra: herramientas faltantes ->$missing"
    echo "       (instala y re-ejecuta para validar el entregable A)"
  fi
fi

# ---------- Validar ADR (siempre) ----------
ADR="$ROOT/docs/ADR-001-runner-choice.md"
if [ ! -f "$ADR" ]; then
  echo "  FAIL ADR ausente: $ADR"
  fail=$((fail+1))
else
  echo "  OK   ADR presente: $ADR"
  for sec in "## Contexto" "## Opciones evaluadas" "## Decisión" "## Consecuencias"; do
    if grep -qF "$sec" "$ADR"; then
      echo "    OK   sección '$sec' presente"
    else
      echo "    FAIL falta sección '$sec'"
      fail=$((fail+1))
    fi
  done
  # Las 4 opciones mencionadas
  for opt in "hosted" "larger" "self-hosted" "ARC"; do
    if grep -iq "$opt" "$ADR"; then
      echo "    OK   opción '$opt' mencionada"
    else
      echo "    FAIL opción '$opt' no mencionada en el ADR"
      fail=$((fail+1))
    fi
  done
  # Longitud mínima para evitar entregas vacías
  n=$(wc -c < "$ADR" | tr -d ' ')
  if [ "$n" -ge 500 ]; then
    echo "    OK   ADR tiene $n caracteres (>=500)"
  else
    echo "    FAIL ADR muy corto ($n chars); mínimo 500"
    fail=$((fail+1))
  fi
  # Que no quede el placeholder sin editar
  if grep -q "<tu nombre>" "$ADR" || grep -q "<Resume el escenario" "$ADR" || grep -q "<Una línea con la decisión" "$ADR"; then
    echo "    FAIL ADR aún contiene placeholders '<...>' sin reemplazar"
    fail=$((fail+1))
  else
    echo "    OK   ADR sin placeholders residuales"
  fi
fi

# ---------- Validar infra (si corresponde) ----------
if [ "$MODE" = "infra+adr" ] || [ "$MODE" = "infra" ]; then
  # Cluster kind
  if kind get clusters 2>/dev/null | grep -qx "arc-mini"; then
    echo "  OK   kind cluster 'arc-mini' existe"
  else
    echo "  FAIL kind cluster 'arc-mini' no existe. Corre bin/apply-infra.sh"
    fail=$((fail+1))
  fi

  # Context
  if kubectl config get-contexts -o name 2>/dev/null | grep -qx "kind-arc-mini"; then
    kubectl config use-context kind-arc-mini >/dev/null 2>&1 || true
    echo "  OK   kubectl context kind-arc-mini seleccionable"
  else
    echo "  FAIL kubectl context 'kind-arc-mini' no encontrado"
    fail=$((fail+1))
  fi

  # CRDs — al menos 2 de las 4
  crd_count=0
  for c in autoscalingrunnersets.actions.github.com \
           autoscalinglisteners.actions.github.com \
           ephemeralrunners.actions.github.com \
           ephemeralrunnersets.actions.github.com; do
    if kubectl get crd "$c" >/dev/null 2>&1; then
      echo "    OK   CRD $c instalada"
      crd_count=$((crd_count+1))
    fi
  done
  if [ "$crd_count" -ge 2 ]; then
    echo "  OK   $crd_count CRDs actions.github.com instaladas (>=2)"
  else
    echo "  FAIL se esperaban >=2 CRDs actions.github.com (vistas: $crd_count)"
    fail=$((fail+1))
  fi

  # Operator pod
  if kubectl -n arc-systems get deploy 2>/dev/null | awk 'NR>1{print $1}' | grep -q controller; then
    echo "  OK   operator deployment presente en arc-systems"
  else
    echo "  FAIL operator deployment ausente en arc-systems"
    fail=$((fail+1))
  fi

  # AutoscalingRunnerSet
  if kubectl -n arc-runners get autoscalingrunnerset my-runners >/dev/null 2>&1; then
    echo "  OK   AutoscalingRunnerSet 'my-runners' existe en arc-runners"
  else
    echo "  FAIL AutoscalingRunnerSet 'my-runners' no existe (helm install my-runners)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed. (MODE=$MODE)"
  exit 1
fi
echo "OK: actividad completada correctamente. (MODE=$MODE)"
exit 0
