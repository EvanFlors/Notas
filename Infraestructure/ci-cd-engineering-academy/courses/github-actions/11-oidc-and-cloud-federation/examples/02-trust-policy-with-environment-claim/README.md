# Ejemplo 02 — Trust policy pinneada por `environment:` claim

## Concepto que demuestra

Variante del ejemplo 01 pensada para **producción**: la trust policy exige que el `sub` del JWT sea exactamente `repo:MyOrg/MyRepo:environment:production`. Esto solo lo emite GitHub cuando el job declara `environment: production`, lo cual **a su vez** dispara las *deployment protection rules* (approvals, wait timers, deployment branches, custom rules). Doble barrera: GitHub exige el gate antes de emitir el JWT; AWS exige exactamente ese `sub` para dejar asumir el rol.

## Por qué es más fuerte que pinnear por `ref:refs/heads/main`

- Si alguien consigue mergear a `main` sin revisión (misconfig de branch protection, acceso directo con bypass), un pin por `ref` ya le vale para asumir. Un pin por `environment:production` **todavía** exige que, al menos, un reviewer apruebe el deploy.
- Permite deployar desde ramas no-main (p. ej., hotfix) sin reescribir la trust: cualquier rama que apruebe el environment vale.
- La `environments` del repo es un recurso de GitHub con audit propio: cada aprobación queda registrada en el `deployments` API.

## Archivos

- `trust-policy.json` — Pin del `sub` por `environment:production`.
- `deploy.yml` — Job con `environment: production` + `permissions: id-token: write`.

## Setup del lado GitHub

1. Repo → Settings → Environments → New environment → `production`.
2. En el environment, añadir:
   - **Required reviewers**: 1+ miembros del equipo.
   - **Deployment branches**: `main` solamente (segunda capa, por si acaso).
   - (Opcional) **Wait timer**: 5 min.

Nada de esto está en el workflow — vive en la UI/API del repo. La única señal en el YAML es `environment: production`.

## Setup del lado AWS

Idéntico al ejemplo 01, con el `trust-policy.json` adjunto a este ejemplo:

```bash
aws iam create-role \
  --role-name github-deploy-prod \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name github-deploy-prod \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

## Flujo ASCII

```
push a main                                           GitHub                       AWS STS
     │                                                   │                            │
     ▼                                                   │                            │
┌────────────┐                                           │                            │
│ job        │ environment: production                  │                            │
│ waiting... │ ────── (gate) ────────────────────────▶  │                            │
│            │                                           │  reviewer approves          │
│            │ ◀───────────────────────────────────────  │                            │
│ job running│                                           │                            │
│            │ GET id-token (audience=sts.amazonaws.com)│                            │
│            │ ──────────────────────────────────────▶   │                            │
│            │ ◀─── JWT con sub=repo:MyOrg/MyRepo:      │                            │
│            │       environment:production              │                            │
│            │                                                                        │
│            │ sts:AssumeRoleWithWebIdentity(JWT)                                     │
│            │ ──────────────────────────────────────────────────────────────────────▶│
│            │                                                            trust OK?  │
│            │                                                            aud ✓ sub ✓ │
│            │ ◀─────────── creds temporales (ASIA...) ────────────────────────────── │
└────────────┘
```

## Combinaciones recomendadas

| Entorno | `sub` recomendado | Deployment branches |
|---|---|---|
| `production` | `repo:Org/Repo:environment:production` + required reviewers | `main` |
| `staging` | `repo:Org/Repo:environment:staging` | `main`, `release/*` |
| `dev` | `repo:Org/Repo:environment:dev` (sin approval) | `*` |
| CI genérico sin env | `repo:Org/Repo:ref:refs/heads/*` (branch wildcard controlado) | — |

## Advertencia sutil

Si el job declara `environment: production` **y** la trust pinnea por `ref:refs/heads/main`, el `sub` del JWT va a ser `repo:...:environment:production` (gana el environment) y la trust **no match**. El `environment:` **sustituye** al `ref:` en el `sub`. Si quieres doble match "main + environment", el pin tiene que ir por `environment:` y usas `deployment branches: [main]` del lado GitHub.
