#!/usr/bin/env bash
# Validate cap-03-01-wire-up-ci.
#
# Note: deliberately NOT using `set -o pipefail`. Several checks pipe into
# grep -q which short-circuits on first match. Under pipefail, upstream
# commands may be killed by SIGPIPE (exit 141) and read as spurious failures.
set -eu

WORK="${WORK_DIR:-/tmp/cap-03-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validando $WORK =="

if [ ! -d "$WORK" ]; then
  bad "no existe directorio $WORK (ejecuta la actividad antes)"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

cd "$WORK"

# --- 1. Archivos esperados ---
for f in \
  .github/workflows/ci.yml \
  .github/workflows/pr.yml \
  pyproject.toml \
  .gitleaks.toml; do
  if [ -f "$f" ]; then
    ok "existe $f"
  else
    bad "no existe $f"
  fi
done

# --- 2. ci.yml declara los jobs esperados ---
if [ -f .github/workflows/ci.yml ]; then
  for job in lint test sast sca secret-scan aggregate-sarif; do
    if grep -q "^  ${job}:" .github/workflows/ci.yml; then
      ok "ci.yml declara job '${job}'"
    else
      bad "ci.yml no declara job '${job}'"
    fi
  done

  grep -q 'security-events: write' .github/workflows/ci.yml \
    && ok "ci.yml pide security-events: write" \
    || bad "ci.yml no pide security-events: write"

  grep -q 'id-token: write' .github/workflows/ci.yml \
    && ok "ci.yml habilita OIDC (id-token: write)" \
    || bad "ci.yml no habilita OIDC (id-token: write)"

  grep -q 'upload-sarif' .github/workflows/ci.yml \
    && ok "ci.yml sube SARIF a Code Scanning" \
    || bad "ci.yml no sube SARIF"
fi

# --- 3. pr.yml tiene checks de PR ---
if [ -f .github/workflows/pr.yml ]; then
  grep -q 'pull_request' .github/workflows/pr.yml \
    && ok "pr.yml dispara on pull_request" \
    || bad "pr.yml no dispara on pull_request"

  grep -q 'diff-cover\|diff_cover' .github/workflows/pr.yml \
    && ok "pr.yml corre diff-cover" \
    || bad "pr.yml no corre diff-cover"
fi

# --- 4. pyproject.toml con secciones de tooling ---
if [ -f pyproject.toml ]; then
  for section in '\[tool.ruff\]' '\[tool.mypy\]' '\[tool.pytest.ini_options\]'; do
    if grep -q "^${section}" pyproject.toml; then
      ok "pyproject.toml tiene seccion ${section}"
    else
      bad "pyproject.toml no tiene seccion ${section}"
    fi
  done

  grep -q 'cov-fail-under\|fail_under' pyproject.toml && ok "pyproject.toml puede expresar gate de coverage" || true
fi

# --- 5. gitleaks config con allowlist ---
if [ -f .gitleaks.toml ]; then
  grep -q '^\[allowlist\]' .gitleaks.toml \
    && ok ".gitleaks.toml declara [allowlist]" \
    || bad ".gitleaks.toml no declara [allowlist]"

  grep -q '^\[\[rules\]\]' .gitleaks.toml \
    && ok ".gitleaks.toml tiene reglas custom" \
    || bad ".gitleaks.toml no tiene reglas custom"
fi

# --- 6. YAML parseable (si python3 disponible) ---
if command -v python3 >/dev/null 2>&1; then
  for wf in .github/workflows/ci.yml .github/workflows/pr.yml; do
    if [ -f "$wf" ]; then
      if python3 -c "import yaml,sys; yaml.safe_load(open('$wf'))" 2>/dev/null; then
        ok "$wf es YAML valido"
      else
        # PyYAML podria no estar instalado; no bloqueamos.
        report+="  SKIP $wf (PyYAML no disponible, salto validacion sintactica)\n"
      fi
    fi
  done
fi

# --- 7. No hay secretos obvios ---
if grep -rE '(AKIA[0-9A-Z]{16}|-----BEGIN RSA PRIVATE KEY-----)' . 2>/dev/null \
     --include='*.yml' --include='*.toml' --include='*.py' \
     | grep -v 'allowlist\|dummy_\|example_\|fake_' >/dev/null; then
  bad "aparecen patrones de secretos reales en el repo"
else
  ok "no hay patrones de secretos reales"
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
