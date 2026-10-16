#!/usr/bin/env bash
# Structural validation for plat-08-01-wire-essential-plugins.
# Checks that WIRING.md exists and contains the required sections,
# the canonical plugin families, auth modes table, well-known annotations
# and configuration code blocks.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-08-wiring}"
DOC="$BASE/WIRING.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required top-level sections (A..E).
if grep -qiE '^#+ *(Secci[óo]n +A|Elecci[óo]n)' "$DOC"; then
  echo "  OK   WIRING.md has Section A (Eleccion y justificacion)"
else
  echo "  FAIL WIRING.md missing Section A / Eleccion heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +B|Configuraci[óo]n|app-config)' "$DOC"; then
  echo "  OK   WIRING.md has Section B (Configuracion app-config.yaml)"
else
  echo "  FAIL WIRING.md missing Section B / Configuracion heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +C|Anotaciones|catalog-info)' "$DOC"; then
  echo "  OK   WIRING.md has Section C (Anotaciones catalog-info.yaml)"
else
  echo "  FAIL WIRING.md missing Section C / Anotaciones heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +D|EntityPage)' "$DOC"; then
  echo "  OK   WIRING.md has Section D (EntityPage.tsx)"
else
  echo "  FAIL WIRING.md missing Section D / EntityPage heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +E|Decisi[óo]n|Auth)' "$DOC"; then
  echo "  OK   WIRING.md has Section E (Decision de auth)"
else
  echo "  FAIL WIRING.md missing Section E / Auth heading"
  fail=$((fail+1))
fi

# Must name the 3 canonical plugin families.
families=0
for p in "kubernetes" "github-actions|github actions|github_actions" "argo"; do
  if grep -qiE "$p" "$DOC"; then
    families=$((families+1))
  fi
done
if [ "$families" -ge 3 ]; then
  echo "  OK   mentions Kubernetes + GitHub Actions + Argo CD families"
else
  echo "  FAIL mentions only $families of {kubernetes, github-actions, argo cd} (expected 3)"
  fail=$((fail+1))
fi

# At least 3 fenced code blocks.
fences=$(grep -cE '^```' "$DOC" || true)
if [ "$fences" -ge 6 ]; then
  echo "  OK   WIRING.md has at least 3 fenced code blocks ($((fences/2)) found)"
else
  echo "  FAIL WIRING.md has only $((fences/2)) code blocks (expected >=3)"
  fail=$((fail+1))
fi

# At least 3 well-known annotations.
anns=0
for a in "backstage.io/kubernetes-id" "github.com/project-slug" \
         "argocd/app-name" "pagerduty.com/" "grafana/dashboard"; do
  if grep -qi "$a" "$DOC"; then
    anns=$((anns+1))
  fi
done
if [ "$anns" -ge 3 ]; then
  echo "  OK   WIRING.md names at least 3 well-known annotations ($anns found)"
else
  echo "  FAIL WIRING.md names only $anns well-known annotations (expected >=3)"
  fail=$((fail+1))
fi

# Must mention proxy or discoveryApi.
if grep -qiE 'proxy|discoveryapi|discovery api' "$DOC"; then
  echo "  OK   mentions proxy / discoveryApi"
else
  echo "  FAIL does not mention proxy nor discoveryApi"
  fail=$((fail+1))
fi

# Auth modes vocabulary in Section E table.
modes=0
for m in "oauth" "service-account|service account" "github-app|github app" "proxy-token|proxy token|proxy"; do
  if grep -qiE "$m" "$DOC"; then
    modes=$((modes+1))
  fi
done
if [ "$modes" -ge 3 ]; then
  echo "  OK   WIRING.md uses >=3 auth-mode terms ($modes found)"
else
  echo "  FAIL WIRING.md uses only $modes auth-mode terms (expected >=3)"
  fail=$((fail+1))
fi

# Must have at least one table (pipes).
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 5 ]; then
  echo "  OK   WIRING.md has a table ($rows pipe-lines found)"
else
  echo "  FAIL WIRING.md table has only $rows pipe-lines (expected >=5)"
  fail=$((fail+1))
fi

# Must use ${VAR} env-var pattern (no hardcoded secrets).
if grep -qE '\$\{[A-Z_][A-Z0-9_]*\}' "$DOC"; then
  echo "  OK   uses \${ENV_VAR} pattern for secrets"
else
  echo "  FAIL does not use \${ENV_VAR} pattern (hardcoded secrets risk)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara WIRING.md con solution/REFERENCE.md para autoevaluarte."
exit 0
