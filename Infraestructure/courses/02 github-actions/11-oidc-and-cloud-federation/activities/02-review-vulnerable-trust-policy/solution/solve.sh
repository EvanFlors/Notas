#!/usr/bin/env bash
# Reference solution for gha-11-02-review-vulnerable-trust-policy.
# NOTE: no `set -o pipefail` with grep -q producers (SIGPIPE false positives).
set -eu

BASE="${1:-/tmp/gha-oidc-audit}"
PROJECT="$BASE/project"
if [ ! -d "$PROJECT" ]; then
  echo "FAIL: $PROJECT not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

mkdir -p "$PROJECT/fixes"

# Fix 1 — prod from main: pin by environment:production (preferred).
cat > "$PROJECT/fixes/trust-policy-1.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AdminProdByEnvironment",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:production"
        }
      }
    }
  ]
}
JSON

# Fix 2 — release por tag: controlled wildcard tras refs/tags/.
cat > "$PROJECT/fixes/trust-policy-2.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReleaseTaggerByTagRef",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/tags/v*"
        }
      }
    }
  ]
}
JSON

# Fix 3 — CI read: wildcard controlado por branch, no PRs.
cat > "$PROJECT/fixes/trust-policy-3.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CIReadByBranchRef",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/heads/*"
        }
      }
    }
  ]
}
JSON

# Fix 4 — staging por environment exacto.
cat > "$PROJECT/fixes/trust-policy-4.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StagingByEnvironmentExact",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:staging"
        }
      }
    }
  ]
}
JSON

# audit.md
cat > "$PROJECT/audit.md" <<'MD'
# Audit — trust policies OIDC

## trust-policy-1.json — VULNERABLE
Pin del `sub` con `StringLike repo:MyOrg/*`. Cualquier repo (incluso uno recién
creado por un atacante dentro de la organización) puede asumir el rol
`github-admin-prod`. Dado el nombre del rol, el blast radius es toda la cuenta
prod. **Fix**: pin exacto a `repo:MyOrg/MyRepo:environment:production` y
combinar con required reviewers del environment.

## trust-policy-2.json — VULNERABLE
Pin con `StringLike repo:MyOrg/MyRepo:*`. El wildcard acepta *cualquier* sufijo
del `sub`: `ref:refs/heads/<branch-arbitrario>`, `pull_request`,
`environment:<cualquier-env>`. Si alguien abre un PR con un workflow
modificado que pide el token (y el repo permite ejecutar workflows de PRs
externos), lo asume. **Fix**: `StringLike repo:MyOrg/MyRepo:ref:refs/tags/v*`
limita a tags que empiezan por `v`.

## trust-policy-3.json — VULNERABLE
Solo verifica `aud=sts.amazonaws.com`. **Cualquier workflow de cualquier repo
de cualquier usuario de GitHub en el mundo** puede asumir el rol
`github-ci-read`. Es equivalente a "sin trust". Cross-tenant abuse.
**Fix**: añadir pin del `sub` por branch wildcard controlado
(`:ref:refs/heads/*`) o, si se quiere más restrictivo, por branch exacta.

## trust-policy-4.json — SAFE_BUT_WEAK
Pin por `StringLike repo:MyOrg/MyRepo:environment:*`. Al menos limita al repo
correcto, pero cualquier environment (dev, staging, production, uno nuevo
que alguien cree por error) permite asumir el rol *de staging*. Si por error
un workflow declara `environment: production` y la permission policy del
rol staging tiene (por error histórico) permisos sobre prod, hay escalada.
**Fix**: `StringEquals ... :sub = repo:MyOrg/MyRepo:environment:staging`
exacto.

## Patrones a nunca repetir
- `repo:<Org>/*` — nunca.
- `repo:<Org>/<Repo>:*` — casi nunca.
- Solo `aud` — nunca.
- `environment:*` — casi nunca.
MD

echo "Solution applied under $PROJECT/"
ls -R "$PROJECT"
