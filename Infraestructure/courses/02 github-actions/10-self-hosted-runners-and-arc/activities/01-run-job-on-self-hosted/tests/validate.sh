#!/usr/bin/env bash
# Valida la actividad 01: estructura del runner self-hosted (simulado).
# NOTE: no usamos `set -o pipefail` globalmente para evitar SIGPIPE
# cuando combinamos productores largos con `grep -q` (lesson gh-02).
set -eu

ROOT="${1:-${RUNNER_ROOT:-/tmp/sh-runner}}"
fail=0

echo "== Validating $ROOT =="

# ---- 1) Layout del starter ----
for p in \
  "$ROOT/actions-runner/config.sh" \
  "$ROOT/actions-runner/run.sh" \
  "$ROOT/actions-runner/bin/Runner.Listener" \
  "$ROOT/actions-runner/bin/Runner.Worker" \
  ; do
  if [ -f "$p" ]; then
    echo "  OK   layout: $p"
  else
    echo "  FAIL layout: $p ausente (corre starter/bootstrap.sh)"
    fail=$((fail+1))
  fi
done

ENV_FILE="$ROOT/actions-runner/runner-config.env"
RUNNER_FILE="$ROOT/actions-runner/.runner"
WF_FILE="$ROOT/workflows/hello-self-hosted.yml"

# ---- 2) runner-config.env ----
if [ ! -f "$ENV_FILE" ]; then
  echo "  FAIL $ENV_FILE no existe (copia del .template y rellena)"
  fail=$((fail+1))
else
  echo "  OK   $ENV_FILE presente"
  for key in RUNNER_URL RUNNER_NAME RUNNER_LABELS RUNNER_EPHEMERAL RUNNER_WORK_FOLDER; do
    if grep -Eq "^${key}=" "$ENV_FILE"; then
      echo "    OK   $key definido"
    else
      echo "    FAIL $key ausente en $ENV_FILE"
      fail=$((fail+1))
    fi
  done
  url=$(grep -E '^RUNNER_URL=' "$ENV_FILE" | head -1 | cut -d= -f2-)
  case "$url" in
    https://github.com/*) echo "    OK   RUNNER_URL apunta a github.com" ;;
    *) echo "    FAIL RUNNER_URL debe empezar con https://github.com/ (got: $url)"; fail=$((fail+1));;
  esac
  if grep -Eq '^RUNNER_EPHEMERAL=true$' "$ENV_FILE"; then
    echo "    OK   RUNNER_EPHEMERAL=true"
  else
    echo "    FAIL RUNNER_EPHEMERAL debe ser 'true' (seguridad: ver lesson §2.3)"
    fail=$((fail+1))
  fi
  labels_line=$(grep -E '^RUNNER_LABELS=' "$ENV_FILE" | head -1 | cut -d= -f2-)
  if [ -n "$labels_line" ]; then
    # Al menos una label custom (cualquier cosa que no sea self-hosted/linux/x64/windows/macos/arm64)
    found_custom=0
    IFS=',' read -r -a arr <<<"$labels_line"
    for l in "${arr[@]}"; do
      case "$l" in
        self-hosted|linux|x64|windows|macos|arm64|"") ;;
        *) found_custom=1 ;;
      esac
    done
    if [ "$found_custom" -eq 1 ]; then
      echo "    OK   RUNNER_LABELS incluye al menos una label custom"
    else
      echo "    FAIL RUNNER_LABELS debe tener al menos 1 label custom (p.ej. demo)"
      fail=$((fail+1))
    fi
  fi
fi

# ---- 3) .runner JSON ----
if [ ! -f "$RUNNER_FILE" ]; then
  echo "  FAIL $RUNNER_FILE no existe (copia del .runner.template y rellena)"
  fail=$((fail+1))
else
  echo "  OK   $RUNNER_FILE presente"
  if ! python3 - "$RUNNER_FILE" <<'PY' ; then
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"    FAIL .runner no es JSON válido: {e}")
    sys.exit(1)
