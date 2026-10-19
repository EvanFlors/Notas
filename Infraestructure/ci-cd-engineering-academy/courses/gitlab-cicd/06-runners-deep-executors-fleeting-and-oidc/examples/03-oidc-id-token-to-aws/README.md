# Ejemplo 03 — OIDC desde GitLab a AWS (walkthrough)

Este ejemplo es un **walkthrough de 5 pasos**. No se ejecuta aquí (no hay cuenta AWS), pero cada paso te deja un artefacto listo para pegar en Fase 4.

## Paso 1 — Crear el OIDC provider en AWS

Una sola vez por cuenta AWS. Vía AWS CLI:

```bash
aws iam create-open-id-connect-provider \
  --url https://gitlab.com \
  --client-id-list "https://gitlab.com" \
  --thumbprint-list "a031c46782e6e6c662c2c87c76da9aa62ccabd8e"
```

El `thumbprint` cambia cuando GitLab rota el certificado. En Terraform es más mantenible (`aws_iam_openid_connect_provider` + `tls_certificate` data source).

## Paso 2 — Trust policy del role

Guarda este JSON como `trust-policy.json` y créalo con:

```bash
aws iam create-role \
  --role-name gitlab-deployer-prod \
  --assume-role-policy-document file://trust-policy.json
```

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitLabOIDCAcmeWebMainProd",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/gitlab.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "gitlab.com:aud": "https://gitlab.com"
        },
        "StringLike": {
          "gitlab.com:sub": "project_path:acme/web:ref_type:branch:ref:main:environment:production"
        }
      }
    }
  ]
}
```

Léelo despacio:

1. `Federated` apunta al provider del paso 1.
2. `aud` exige el audience que el job declarará en `id_tokens:`.
3. `sub` **pinado al proyecto `acme/web`, rama `main`, environment `production`**. Nadie más puede asumirlo.

## Paso 3 — Permission policy del role (least-privilege)

Aparte, adjuntas una policy con **lo que el deploy realmente necesita**. Ejemplo para un deploy S3 + invalidation CloudFront:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::acme-web-prod",
        "arn:aws:s3:::acme-web-prod/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
    }
  ]
}
```

Nunca `AdministratorAccess` para un deploy.

## Paso 4 — `.gitlab-ci.yml` del consumidor

```yaml
stages:
  - deploy

deploy-prod:
  stage: deploy
  image: amazon/aws-cli:2.17.0
  environment:
    name: production
    url: https://acme.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  id_tokens:
    AWS_ID_TOKEN:
      aud: "https://gitlab.com"
  variables:
    AWS_ROLE_ARN: "arn:aws:iam::111122223333:role/gitlab-deployer-prod"
    AWS_DEFAULT_REGION: "eu-west-1"
  script:
    - apk add --no-cache jq
    - >
      aws sts assume-role-with-web-identity
      --role-arn "$AWS_ROLE_ARN"
      --role-session-name "gitlab-${CI_PIPELINE_ID}"
      --web-identity-token "$AWS_ID_TOKEN"
      --duration-seconds 3600 > /tmp/creds.json
    - export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId /tmp/creds.json)
    - export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey /tmp/creds.json)
    - export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken /tmp/creds.json)
    - aws sts get-caller-identity
    - aws s3 sync ./dist s3://acme-web-prod --delete
    - aws cloudfront create-invalidation --distribution-id EDFDVBD6EXAMPLE --paths "/*"
```

Cosas que ya **no** necesitas en Variables de GitLab:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Solo `AWS_ROLE_ARN` (no es secreto; el `Condition` del role es quien protege).

## Paso 5 — Verificar que el `sub` es el esperado

Antes de confiar en el pinning, imprime el claim en un job de debug (una vez, no en prod):

```yaml
debug-sub:
  stage: deploy
  image: alpine:3.20
  id_tokens:
    DEBUG_TOKEN:
      aud: "https://gitlab.com"
  script:
    - apk add --no-cache jq
    - echo "$DEBUG_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.sub, .aud, .iss, .project_path, .ref, .environment'
```

Deberías ver algo como:

```
"project_path:acme/web:ref_type:branch:ref:main:environment:production"
"https://gitlab.com"
"https://gitlab.com"
"acme/web"
"main"
"production"
```

Si tu `sub` no incluye `:environment:production`, es porque el job no declara `environment:`. Añádelo o cambia la trust policy.

## Qué llevarse

- **Un provider OIDC por cuenta AWS**, muchos roles encima.
- **El `sub` es tu llave**: cuanto más estricto, menor radio de impacto.
- **Nunca** uses `"gitlab.com:sub": "*"`.
- Combina con **protected environments** (approvals) para prod.
