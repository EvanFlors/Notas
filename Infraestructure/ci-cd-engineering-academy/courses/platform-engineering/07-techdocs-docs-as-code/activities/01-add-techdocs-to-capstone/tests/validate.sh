#!/usr/bin/env bash
# Structural validation for plat-07-01-add-techdocs-to-capstone.
# Checks the TechDocs skeleton under $BASE: mkdocs.yml, catalog-info.yaml,
# four docs/*.md files, and the CI pipeline. Opcional: strict mkdocs build.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `grep -q` / `head` pipes that may close early (SIGPIPE, exit 141);
# pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/plat-07-techdocs}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and populate per README.md."
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. mkdocs.yml
# ---------------------------------------------------------------------------
MKDOCS="$BASE/mkdocs.yml"
if [ ! -f "$MKDOCS" ]; then
  echo "  FAIL mkdocs.yml missing at $MKDOCS"
  fail=$((fail+1))
else
  echo "  OK   mkdocs.yml present"

  if grep -qE '^site_name:[[:space:]]*[^[:space:]]' "$MKDOCS"; then
    echo "  OK   mkdocs.yml has non-empty site_name"
  else
    echo "  FAIL mkdocs.yml missing or empty site_name"
    fail=$((fail+1))
  fi

  if grep -qE 'techdocs-core' "$MKDOCS"; then
    echo "  OK   mkdocs.yml declares techdocs-core plugin"
  else
    echo "  FAIL mkdocs.yml does not declare 'techdocs-core' in plugins"
    fail=$((fail+1))
  fi

  # nav must have at least 4 .md references (index + adr + runbook + api)
  nav_refs=$(grep -cE '\.md' "$MKDOCS" || true)
  if [ "$nav_refs" -ge 4 ]; then
    echo "  OK   mkdocs.yml nav references at least 4 .md pages ($nav_refs)"
  else
    echo "  FAIL mkdocs.yml nav references only $nav_refs .md pages (expected >=4)"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------------------------
# 2. catalog-info.yaml
# ---------------------------------------------------------------------------
CAT="$BASE/catalog-info.yaml"
if [ ! -f "$CAT" ]; then
  echo "  FAIL catalog-info.yaml missing at $CAT"
  fail=$((fail+1))
else
  echo "  OK   catalog-info.yaml present"

  if grep -qE 'apiVersion:[[:space:]]*backstage\.io/v1alpha1' "$CAT"; then
    echo "  OK   catalog-info.yaml has apiVersion backstage.io/v1alpha1"
  else
    echo "  FAIL catalog-info.yaml missing apiVersion backstage.io/v1alpha1"
    fail=$((fail+1))
  fi

  if grep -qE '^kind:[[:space:]]*Component' "$CAT"; then
    echo "  OK   catalog-info.yaml kind is Component"
  else
    echo "  FAIL catalog-info.yaml kind is not Component"
    fail=$((fail+1))
  fi

  if grep -qE 'backstage\.io/techdocs-ref:[[:space:]]*dir:' "$CAT"; then
    echo "  OK   catalog-info.yaml has backstage.io/techdocs-ref: dir:..."
  else
    echo "  FAIL catalog-info.yaml missing or malformed backstage.io/techdocs-ref annotation (expected 'dir:...')"
    fail=$((fail+1))
  fi

  if grep -qE '^[[:space:]]*owner:' "$CAT"; then
    echo "  OK   catalog-info.yaml has spec.owner"
  else
    echo "  FAIL catalog-info.yaml missing spec.owner"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------------------------
# 3. docs/ pages
# ---------------------------------------------------------------------------
check_md_page() {
  local path="$1"
  local label="$2"
  if [ ! -f "$path" ]; then
    echo "  FAIL $label missing at $path"
    fail=$((fail+1))
    return
  fi
  if ! head -n1 "$path" | grep -qE '^# [^[:space:]]'; then
    echo "  FAIL $label does not start with a '# Title' line"
    fail=$((fail+1))
    return
  fi
  # Count non-empty, non-title lines
  body_lines=$(grep -cvE '^(#.*|[[:space:]]*|<!--.*-->)$' "$path" || true)
  if [ "$body_lines" -lt 3 ]; then
    echo "  FAIL $label has only $body_lines content line(s); expected >=3"
    fail=$((fail+1))
    return
  fi
  echo "  OK   $label present with title and >=3 content lines"
}

