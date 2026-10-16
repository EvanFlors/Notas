#!/usr/bin/env bash
# Structural validation for sec-11-02-exception-workflow.
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/sec-11-exception}"
fail=0

echo "== Structural validation for $BASE =="

check_file() {
  if [ -f "$1" ]; then
    echo "  OK   $1 exists"
  else
    echo "  FAIL $1 missing"
    fail=$((fail+1))
  fi
}

grep_in() {
  if [ -f "$1" ] && grep -qiE "$2" "$1"; then
    echo "  OK   $3"
  else
    echo "  FAIL $3"
    fail=$((fail+1))
  fi
}

# 1. Expected files.
check_file "$BASE/ADR.md"
check_file "$BASE/TEMPLATE.yaml"
check_file "$BASE/PROCESS.md"

# 2. ADR sections.
grep_in "$BASE/ADR.md" '^#+ *contexto'                "ADR has Contexto section"
grep_in "$BASE/ADR.md" '^#+ *decisi[óo]n'             "ADR has Decision section"
grep_in "$BASE/ADR.md" 'alternativa'                  "ADR mentions alternatives rejected"
grep_in "$BASE/ADR.md" 'consecuencia'                 "ADR mentions consequences"

# 3. TEMPLATE.yaml must be a PolicyException with required annotations.
grep_in "$BASE/TEMPLATE.yaml" '^kind: *PolicyException'  "TEMPLATE kind=PolicyException"
grep_in "$BASE/TEMPLATE.yaml" 'kyverno\.io'              "TEMPLATE uses kyverno.io API"
grep_in "$BASE/TEMPLATE.yaml" 'requested-by'             "TEMPLATE has requested-by annotation"
grep_in "$BASE/TEMPLATE.yaml" 'approved-by'              "TEMPLATE has approved-by annotation"
grep_in "$BASE/TEMPLATE.yaml" 'ticket'                   "TEMPLATE has ticket annotation"
grep_in "$BASE/TEMPLATE.yaml" 'expires-at'               "TEMPLATE has expires-at annotation"
grep_in "$BASE/TEMPLATE.yaml" '^spec:'                   "TEMPLATE has spec section"
grep_in "$BASE/TEMPLATE.yaml" 'policyName'               "TEMPLATE references a policyName"

# 4. PROCESS.md sections.
grep_in "$BASE/PROCESS.md" '^#+ *solicitud'              "PROCESS has Solicitud section"
grep_in "$BASE/PROCESS.md" '^#+ *aprobaci[óo]n'          "PROCESS has Aprobacion section"
grep_in "$BASE/PROCESS.md" '^#+ *ttl'                    "PROCESS has TTL section"
grep_in "$BASE/PROCESS.md" '^#+ *expiraci[óo]n'          "PROCESS has Expiracion section"
grep_in "$BASE/PROCESS.md" '^#+ *auditor[íi]a'           "PROCESS has Auditoria section"

# 5. YAML parse check (optional).
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  if python3 -c "import sys,yaml;list(yaml.safe_load_all(open(sys.argv[1])))" "$BASE/TEMPLATE.yaml" >/dev/null 2>&1; then
    echo "  OK   TEMPLATE.yaml parses as YAML"
  else
    echo "  FAIL TEMPLATE.yaml is not valid YAML"
    fail=$((fail+1))
  fi
else
  echo "  SKIP YAML parse check (python3/PyYAML not available)"
fi

# 6. kyverno CLI bonus.
if command -v kyverno >/dev/null 2>&1; then
  echo "  INFO kyverno CLI detected (no apply here since this is a template)"
else
  echo "  SKIP kyverno CLI not installed"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
