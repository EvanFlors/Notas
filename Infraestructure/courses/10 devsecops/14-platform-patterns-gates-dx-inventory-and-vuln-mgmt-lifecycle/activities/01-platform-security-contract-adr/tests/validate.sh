#!/usr/bin/env bash
# Structural validation for sec-14-01-platform-security-contract-adr.
# Checks that ADR-security-contract.md exists and contains the required
# sections, the gate table, the CVSS+EPSS+KEV vocabulary, and the exception
# policy keywords.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-14-contract}"
DOC="$BASE/ADR-security-contract.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section: Contexto
if grep -qiE '^#+.*(Contexto|Context)' "$DOC"; then
  echo "  OK   has 'Contexto' section"
else
  echo "  FAIL missing 'Contexto' section heading"
  fail=$((fail+1))
fi

# Section: Decision
if grep -qiE '^#+.*(Decisi[óo]n|Decision)' "$DOC"; then
  echo "  OK   has 'Decision' section"
else
  echo "  FAIL missing 'Decision' section heading"
  fail=$((fail+1))
fi

# Section: Gates
if grep -qiE '^#+ *.*(Gate|Gates|Controles)' "$DOC"; then
  echo "  OK   has 'Gates' section"
else
  echo "  FAIL missing 'Gates' section heading"
  fail=$((fail+1))
fi

# Section: Severidad / Severity
if grep -qiE '^#+ *.*(Severidad|Severity|Pol[ií]tica)' "$DOC"; then
  echo "  OK   has 'Severidad / Politica' section"
else
  echo "  FAIL missing 'Severidad / Politica' section heading"
  fail=$((fail+1))
fi

# Section: Exception / Excepciones
if grep -qiE '^#+ *.*(Excepci|Exception)' "$DOC"; then
  echo "  OK   has 'Excepciones' section"
else
  echo "  FAIL missing 'Excepciones' section heading"
  fail=$((fail+1))
fi

# Section: Developer experience / DX
if grep -qiE '^#+ *.*(Developer|DX|Experience|Experiencia)' "$DOC"; then
  echo "  OK   has 'Developer experience' section"
else
  echo "  FAIL missing 'Developer experience' section heading"
  fail=$((fail+1))
fi

# Section: Consecuencias / Consequences
if grep -qiE '^#+ *.*(Consecuenc|Consequence|Trade-?off)' "$DOC"; then
  echo "  OK   has 'Consecuencias' section"
else
  echo "  FAIL missing 'Consecuencias' section heading"
  fail=$((fail+1))
fi

# Vocabulario de categorias de gates (al menos los 3 terminos)
for term in "blocking" "warn" "nightly"; do
  if grep -qi "$term" "$DOC"; then
    echo "  OK   uses gate-category term '$term'"
  else
    echo "  FAIL does not use gate-category term '$term'"
    fail=$((fail+1))
  fi
done

# Severity vocabulary
for term in "CVSS" "EPSS" "KEV"; do
  if grep -q "$term" "$DOC"; then
    echo "  OK   mentions '$term'"
  else
    echo "  FAIL does not mention '$term'"
    fail=$((fail+1))
  fi
done

# Exception policy vocabulary
for term in "approver" "TTL|expir" "revisor|reviewer"; do
  if grep -qiE "$term" "$DOC"; then
    echo "  OK   exception policy mentions '$term'"
  else
    echo "  FAIL exception policy missing '$term'"
    fail=$((fail+1))
  fi
done

# Al menos un panel SARIF / un solo panel / Backstage / Code Scanning / IDP
if grep -qiE 'sarif|backstage|code scanning|idp'  "$DOC"; then
  echo "  OK   DX section references a unified panel (SARIF/Backstage/Code Scanning/IDP)"
else
  echo "  FAIL DX section missing unified-panel reference"
  fail=$((fail+1))
fi

# Al menos una tabla (pipe-lines >= 5 para header + separator + 3 rows)
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 5 ]; then
  echo "  OK   has at least one table ($rows pipe-lines found)"
else
  echo "  FAIL no table found (expected >=5 pipe-lines, found $rows)"
  fail=$((fail+1))
fi

# At least 5 gates mentioned by name (secret, SAST, SCA, firma/sign, SBOM, IaC, admission)
pieces=0
for p in "secret" "sast|semgrep|codeql" "sca|trivy" "sign|cosign|firma" "sbom|syft" "iac|checkov|opa|rego" "admission|kyverno"; do
  if grep -qiE "$p" "$DOC"; then
    pieces=$((pieces+1))
  fi
done
if [ "$pieces" -ge 5 ]; then
  echo "  OK   names at least 5 gate categories ($pieces found)"
else
  echo "  FAIL names only $pieces gate categories (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-security-contract.md con solution/REFERENCE.md."
exit 0
