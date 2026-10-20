#!/usr/bin/env bash
# Reference solution for gha-11-01-federate-with-aws.
# NOTE: avoid `set -o pipefail` with grep -q producers (SIGPIPE false positives).
set -eu

BASE="${1:-/tmp/gha-oidc}"
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
      "Sid": "AllowGitHubActionsOIDCFromProd",
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
    name: Deploy to prod via OIDC
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
          role-to-assume: arn:aws:iam::000000000000:role/github-deploy-prod
          role-session-name: GitHubActionsProd-${{ github.run_id }}
          aws-region: eu-west-1

      - name: Who am I
        run: aws sts get-caller-identity
YAML

# 3) docs/oidc.md
cat > "$PROJECT/docs/oidc.md" <<'MD'
# OIDC federation GitHub Actions -> AWS (prod)

## Flujo

1. El workflow con `permissions: id-token: write` pide un JWT a GitHub en
   `$ACTIONS_ID_TOKEN_REQUEST_URL?audience=sts.amazonaws.com` usando el
   `$ACTIONS_ID_TOKEN_REQUEST_TOKEN` como bearer. GitHub firma el token con sus
   claves y lo devuelve. El JWT trae `iss`, `aud`, `sub`, `repository`,
   `environment`, `ref`, `workflow`, `actor`, `run_id`, etc.
2. La acción `aws-actions/configure-aws-credentials` llama a STS
   **`AssumeRoleWithWebIdentity`** con el JWT y el ARN del rol
   `github-deploy-prod`. STS verifica la firma contra el **JWKS público** de
   GitHub (`https://token.actions.githubusercontent.com/.well-known/jwks`),
   evalúa el trust policy del rol y emite credenciales temporales de hasta 1 h.
3. El workflow usa esas credenciales (variables `AWS_ACCESS_KEY_ID` que
   empieza con `ASIA...`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`,
   `AWS_REGION`). Al terminar el job: expiran.

## Por qué el pin del `sub` por `environment`

El claim `sub` que emite GitHub es determinista. Cuando el job declara
`environment: production`, el `sub` adopta la forma
`repo:MyOrg/MyRepo:environment:production`. Pinnear la trust policy a ese
valor exacto significa que **ningún otro workflow** —ni otro repo, ni otra
rama, ni el mismo repo sin environment— puede asumir el rol. Combinado con
*required reviewers* del environment en GitHub, se consigue doble barrera:
alguien aprueba manualmente el deploy *antes* de que el JWT se emita, y AWS
exige el `sub` exacto *después*.

Un pin solo por owner (`repo:MyOrg/*`) sería catastrófico: cualquier repo de
la organización (incluido uno nuevo que un atacante consiga crear) podría
asumir el rol.

## Lo que necesita AWS

- Un **OIDC provider** registrado en IAM apuntando a
  `https://token.actions.githubusercontent.com` con `client-id-list` =
  `sts.amazonaws.com`. Se crea una vez por cuenta.
- Un rol IAM (`github-deploy-prod`) cuyo `AssumeRolePolicyDocument` sea el
  `trust-policy.json` de este repo, cargando ese OIDC provider como
  `Principal.Federated` y aplicando la Condition del `aud` y el `sub`.
- La permission policy del rol se mantiene en mínimo privilegio y es
  independiente del trust.

Resultado: cero credenciales AWS de larga vida en GitHub, cero rotación,
auditoría completa en GitHub (OIDC token request) y en CloudTrail
(`AssumeRoleWithWebIdentity` con `role-session-name` incluyendo el `run_id`).
MD

echo "Solution applied under $PROJECT/"
ls -R "$PROJECT"
