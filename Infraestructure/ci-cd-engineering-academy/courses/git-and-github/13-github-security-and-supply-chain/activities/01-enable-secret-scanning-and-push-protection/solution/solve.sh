#!/usr/bin/env bash
# Reference solution for gh-13-01-enable-secret-scanning-and-push-protection.
# Instalates a pre-commit hook detecting 4 secret patterns, and completes SECURITY.md.
set -euo pipefail

BASE="${1:-/tmp/sec-scanning}"
REPO="$BASE/repo"
if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

cd "$REPO"

# 1) Install the pre-commit hook
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
# Local pre-commit secret scanner (defense in depth).
# Blocks commits that stage content matching known secret patterns.

patterns=(
  'AKIA[0-9A-Z]{16}'
  'ghp_[0-9A-Za-z]{36}'
  'sk_live_[0-9A-Za-z]{10,}'
  '-----BEGIN( RSA| OPENSSH| EC| DSA)? PRIVATE KEY-----'
)

# Collect staged files (added, copied, modified, renamed, type-changed).
staged="$(git diff --cached --name-only --diff-filter=ACMRT)"
[ -z "$staged" ] && exit 0

found=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Binary files: skip.
  if git diff --cached --numstat -- "$f" | awk '{print $1$2}' | grep -q '^-$'; then
    continue
  fi
  content="$(git show ":$f" 2>/dev/null || true)"
  [ -z "$content" ] && continue
  for pat in "${patterns[@]}"; do
    if printf '%s' "$content" | grep -Eq -- "$pat"; then
      echo "[pre-commit] BLOCKED: potential secret matching /$pat/ in $f" >&2
      found=1
    fi
  done
done <<< "$staged"

if [ "$found" -ne 0 ]; then
  echo "[pre-commit] Commit aborted. Remove the secret and rotate it if real." >&2
  exit 1
fi
exit 0
HOOK
chmod +x .git/hooks/pre-commit

# 2) Complete SECURITY.md
cat > SECURITY.md <<'EOF'
# Security Policy

## Reporting

Reporta vulnerabilidades usando **Private Vulnerability Reporting** en GitHub:
Repository → Security → Advisories → **Report a vulnerability**.

No abras issues públicos para vulnerabilidades. El equipo responde en <=72h.

## Controls

Controles activos en este repo:

- **Secret scanning + push protection** (habilitado en GitHub a nivel repo).
- **Pre-commit hook local** que detecta patrones AWS, GitHub tokens, Stripe
  keys, y claves privadas (defensa en profundidad).
- **Firma de commits y tags** con SSH signing; ruleset `required_signatures` en main.
- **Dependabot** alerts, security updates y version updates agrupados.
- **CodeQL** code scanning en PR y schedule semanal.
- **OIDC federation** a AWS (cero credenciales de larga vida en Actions).
- **Workflows** con `permissions:` mínimas y actions pinneadas por SHA.
- **Audit log** streaming activo a nivel organización.

## Rotation

- Secrets inevitables (webhooks externos) se rotan cada 90 días.
- Credenciales emitidas vía OIDC: no requieren rotación (viven <1h).
- Claves SSH de firma: revisión anual; revocación inmediata al salir del equipo.
EOF

# 3) Create a commit of the policy update (the hook will not block it).
git add SECURITY.md
git commit -q -m "chore(sec): install pre-commit hook and complete SECURITY.md"

echo "Solution applied."
echo "Try a blocked commit:"
echo "  echo 'AKIAIOSFODNN7EXAMPLE' > fake.env && git add fake.env && git commit -m test"
