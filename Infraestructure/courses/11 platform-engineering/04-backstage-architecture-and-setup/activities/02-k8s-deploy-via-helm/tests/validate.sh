#!/usr/bin/env bash
# Structural validation for plat-04-02-k8s-deploy-via-helm.
# Checks HELM-DEPLOY.md structure, values.yaml validity and required blocks,
# and absence of real-looking secrets. Optional: helm template render.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Semantic correctness is NOT graded — compare manually with solution/.

set -eu

BASE="${1:-/tmp/plat-04-helm}"
DOC="$BASE/HELM-DEPLOY.md"
VALUES="$BASE/values.yaml"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

# -------- Required files --------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$VALUES" ]; then
  echo "FAIL: $VALUES does not exist. Student must produce it."
  exit 1
fi

# -------- Section headings in HELM-DEPLOY.md (A..D) --------
for sec in A B C D; do
  if grep -qiE "^#+ *Secci[óo]n +${sec}\b" "$DOC"; then
    echo "  OK   HELM-DEPLOY.md has 'Seccion ${sec}'"
  else
    echo "  FAIL HELM-DEPLOY.md missing 'Seccion ${sec}'"
    fail=$((fail+1))
  fi
done

# -------- Required keywords in HELM-DEPLOY.md --------
require_kw() {
  local pattern="$1"
  local label="$2"
  if grep -qiE "$pattern" "$DOC"; then
    echo "  OK   HELM-DEPLOY.md mentions ${label}"
  else
    echo "  FAIL HELM-DEPLOY.md does not mention ${label}"
    fail=$((fail+1))
  fi
}

require_kw 'helm install|helm template|helm upgrade' 'helm commands'
require_kw 'backstage/backstage|backstage/charts'    'chart coordinates'
require_kw 'ingress'                                  'ingress'
require_kw 'tls|https'                                'TLS/HTTPS'
require_kw 'postgres'                                 'Postgres'
require_kw 'secretKeyRef|external secrets|vault'      'secret injection pattern'
require_kw 'upgrade'                                  'upgrade policy'

# -------- values.yaml required blocks --------
require_values_kw() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$VALUES"; then
    echo "  OK   values.yaml has ${label}"
  else
    echo "  FAIL values.yaml missing ${label}"
    fail=$((fail+1))
  fi
}

require_values_kw '^backstage:'              'backstage block'
require_values_kw '^[[:space:]]+image:'      'image block'
require_values_kw 'extraEnvVars:'            'extraEnvVars block'
require_values_kw 'secretKeyRef:'            'secretKeyRef usage'
require_values_kw '^ingress:'                'ingress block'
require_values_kw '^postgresql:'             'postgresql block'
require_values_kw 'enabled:[[:space:]]*false' 'postgresql.enabled: false (expected)'

# -------- values.yaml must parse as YAML --------
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$VALUES'))" 2>/dev/null; then
    echo "  OK   values.yaml parses as YAML"
  else
    echo "  FAIL values.yaml is not valid YAML"
    fail=$((fail+1))
  fi
else
  echo "  SKIP YAML parse (python3 not available)"
  skipped=$((skipped+1))
fi

# -------- Secrets safety across both files --------
bad_secrets=0
for f in "$DOC" "$VALUES"; do
  while IFS= read -r line; do
    if printf '%s' "$line" | grep -qE 'ghp_[A-Za-z0-9]{30,}' \
       && ! printf '%s' "$line" | grep -qi 'placeholder\|xxxx\|example\|do_not_use'; then
      echo "  FAIL possible real GitHub token in $f: $line"
      bad_secrets=$((bad_secrets+1))
    fi
    if printf '%s' "$line" | grep -qE 'Iv1\.[A-Za-z0-9]{10,}' \
       && ! printf '%s' "$line" | grep -qi 'placeholder\|xxxx\|example'; then
      echo "  FAIL possible real OAuth clientId in $f: $line"
      bad_secrets=$((bad_secrets+1))
    fi
  done < "$f"
done
if [ "$bad_secrets" -eq 0 ]; then
  echo "  OK   no real-looking secrets detected in either file"
else
  fail=$((fail+bad_secrets))
fi

# -------- Optional: helm template --------
if command -v helm >/dev/null 2>&1; then
  echo "== Optional helm template check =="
  if helm template my-backstage backstage/backstage --values "$VALUES" >/dev/null 2>&1; then
    echo "  OK   helm template renders"
  else
    # Try adding the repo first
    helm repo add backstage https://backstage.github.io/charts >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    if helm template my-backstage backstage/backstage --values "$VALUES" >/dev/null 2>&1; then
      echo "  OK   helm template renders (repo added)"
    else
      echo "  SKIP helm template (chart repo unreachable or offline)"
      skipped=$((skipped+1))
    fi
  fi
else
  echo "  SKIP helm template (helm not installed)"
  skipped=$((skipped+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed; $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/.)"
  exit 1
fi
echo "OK: estructura valida ($skipped SKIP). Compara con solution/REFERENCE.md y solution/values.yaml."
exit 0
