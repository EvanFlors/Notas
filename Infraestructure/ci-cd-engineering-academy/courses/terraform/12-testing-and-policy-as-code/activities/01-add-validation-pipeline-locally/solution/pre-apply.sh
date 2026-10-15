#!/usr/bin/env bash
# pre-apply.sh — pipeline de validacion local pre-apply (solucion).
# Uso: ./pre-apply.sh <dir-del-modulo>
#
# Deliberadamente NO 'set -o pipefail': varios checks pipean a 'grep -q' que
# cierra el pipe pronto; pipefail convertiria SIGPIPE del productor en FAIL.
set -u

MOD_DIR="${1:-.}"
pass=0
fail=0
skip=0
report=""

add_result() {
  local label="$1" status="$2"
  report+="  [$status] $label\n"
  case "$status" in
    PASS) pass=$((pass+1));;
    FAIL) fail=$((fail+1));;
    SKIP) skip=$((skip+1));;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

echo "== pre-apply pipeline on: $MOD_DIR =="

# 1 — terraform fmt -check -recursive
if have terraform; then
  if terraform fmt -check -recursive "$MOD_DIR" >/dev/null 2>&1; then
    add_result "terraform fmt -check" PASS
  else
    add_result "terraform fmt -check" FAIL
  fi
else
  add_result "terraform fmt -check" SKIP
fi

# 2 — terraform init -backend=false
if have terraform; then
  if terraform -chdir="$MOD_DIR" init -backend=false -input=false -no-color >/dev/null 2>&1; then
    add_result "terraform init -backend=false" PASS
  else
    add_result "terraform init -backend=false" FAIL
  fi
else
  add_result "terraform init -backend=false" SKIP
fi

# 3 — terraform validate
if have terraform; then
  if terraform -chdir="$MOD_DIR" validate -no-color >/dev/null 2>&1; then
    add_result "terraform validate" PASS
  else
    add_result "terraform validate" FAIL
  fi
else
  add_result "terraform validate" SKIP
fi

# 4 — tflint
if have tflint; then
  if tflint --chdir "$MOD_DIR" --format compact >/dev/null 2>&1; then
    add_result "tflint" PASS
  else
    add_result "tflint" FAIL
  fi
else
  add_result "tflint" SKIP
fi

# 5 — checkov
if have checkov; then
  if checkov -d "$MOD_DIR" --quiet --compact --framework terraform >/dev/null 2>&1; then
    add_result "checkov" PASS
  else
    add_result "checkov" FAIL
  fi
else
  add_result "checkov" SKIP
fi

# 6 — conftest sobre policy/ si existe y hay plan.json
if [ -d "$MOD_DIR/policy" ]; then
  if have conftest; then
    if [ -f "$MOD_DIR/plan.json" ]; then
      if conftest test --policy "$MOD_DIR/policy" "$MOD_DIR/plan.json" >/dev/null 2>&1; then
        add_result "conftest (plan.json)" PASS
      else
        add_result "conftest (plan.json)" FAIL
      fi
    else
      add_result "conftest (no plan.json)" SKIP
    fi
  else
    add_result "conftest" SKIP
  fi
else
  add_result "conftest (no policy/ dir)" SKIP
fi

echo
echo "== summary =="
printf "%b" "$report"
echo "PASS=$pass FAIL=$fail SKIP=$skip"

[ "$fail" -eq 0 ]
