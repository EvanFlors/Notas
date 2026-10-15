# Ejemplo 03 — OIDC desde GitHub Actions a AWS (sin secretos)

**Lectura y modelo mental**: no se aplica a una cuenta real aquí. La aplicación completa vive en `gh-13`.

## Qué contiene

- `files/trust-policy.json` — IAM trust policy del role que Actions asume. **Dummy account ID y role ARN** (placeholders claramente marcados).
- `files/workflow-oidc.yaml` — workflow Actions con `permissions: id-token: write` + `aws-actions/configure-aws-credentials`.
- `files/README-trust-policy.md` — explicación campo a campo.

## Idea en 90 segundos

```
Actions runner  ──(JWT con claims repo/ref/env)──▶  AWS STS
                                                      │
                                        valida JWT contra JWKS pública
                                        de GitHub + claims en trust policy
                                                      │
                                 crea credencial temporal (15 min)
                                                      ▼
                                        AWS SDK en el job
```

## Validar offline

```bash
cd /tmp && cp -r "$(dirname "$0")/files" /tmp/oidc-demo && cd /tmp/oidc-demo
python3 -c "import json; d=json.load(open('trust-policy.json')); \
  assert d['Version']=='2012-10-17'; \
  stmt=d['Statement'][0]; \
  assert stmt['Action']=='sts:AssumeRoleWithWebIdentity'; \
  cond=stmt['Condition']['StringLike']['token.actions.githubusercontent.com:sub']; \
  assert 'repo:' in cond; \
  print('OK: trust policy structure válida.')"
```

## Qué hay que entender

1. El `sub` claim del JWT identifica *qué* ejecutó el workflow. Ejemplos:
   - `repo:my-org/payments-api:ref:refs/heads/main`
   - `repo:my-org/payments-api:environment:production`
   - `repo:my-org/payments-api:pull_request`
2. El trust policy restringe por `sub`. **Nunca** `repo:my-org/*` salvo decisión explícita.
3. El workflow debe declarar `permissions: id-token: write` (no se hereda).
4. AWS devuelve credenciales de **15 min** por default (configurable hasta 12 h).

## Qué NO cubre este ejemplo

- Crear el OIDC provider en AWS (`aws iam create-open-id-connect-provider`).
- Validar la cadena en vivo.
- Workload Identity Federation en GCP / federated credentials en Azure (análogos conceptuales).

→ Ver `gh-13-github-security-and-supply-chain`.

## Limpieza

```bash
rm -rf /tmp/oidc-demo
```
