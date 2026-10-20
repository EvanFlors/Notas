# Ejemplo 01 — OIDC AWS AssumeRole

## Concepto que demuestra

Workflow mínimo que **asume un rol IAM en AWS** vía OIDC, sin ningún `AKIA...` ni `secrets.AWS_*` de larga vida. Trust policy pinneada a `repo:MyOrg/MyRepo:ref:refs/heads/main` (variante por branch; para `environment`, ver el ejemplo 02).

## Contexto

Reemplazo directo del patrón "clásico" `aws configure set aws_access_key_id ...` dentro del workflow. Vale para CI (lectura/describe), deploys desde `main`, publicación de artefactos a S3, etc.

## Archivos

- `trust-policy.json` — se adjunta al rol IAM (en la cuenta AWS). `AWS-ACCOUNT-ID` y `MyOrg/MyRepo` son placeholders.
- `deploy.yml` — se copia a `.github/workflows/deploy.yml` del repo.

## Setup del lado AWS (una sola vez por cuenta)

```bash
# 1) Registrar GitHub como OIDC provider (una vez por cuenta)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2) Crear el rol con el trust policy adjunto
aws iam create-role \
  --role-name github-deploy \
  --assume-role-policy-document file://trust-policy.json

# 3) Adjuntar permisos (minimum privilege; aquí: solo lectura como demo)
aws iam attach-role-policy \
  --role-name github-deploy \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

## Flujo ASCII

```
push a main                       OIDC                     STS                     AWS API
     │                              │                       │                        │
     ▼                              │                       │                        │
┌───────────┐  id-token (JWT)  ┌─────────────┐  AssumeRoleWithWebIdentity           │
│ runner    │ ───────────────▶ │ GitHub IdP  │ ─────────────▶ ┌──────────────┐     │
│ deploy    │ ◀─ JWT firmado ─ └─────────────┘                │ verifica JWT │     │
│ job       │                                                 │ aplica trust │     │
│           │ ──────────────── POST ─────────────────────────▶│ emite creds  │     │
│           │ ◀─────────── creds temporales (ASIA...) ──────── └──────────────┘     │
│           │ ────────── aws sts get-caller-identity ──────────────────────────────▶
│           │ ◀─────── Arn: arn:aws:sts::ACCOUNT:assumed-role/github-deploy/... ───
└───────────┘
```

## Cómo leerlo

- `permissions: {}` top-level: por defecto *nada*. Elevamos lo mínimo en el job.
- `id-token: write` en el job `deploy`: imprescindible para pedir el JWT.
- `role-session-name` incluye `run_id` → en CloudTrail puedes correlacionar la session con el run exacto.
- Trust policy: `StringEquals` sobre `aud` **y** sobre `sub` → match exacto. Si cambias de branch, no match.

## Variación: por tag

Si deployas por tag en vez de branch, el `sub` cambia a:

```
repo:MyOrg/MyRepo:ref:refs/tags/v1.2.3
```

y en la trust puedes aceptar un wildcard controlado:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/tags/v*"
}
```

## Qué pasa si falla

- `Could not load credentials` → falta `id-token: write`.
- `Not authorized to perform sts:AssumeRoleWithWebIdentity` → el `sub` real no coincide con la Condition. Dumpéalo (ver §7.6 de la lección).
- `InvalidIdentityToken` → el OIDC provider no está registrado, o lo está con otra URL.

Siguiente paso recomendado: ver `../02-trust-policy-with-environment-claim/` para el pin por environment (recomendado para prod).