check_md_page "$BASE/docs/index.md"                    "docs/index.md"
check_md_page "$BASE/docs/adr/0001-adopt-techdocs.md"  "docs/adr/0001-adopt-techdocs.md"
check_md_page "$BASE/docs/runbook/deploy-and-rollback.md" "docs/runbook/deploy-and-rollback.md"
check_md_page "$BASE/docs/api/reference.md"            "docs/api/reference.md"

# ADR must have context / decision / consequences keywords
ADR="$BASE/docs/adr/0001-adopt-techdocs.md"
if [ -f "$ADR" ]; then
  if grep -qiE 'context|contexto' "$ADR" \
     && grep -qiE 'decision|decisi[óo]n' "$ADR" \
     && grep -qiE 'consequence|consecuencia' "$ADR"; then
    echo "  OK   ADR mentions Context / Decision / Consequences"
  else
    echo "  FAIL ADR missing one of Context / Decision / Consequences"
    fail=$((fail+1))
  fi
fi

# Runbook must mention at least one operational section
RUN="$BASE/docs/runbook/deploy-and-rollback.md"
if [ -f "$RUN" ]; then
  if grep -qiE 'diagn[óo]stico|diagnosis|mitigaci[óo]n|mitigation|escalaci[óo]n|escalation|rollback' "$RUN"; then
    echo "  OK   Runbook has at least one operational section (diagnosis / mitigation / escalation / rollback)"
  else
    echo "  FAIL Runbook missing operational sections (diagnosis / mitigation / escalation / rollback)"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------------------------
# 4. CI pipeline
# ---------------------------------------------------------------------------
WF="$BASE/.github/workflows/techdocs.yml"
if [ ! -f "$WF" ]; then
  echo "  FAIL CI workflow missing at $WF"
  fail=$((fail+1))
else
  echo "  OK   .github/workflows/techdocs.yml present"

  if grep -qE 'techdocs-cli' "$WF"; then
    echo "  OK   workflow mentions techdocs-cli"
  else
    echo "  FAIL workflow does not mention techdocs-cli"
    fail=$((fail+1))
  fi

  if grep -qE 'publish' "$WF"; then
    echo "  OK   workflow mentions publish"
  else
    echo "  FAIL workflow does not mention 'publish' subcommand"
    fail=$((fail+1))
  fi

  if grep -qiE 'awsS3|googleGcs|azureBlobStorage' "$WF"; then
    echo "  OK   workflow declares a cloud publisher-type"
  else
    echo "  FAIL workflow does not declare any publisher-type (awsS3/googleGcs/azureBlobStorage)"
    fail=$((fail+1))
  fi

  if grep -qiE 'id-token:[[:space:]]*write|oidc' "$WF"; then
    echo "  OK   workflow uses OIDC (id-token: write) or mentions OIDC"
  else
    echo "  FAIL workflow does not request OIDC (id-token: write) nor mention OIDC"
    fail=$((fail+1))
  fi

  if grep -qE '^on:' "$WF" && grep -qE 'push|workflow_dispatch' "$WF"; then
    echo "  OK   workflow has a push or workflow_dispatch trigger"
  else
    echo "  FAIL workflow missing push / workflow_dispatch trigger"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------------------------
# 5. Optional: mkdocs strict build
# ---------------------------------------------------------------------------
if command -v mkdocs >/dev/null 2>&1; then
  if python3 -c "import material" 2>/dev/null || python3 -c "import mkdocs_techdocs_core" 2>/dev/null; then
    echo
    echo "== Optional: mkdocs build --strict =="
    if (cd "$BASE" && mkdocs build --strict --site-dir "$(mktemp -d)" >/dev/null 2>&1); then
      echo "  OK   mkdocs build --strict succeeded"
    else
      echo "  FAIL mkdocs build --strict failed — check nav references and link targets"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP mkdocs-techdocs-core not installed; strict build skipped (install with 'pip install mkdocs-techdocs-core')"
  fi
else
  echo "  SKIP mkdocs not installed; strict build skipped (install with 'pip install mkdocs mkdocs-techdocs-core')"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