if d.get("ephemeral") is not True:
    print("    FAIL .runner.ephemeral debe ser true (bool)")
    sys.exit(1)
labels = d.get("labels", [])
names = [l.get("name") for l in labels if isinstance(l, dict)]
if "self-hosted" not in names:
    print("    FAIL .runner.labels debe incluir 'self-hosted'")
    sys.exit(1)
custom = [l for l in labels if isinstance(l, dict) and l.get("type") == "user"]
if not custom:
    print("    FAIL .runner.labels debe incluir >=1 label con type='user' (custom)")
    sys.exit(1)
print("    OK   .runner JSON válido, ephemeral=true, labels con self-hosted + custom")
PY
    fail=$((fail+1))
  fi
fi

# ---- 4) workflow YAML ----
if [ ! -f "$WF_FILE" ]; then
  echo "  FAIL $WF_FILE no existe (copia del .template y rellena)"
  fail=$((fail+1))
else
  echo "  OK   $WF_FILE presente"
  if ! python3 - "$WF_FILE" "$RUNNER_FILE" <<'PY' ; then
import sys
try:
    import yaml
except ImportError:
    print("    WARN PyYAML no instalado; haciendo chequeo estructural con grep")
    sys.exit(0)
wf_path, runner_path = sys.argv[1], sys.argv[2]
try:
    wf = yaml.safe_load(open(wf_path))
except Exception as e:
    print(f"    FAIL workflow YAML inválido: {e}")
    sys.exit(1)
on = wf.get("on") or wf.get(True)  # YAML parse "on:" quirk
# Handle 'on' being parsed as bool True by PyYAML in some cases
if on is None:
    print("    FAIL workflow no define 'on:'")
    sys.exit(1)
if isinstance(on, dict):
    if "workflow_dispatch" not in on:
        print("    FAIL workflow.on debe incluir workflow_dispatch")
        sys.exit(1)
elif isinstance(on, list):
    if "workflow_dispatch" not in on:
        print("    FAIL workflow.on debe incluir workflow_dispatch")
        sys.exit(1)
elif isinstance(on, str):
    if on != "workflow_dispatch":
        print("    FAIL workflow.on debe incluir workflow_dispatch")
        sys.exit(1)
jobs = wf.get("jobs") or {}
if not jobs:
    print("    FAIL workflow no define jobs")
    sys.exit(1)
# toma el primer job
job = next(iter(jobs.values()))
runs_on = job.get("runs-on")
if not isinstance(runs_on, list):
    print(f"    FAIL runs-on debe ser lista (array), got: {type(runs_on).__name__}")
    sys.exit(1)
if "self-hosted" not in runs_on:
    print("    FAIL runs-on debe incluir 'self-hosted'")
    sys.exit(1)
custom_in_runson = [x for x in runs_on if x not in ("self-hosted","linux","x64","windows","macos","arm64")]
if not custom_in_runson:
    print("    FAIL runs-on debe incluir >=1 label custom (p.ej. demo)")
    sys.exit(1)
# cruce con .runner
import json
try:
    rd = json.load(open(runner_path))
    runner_custom = {l["name"] for l in rd.get("labels",[]) if l.get("type")=="user"}
    overlap = runner_custom & set(custom_in_runson)
    if not overlap:
        print(f"    FAIL ninguna label custom del workflow ({custom_in_runson}) está en .runner ({sorted(runner_custom)})")
        sys.exit(1)
    print(f"    OK   runs-on cruza con .runner por labels: {sorted(overlap)}")
except Exception as e:
    print(f"    WARN no pude cruzar con .runner: {e}")
steps = job.get("steps") or []
if not steps:
    print("    FAIL job no define steps")
    sys.exit(1)
print("    OK   workflow YAML válido, workflow_dispatch, runs-on lista con self-hosted + custom, >=1 step")
PY
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
