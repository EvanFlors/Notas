#!/usr/bin/env bash
# Reference solution for gh-13-03-oidc-federation-to-cloud.
set -euo pipefail

BASE="${1:-/tmp/oidc-fed}"
PROJECT="$BASE/project"
if [ ! -d "$PROJECT" ]; then
  echo "FAIL: $PROJECT not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

# 1) trust-policy.json
cat > "$PROJECT/trust-policy.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsOIDC",
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

# 2) workflow
cat > "$PROJECT/.github/workflows/deploy.yml" <<'YAML'
name: deploy

on:
  push:
    branches: [main]
  workflow_dispatch: {}

permissions: {}

jobs:
  deploy:
    name: Deploy to production via OIDC
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/github-deploy
          role-session-name: GitHubActions-${{ github.run_id }}
          aws-region: eu-west-1

      - name: Who am I
        run: aws sts get-caller-identity
YAML

# 3) docs/oidc.md
cat > "$PROJECT/docs/oidc.md" <<'MD'
# OIDC federation GitHub Actions -> AWS

## Flujo

1. El workflow pide un **id-token** OIDC a GitHub (requiere `permissions: id-token: write`).
   GitHub emite un JWT firmado con claims: `iss`, `sub`, `aud`, `exp`, `repository`,
   `environment`, `actor`, `run_id`, etc.
2. La acción `aws-actions/configure-aws-credentials` llama a STS
   **`AssumeRoleWithWebIdentity`** con el JWT y el ARN del rol.
3. STS verifica la firma contra el **JWKS público** de GitHub, comprueba el
   trust policy del rol (`aud`, `sub`), y emite credenciales temporales
   (hasta 1h por default).
4. El workflow usa esas credenciales para hablar con AWS. Al terminar: desaparecen.

## Por qué el pin del `sub` es crítico

Sin un pin exacto del `sub`, **cualquier workflow de cualquier repo (incluido uno
nuevo que un atacante abra en tu org)** podría asumir el rol. El pin recomendado
para prod incluye el environment:

```
repo:MyOrg/MyRepo:environment:production
```

Esto, combinado con **environment approvals** del lado GitHub, exige revisión
humana antes de que el workflow pueda tan siquiera pedir el token OIDC con ese
`sub`. Doble barrera.

## Lo que necesita AWS

- Un **OIDC provider** (OpenID Connect) en IAM apuntando a
  `https://token.actions.githubusercontent.com` con `client-id-list` = `sts.amazonaws.com`.
  (Una vez por cuenta AWS.)
- Un rol IAM con el `trust-policy.json` que carga ese provider como `Principal.Federated`.

Cero credenciales de larga vida en GitHub. Cero rotación necesaria. Audit trail
completo tanto en GitHub (OIDC token request) como en CloudTrail (AssumeRoleWithWebIdentity).
MD

echo "Solution applied under $PROJECT/"
ls -R "$PROJECT"
