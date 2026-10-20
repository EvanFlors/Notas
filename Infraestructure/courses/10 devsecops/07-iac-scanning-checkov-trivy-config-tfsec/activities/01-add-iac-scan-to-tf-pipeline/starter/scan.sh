#!/usr/bin/env bash
# scan.sh — orchestrate Checkov + Trivy config and produce REPORT.md.
#
# Intentionally no `set -o pipefail`: we use `jq | grep` and friends, and
# SIGPIPE on an early match would turn into a spurious failure.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$HERE/terraform"
K8S_DIR="$HERE/k8s"
SUP="$HERE/suppressions.csv"
REPORT="$HERE/REPORT.md"
CHECKOV_JSON="$HERE/checkov.json"
TRIVY_JSON="$HERE/trivy.json"

have() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# Step 1 — Run Checkov on terraform/ and write checkov.json.
#          If checkov is NOT installed, write "{}" and echo SKIP (graceful degrade).
# -----------------------------------------------------------------------------
if have checkov; then
  echo "[scan] checkov -d $TF_DIR -o json"
  # Checkov exits non-zero when findings exist; we don't want that to kill the script.
  checkov -d "$TF_DIR" --framework terraform -o json --quiet > "$CHECKOV_JSON" || true
else
  echo "[scan] SKIP: checkov not installed; writing empty results."
  echo '{}' > "$CHECKOV_JSON"
fi

# -----------------------------------------------------------------------------
# Step 2 — Run Trivy config on k8s/ and write trivy.json.
#          If trivy is NOT installed, write "{}" and echo SKIP.
# -----------------------------------------------------------------------------
if have trivy; then
  echo "[scan] trivy config $K8S_DIR -f json"
  trivy config "$K8S_DIR" -f json -o "$TRIVY_JSON" --quiet || true
else
  echo "[scan] SKIP: trivy not installed; writing empty results."
  echo '{}' > "$TRIVY_JSON"
fi

# -----------------------------------------------------------------------------
# Step 3 — Load suppressions (skip header line, ignore blanks).
# -----------------------------------------------------------------------------
suppressed_rules=""
if [ -f "$SUP" ]; then
  while IFS=, read -r rid _reason _exp; do
    [ "$rid" = "rule_id" ] && continue
    [ -z "$rid" ] && continue
    suppressed_rules="$suppressed_rules $rid"
  done < "$SUP"
fi

is_suppressed() {
  local rid="$1"
  for s in $suppressed_rules; do
    [ "$s" = "$rid" ] && return 0
  done
  return 1
}

# -----------------------------------------------------------------------------
# Collect Checkov failed_checks (id + severity + resource) via jq.
# -----------------------------------------------------------------------------
checkov_rows=""
checkov_blocking=0
checkov_suppressed=0
if have jq && [ -s "$CHECKOV_JSON" ]; then
  # Checkov JSON shape: either {results:{failed_checks:[...]}} or a list of such.
  rows=$(jq -r '
      ( if type=="array" then .[] else . end )
      | (.results.failed_checks // [])
      | .[]
      | [ .check_id, (.severity // "UNKNOWN"), .resource ]
      | @tsv
    ' "$CHECKOV_JSON" 2>/dev/null || true)
  while IFS=$'\t' read -r rid sev res; do
    [ -z "$rid" ] && continue
    if is_suppressed "$rid"; then
      checkov_suppressed=$((checkov_suppressed+1))
      checkov_rows="${checkov_rows}| ${rid} | ${sev} | ${res} | suppressed |\n"
    else
      checkov_rows="${checkov_rows}| ${rid} | ${sev} | ${res} | active |\n"
      case "$sev" in HIGH|CRITICAL) checkov_blocking=$((checkov_blocking+1));; esac
    fi
  done <<< "$rows"
fi

# -----------------------------------------------------------------------------
# Collect Trivy config misconfigurations.
# -----------------------------------------------------------------------------
trivy_rows=""
trivy_blocking=0
trivy_suppressed=0
if have jq && [ -s "$TRIVY_JSON" ]; then
  rows=$(jq -r '
      (.Results // [])
      | .[]
      | (.Misconfigurations // [])
      | .[]
      | [ .ID, (.Severity // "UNKNOWN"), (.Message // "") ]
      | @tsv
    ' "$TRIVY_JSON" 2>/dev/null || true)
  while IFS=$'\t' read -r rid sev msg; do
    [ -z "$rid" ] && continue
    if is_suppressed "$rid"; then
      trivy_suppressed=$((trivy_suppressed+1))
      trivy_rows="${trivy_rows}| ${rid} | ${sev} | ${msg} | suppressed |\n"
    else
      trivy_rows="${trivy_rows}| ${rid} | ${sev} | ${msg} | active |\n"
      case "$sev" in HIGH|CRITICAL) trivy_blocking=$((trivy_blocking+1));; esac
    fi
  done <<< "$rows"
fi

# -----------------------------------------------------------------------------
# Step 4 — Write REPORT.md.
# -----------------------------------------------------------------------------
total_blocking=$((checkov_blocking + trivy_blocking))
total_suppressed=$((checkov_suppressed + trivy_suppressed))

{
  echo "# IaC scan report"
  echo
  echo "## Resumen"
  echo
  echo "- Checkov activos (HIGH/CRITICAL): ${checkov_blocking}"
  echo "- Trivy activos (HIGH/CRITICAL):   ${trivy_blocking}"
  echo "- Total bloqueantes:               ${total_blocking}"
  echo "- Total suprimidos:                ${total_suppressed}"
  echo
  echo "## Checkov"
  echo
  echo "| rule_id | severity | resource | status |"
  echo "|---------|----------|----------|--------|"
  if [ -n "$checkov_rows" ]; then
    printf "%b" "$checkov_rows"
  else
    echo "| (none)  | -        | -        | -      |"
  fi
  echo
  echo "## Trivy config"
  echo
  echo "| rule_id | severity | message | status |"
  echo "|---------|----------|---------|--------|"
  if [ -n "$trivy_rows" ]; then
    printf "%b" "$trivy_rows"
  else
    echo "| (none)  | -        | -       | -      |"
  fi
  echo
  echo "## Suprimidos"
  echo
  if [ -s "$SUP" ] && [ "$(wc -l < "$SUP")" -gt 1 ]; then
    echo "| rule_id | reason | expires |"
    echo "|---------|--------|---------|"
    tail -n +2 "$SUP" | while IFS=, read -r rid reason exp; do
      [ -z "$rid" ] && continue
      echo "| ${rid} | ${reason} | ${exp} |"
    done
  else
    echo "_No hay supresiones registradas._"
  fi
} > "$REPORT"

echo "[scan] wrote $REPORT (blocking=${total_blocking}, suppressed=${total_suppressed})"

if [ "$total_blocking" -gt 0 ]; then
  exit 1
fi
exit 0
