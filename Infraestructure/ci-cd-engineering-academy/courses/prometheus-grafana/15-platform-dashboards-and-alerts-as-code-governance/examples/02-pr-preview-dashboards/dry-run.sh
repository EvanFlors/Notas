#!/usr/bin/env bash
# Local dry-run of what the CI workflow does for dashboards & alerts.
# Does NOT touch Grafana — only lints and runs promtool tests.
# No `set -o pipefail` to avoid SIGPIPE from grep -q on streaming inputs.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

echo "== 1. YAML syntax check (workflow) =="
if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("WARN: PyYAML not installed; skipping YAML parse (pip install pyyaml).")
    sys.exit(0)
with open(".github/workflows/dashboards.yml") as fh:
    yaml.safe_load(fh)
print("OK — dashboards.yml parses as YAML.")
PY
else
  echo "WARN: python3 not available; skipping YAML parse."
fi

echo
echo "== 2. promtool check rules =="
if command -v promtool >/dev/null 2>&1; then
  promtool check rules rules/*.yaml
else
  echo "SKIP: promtool no está instalado. brew install prometheus (o descarga de prometheus.io)."
fi

echo
echo "== 3. promtool test rules =="
if command -v promtool >/dev/null 2>&1; then
  promtool test rules tests/*.yaml
else
  echo "SKIP: promtool no está instalado."
fi

echo
echo "OK — local dry-run complete"
echo "Siguiente: configurar secrets GRAFANA_PREVIEW_URL / _TOKEN y abrir un PR en un repo con este workflow."
