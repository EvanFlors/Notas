# Ejemplo 01 — OIDC GitHub Actions → IAM Role

> Lectura y análisis. **No se despliega**. Objetivo: fijar visualmente el flujo OIDC y entender qué protege el pinning del claim `sub`.

## 1. El flujo, paso a paso

```
┌─────────────────────────────────────────────────────────────────────────┐
│ GitHub Actions job                                                      │
│   permissions:                                                          │
│     id-token: write    ◄── sin esto, GHA no emite OIDC token            │
│     contents: read                                                      │
│                                                                         │
│   steps:                                                                │
│     - uses: aws-actions/configure-aws-credentials@v4                    │
│       with:                                                             │
│         role-to-assume: arn:aws:iam::111122223333:role/gha-mirepo-prod  │
│         aws-region: us-east-1                                           │
└─────────────────────────────────────────────┬───────────────────────────┘
                                              │
                1. GHA pide OIDC token         │
                   a token.actions.github...   │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ JWT emitido por GitHub (ejemplo redactado)                              │
│   {                                                                     │
│     "iss":  "https://token.actions.githubusercontent.com",              │
│     "aud":  "sts.amazonaws.com",                                        │
│     "sub":  "repo:miorg/mirepo:ref:refs/heads/main",                    │
│     "repository": "miorg/mirepo",                                       │
│     "ref": "refs/heads/main",                                           │
│     "actor": "evan"                                                     │
│   }                                                                     │
└─────────────────────────────────────────────┬───────────────────────────┘
                                              │
                2. sts:AssumeRoleWithWebIdentity (JWT, RoleArn)
                                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ AWS STS                                                                 │
│   verifica firma JWT (OIDC provider en la cuenta)                       │
│   evalua trust policy del rol:                                          │
│     - Principal.Federated == OIDC provider ARN                          │
│     - Condition StringEquals aud == "sts.amazonaws.com"                 │
│     - Condition StringEquals sub == "repo:miorg/mirepo:ref:refs/heads/main"│
│   ─────────────────────────────                                         │
│   todas pasan ──► emite credenciales STS (duracion 1 h por defecto)     │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. La trust policy correcta (modelo)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:miorg/mirepo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Puntos clave:

1. `Principal.Federated` referencia el **ARN del OIDC provider en tu cuenta**, no el issuer directo.
2. `Action` es exactamente `sts:AssumeRoleWithWebIdentity`.
3. `aud` fijo a `sts.amazonaws.com` (lo que la action v4 pide por defecto).
4. `sub` **pinneado** con `StringEquals` a un ref concreto. Nada de wildcards.

## 3. Los errores clásicos (anti-patrones)

### 3.1 Wildcard total

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:*"
}
```

Cualquier repo de GitHub (incluso del atacante) puede asumir el rol. **Hallazgo crítico.**

### 3.2 Wildcard de ref dentro de tu repo

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:miorg/mirepo:*"
}
```

Cualquier **PR** (incluyendo PRs de forks externos cuyo workflow se ejecuta en tu repo) matchea. Un atacante abre un PR con un workflow que llama al rol de producción. **Hallazgo alto.**

### 3.3 Sin condición de `aud`

```json
"StringEquals": {
  "token.actions.githubusercontent.com:sub": "repo:miorg/mirepo:ref:refs/heads/main"
}
```

Pierde defensa en profundidad: si por algún camino un atacante consigue un JWT con `sub` falseado pero `aud` arbitrario, falta la segunda barrera. **Hallazgo medio.**

### 3.4 Rol compartido entre dev y prod

Un único rol asumible desde cualquier branch del repo. Perder el control de un branch de desarrollo = perder prod. **Hallazgo alto.** Patrón correcto: **un rol por environment** (`gha-mirepo-dev`, `gha-mirepo-stg`, `gha-mirepo-prod`) con `sub` pinneado a `:environment:dev|stg|prod` respectivamente.

## 4. Lectura

- La seguridad **no está** en la action ni en el workflow — está en la trust policy.
- La trust policy es declarativa, auditable y **lo único** que decide quién puede asumir ese rol.
- Un review de PR de infra que toque la trust policy debería requerir doble approver (patrón recomendado por el AWS SRA).

## 5. Preguntas

1. Si el pipeline tiene un job que corre en `main` y otro job que corre en PRs, ¿deberían asumir el mismo rol? Argumenta.
2. ¿Qué pasa si olvidas `permissions.id-token: write` en el workflow? ¿Falla en qué paso?
3. ¿Cuál es la diferencia operativa entre pinnear `sub` a `:ref:refs/heads/main` vs `:environment:prod`?
4. ¿Por qué el thumbprint del OIDC provider dejó de ser crítico en la práctica desde que AWS lo calcula automáticamente?
