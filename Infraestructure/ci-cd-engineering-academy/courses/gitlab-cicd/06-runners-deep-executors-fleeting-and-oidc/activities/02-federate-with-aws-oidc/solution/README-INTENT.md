# README-INTENT — gl-06-02

## Trust policy — pinning

El role `gitlab-deployer-prod` confía exclusivamente en el **OIDC provider** `arn:aws:iam::111122223333:oidc-provider/gitlab.com`, instalado una sola vez en la cuenta AWS. La trust policy exige:

- **`aud` (StringEquals)** = `https://gitlab.com`. Impide que un token emitido para otro público (p. ej. HashiCorp Vault, Google Cloud) sea aceptado por AWS. El `aud` del token lo controla el pipeline en `id_tokens: { AWS_ID_TOKEN: { aud: "https://gitlab.com" } }`.
- **`sub` (StringLike)** = `project_path:acme/web:ref_type:branch:ref:main:environment:production`. Los claims que GitLab compone en el `sub` son, en orden:
  - `project_path:acme/web` — proyecto específico.
  - `ref_type:branch` — tipo de referencia (`branch` o `tag`).
  - `ref:main` — nombre exacto de la rama.
  - `environment:production` — nombre del environment declarado por el job.

Usamos `StringLike` (no `StringEquals`) porque permite comodines `*` si en el futuro queremos ampliar el match (p. ej. a `ref:release/*`); hoy no hay comodines y el pinning es exacto. Si quisiéramos aceptar también tags `v*.*.*`, duplicaríamos el `Statement` o combinaríamos en una lista de patrones.

Como capa adicional, `production` es un **protected environment** con *approval rules* (2 approvers). Nadie puede provocar un despliegue — y por tanto un `assume-role-with-web-identity` — sin aprobación humana.

## Antipatrones

Pinning inseguro que **no** debes aceptar en un review:

1. **`"gitlab.com:sub": "*"`** — cualquier job de cualquier proyecto de `gitlab.com` puede asumir el role. Esto convierte el role en un *shared secret* del tamaño de GitLab.com. Es la pesadilla.
2. **`"gitlab.com:sub": "project_path:acme/*"`** sobre un role con escritura — cualquier proyecto del group `acme` (incluyendo repos nuevos sin review) puede desplegar a prod. Útil **solo** si el role es estrictamente de solo-lectura (`s3:ListBucket`, `cloudwatch:GetMetric*`…).
3. **Omitir `aud`** — permite que un token emitido para otro destino (Vault) se re-use contra AWS si alguien exfiltra el JWT.
4. **Usar `StringEquals` con `*`** — `StringEquals` no interpreta el comodín; el match falla silenciosamente y el equipo "arregla" la trust policy aflojándola más de la cuenta.

## Pipeline consumidor

El job `deploy-prod` corre en el environment `production`, solo cuando `$CI_COMMIT_BRANCH == "main"`. Declara `AWS_ID_TOKEN` como ID Token con `aud: "https://gitlab.com"` y lo pasa a `aws sts assume-role-with-web-identity` (API STS `AssumeRoleWithWebIdentity`). La respuesta son **credenciales temporales STS** (1 hora, `--duration-seconds 3600`) que exporta como variables de entorno estándar de AWS para el resto del `script:`.

Variables que **ya no** aparecen en Settings → CI/CD → Variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Lo único que queda es `AWS_ROLE_ARN` dentro del `.gitlab-ci.yml` (no es secreto; el `sub`/`aud` del role es quien impide que otros lo asuman).

Duración de sesión: pedimos **3600 s** (1h). No pedimos más porque el ID Token de GitLab tiene vida corta y la `MaxSessionDuration` del role podría estar en 1h; una petición de 7200 s fallaría con `AccessDenied`.
