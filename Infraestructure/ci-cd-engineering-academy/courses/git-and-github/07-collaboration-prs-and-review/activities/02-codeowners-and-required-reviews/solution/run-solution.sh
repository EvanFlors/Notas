#!/usr/bin/env bash
# Reference solution for gh-07-02-codeowners-and-required-reviews.
# Builds the starter and writes the 3 governance files, committing them.

set -euo pipefail

BASE="${1:-/tmp/codeowners-lab}"
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/build-repo.sh" "$BASE"

cd "$BASE"
export GIT_AUTHOR_NAME="Dev"
export GIT_AUTHOR_EMAIL="dev@example.com"
export GIT_COMMITTER_NAME="Dev"
export GIT_COMMITTER_EMAIL="dev@example.com"

mkdir -p .github

cat > .github/CODEOWNERS <<'EOF'
# acme-platform CODEOWNERS
# Última regla que matchea gana. Ordenamos: default -> globs -> paths.

# ── Default fallback ──
*                               @acme/maintainers

# ── Globs por tipo (expertos transversales) ──
*.py                            @acme/python-maintainers
*.tf                            @acme/platform-team
*.md                            @acme/docs-team

# ── Paths específicos (dueños de subsistema) ──
/docs/                          @acme/docs-team
/src/api/                       @acme/api-team
/src/web/                       @acme/frontend-team
/infra/                         @acme/platform-team

# ── Archivos críticos: doble owner obligatorio ──
/.github/workflows/             @acme/devops @acme/maintainers
/.github/CODEOWNERS             @acme/maintainers @acme/security
/SECURITY.md                    @acme/security @acme/maintainers
EOF

cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## Summary

<!-- 2–4 líneas: ¿qué resuelve y por qué? -->

## Changes

- ...

## Linked issues

Fixes #

## Test plan

- [ ] ...

## Risk / rollback

- Riesgo:
- Rollback:

## Checklist

- [ ] Diff ≤ 400 líneas.
- [ ] Tests nuevos o actualizados.
- [ ] Sin secretos ni credenciales.
EOF

cat > .github/review-policy.yaml <<'EOF'
# Política de reviewers aplicable a 'main'.
# Documental: GitHub la implementa vía Branch protection / Rulesets.

required_approvals: 1
require_codeowner_review: true
dismiss_stale_reviews_on_push: true
require_up_to_date_before_merge: true
restrict_who_can_push_to_main:
  - "@acme/maintainers"

# Rationale:
#   - 1 aprobación mínima + al menos 1 CODEOWNER balancea velocidad y seguridad en un equipo de 8.
#   - dismiss_stale_reviews_on_push evita que un push sorpresa pase bajo una aprobación vieja.
#   - require_up_to_date_before_merge garantiza que CI corra con el estado real que llega a main.
#   - solo @acme/maintainers pueden push directo (si acaso); el resto solo vía PR.
EOF

git add .github/CODEOWNERS .github/PULL_REQUEST_TEMPLATE.md .github/review-policy.yaml
git commit -q -m "feat(.github): add CODEOWNERS, PR template, review policy

Fixes #1"

echo
echo "Solution applied. Validate with:"
echo "  bash $HERE/../tests/validate.sh $BASE"
