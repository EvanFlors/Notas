#!/usr/bin/env bash
# Validate structure of SLO.md and alerts.yaml.
# NO pipefail: we grep over student files which may short-circuit.

BASE="${BASE_DIR:-/tmp/otel13-act02}"
SLO="$BASE/SLO.md"
ALERTS="$BASE/alerts.yaml"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating otel-13-02-define-pipeline-slo =="

if [ ! -f "$SLO" ]; then
  echo "FAIL: $SLO no existe. Ejecuta starter/bootstrap.sh y edita." >&2
  exit 1
fi
if [ ! -f "$ALERTS" ]; then
  echo "FAIL: $ALERTS no existe." >&2
  exit 1
fi

# 1. Secciones del SLO.md
for section in "## SLIs" "## SLOs" "## Error Budget" "## Alertas" "## Playbook"; do
  if grep -qF "$section" "$SLO"; then
    note_ok "Seccion presente: $section"
  else
    note_fail "Seccion ausente: $section"
  fi
done

# 2. Al menos 3 SLIs mencionando metricas otelcol_*
sli_count=$(grep -cE "otelcol_[a-z_]+" "$SLO" || true)
if [ "$sli_count" -ge 3 ]; then
  note_ok "SLO.md referencia metricas otelcol_* ($sli_count ocurrencias)"
else
  note_fail "SLO.md debe referenciar >=3 metricas otelcol_* (actual: $sli_count)"
fi

# 3. Playbook con >=2 acciones (lineas con guion o numero)
playbook_section=$(awk '/^## Playbook/,0' "$SLO")
action_lines=$(echo "$playbook_section" | grep -cE "^\s*[-*0-9]" || true)
if [ "$action_lines" -ge 2 ]; then
  note_ok "Playbook con >=2 acciones ($action_lines bullets)"
else
  note_fail "Playbook debe listar >=2 acciones (bullets o numeradas; actual: $action_lines)"
fi

# 4. alerts.yaml YAML valido con grupos y >=3 rules
if command -v python3 >/dev/null 2>&1; then
  py_out=$(python3 - "$ALERTS" <<'PY'
import sys, yaml
try:
    data = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print(f"YAML_ERR:{e}")
    sys.exit(0)
if not isinstance(data, dict) or "groups" not in data:
    print("STRUCT_ERR:no groups")
    sys.exit(0)
rules = []
for g in data["groups"] or []:
    for r in g.get("rules", []) or []:
        rules.append(r)
alert_rules = [r for r in rules if "alert" in r and "expr" in r]
with_otelcol = [r for r in alert_rules if "otelcol_" in str(r.get("expr",""))]
print(f"OK:{len(alert_rules)}:{len(with_otelcol)}")
PY
)
  case "$py_out" in
    YAML_ERR:*)   note_fail "alerts.yaml invalid YAML: ${py_out#YAML_ERR:}";;
    STRUCT_ERR:*) note_fail "alerts.yaml sin 'groups:' top-level";;
    OK:*)
      n_rules=$(echo "$py_out" | awk -F: '{print $2}')
      n_otelcol=$(echo "$py_out" | awk -F: '{print $3}')
      if [ "$n_rules" -ge 3 ]; then
        note_ok "alerts.yaml con $n_rules alert rules"
      else
        note_fail "alerts.yaml debe tener >=3 alert rules (actual: $n_rules)"
      fi
      if [ "$n_otelcol" -ge 1 ]; then
        note_ok "alert rules referencian otelcol_* en expr ($n_otelcol)"
      else
        note_fail "al menos una alert rule debe referenciar una metrica otelcol_* en expr"
      fi
      ;;
    *) note_fail "no pude parsear alerts.yaml ($py_out)";;
  esac
else
  note_fail "python3 requerido para parsear alerts.yaml"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed OK, $failed FAIL."
if [ "$failed" -eq 0 ]; then
  echo "== OK: estructura SLO + alerts verificada =="
  exit 0
fi
exit 1
