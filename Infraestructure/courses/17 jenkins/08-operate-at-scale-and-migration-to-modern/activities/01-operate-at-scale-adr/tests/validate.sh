#!/usr/bin/env bash
# Structural validation for jk-08-01-operate-at-scale-adr.
# Checks that ADR-OPERATE-AT-SCALE.md exists and contains the required
# sections plus the minimum content expected by the scenario (HA pattern,
# backup strategy, upgrade cadence, capacity, observability).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-08-01}"
DOC="$BASE/ADR-OPERATE-AT-SCALE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-OPERATE-AT-SCALE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-OPERATE-AT-SCALE.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR has '${label}' section"
  else
    echo "  FAIL ADR missing '${label}' section"
    fail=$((fail+1))
  fi
done

# At least one fenced code block (the HA diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, diagram needs opening+closing)"
  fail=$((fail+1))
fi

# HA pattern explicitly mentioned (one of the three realistic options).
if grep -qiE 'activo[- ]pasivo|active[- ]passive|CloudBees|Operator' "$DOC"; then
  echo "  OK   mentions an HA pattern (activo-pasivo / CloudBees / Operator)"
else
  echo "  FAIL does not mention any HA pattern (activo-pasivo / CloudBees / Operator)"
  fail=$((fail+1))
fi

# JENKINS_HOME + backup/restore keywords.
if grep -q 'JENKINS_HOME' "$DOC"; then
  echo "  OK   mentions JENKINS_HOME"
else
  echo "  FAIL does not mention JENKINS_HOME"
  fail=$((fail+1))
fi

if grep -qiE 'backup|restore' "$DOC"; then
  echo "  OK   mentions backup/restore"
else
  echo "  FAIL does not mention backup/restore"
  fail=$((fail+1))
fi

# master.key or secrets/ reference (the pitfall that breaks restores).
if grep -qiE 'master\.key|secrets/' "$DOC"; then
  echo "  OK   mentions secrets/ or master.key (restore pitfall)"
else
  echo "  FAIL does not mention secrets/ or master.key"
  fail=$((fail+1))
fi

# Backup destination technology.
if grep -qiE 'Velero|snapshot|S3|object[- ]lock' "$DOC"; then
  echo "  OK   mentions a backup destination/tech (Velero / snapshot / S3)"
else
  echo "  FAIL does not mention a backup destination/tech"
  fail=$((fail+1))
fi

# Upgrade cadence: must mention LTS and some cadence word (semana|mes|week|month).
if grep -q 'LTS' "$DOC" && grep -qiE 'semana|mes\b|week|month' "$DOC"; then
  echo "  OK   mentions LTS upgrade cadence"
else
  echo "  FAIL does not mention LTS and a cadence (semana/mes/week/month)"
  fail=$((fail+1))
fi

# Capacity: controller and agents mentioned together.
if grep -qi 'controller' "$DOC" && grep -qi 'agent' "$DOC"; then
  echo "  OK   mentions controller and agents (capacity)"
else
  echo "  FAIL does not mention both 'controller' and 'agent' for capacity"
  fail=$((fail+1))
fi

# At least 3 metric-ish tokens that must alert.
metrics=0
for m in "queue_depth" "queue depth" "executor" "heap" "jvm_memory" \
         "builds/h" "builds/hora" "p95" "latency" "cpu"; do
  if grep -qi "$m" "$DOC"; then
    metrics=$((metrics+1))
  fi
done
if [ "$metrics" -ge 3 ]; then
  echo "  OK   names at least 3 metrics/alerts (${metrics} tokens found)"
else
  echo "  FAIL names only ${metrics} metric tokens (expected >=3)"
  fail=$((fail+1))
fi

# JCasC / jenkins.yaml mention (reproducibility).
if grep -qiE 'JCasC|jenkins\.yaml|configuration[- ]as[- ]code' "$DOC"; then
  echo "  OK   mentions JCasC / jenkins.yaml (reproducibility)"
else
  echo "  FAIL does not mention JCasC / jenkins.yaml"
  fail=$((fail+1))
fi

# SLA mention from the scenario.
if grep -qiE '99\.5|99\.9|SLA' "$DOC"; then
  echo "  OK   mentions SLA (99.5 or similar)"
else
  echo "  FAIL does not mention SLA"
  fail=$((fail+1))
fi

# Compliance / retention mention from the scenario.
if grep -qiE 'complianc|retenci[oó]n|retention|7 +a[nñ]os|7 +years' "$DOC"; then
  echo "  OK   mentions compliance / 7-year retention"
else
  echo "  FAIL does not mention compliance / retention"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives (subheadings or numbered).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-OPERATE-AT-SCALE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
