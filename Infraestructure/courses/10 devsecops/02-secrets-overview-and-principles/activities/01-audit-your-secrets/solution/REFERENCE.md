# REFERENCE — sec-02-01-audit-your-secrets

> Una **referencia** razonada sobre el modelo del capstone descrito en el README. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Contexto del proyecto auditado

Modelo del capstone: aplicación **FastAPI** empaquetada en Docker, construida en **GitHub Actions**, publicada a **GHCR**, desplegada en **Kubernetes** (EKS) vía **Argo CD**. Dependencias externas: **PostgreSQL** (RDS), **Redis** (ElastiCache), **Stripe** (pagos), **Datadog** (telemetry), **Sentry** (errors). Secretos involucrados: credenciales DB, keys SaaS, OIDC/JWT, firma de imágenes, SSH para deploy keys legacy y la clave de cifrado at-rest.

## Sección B — Inventario (modelo)

| secret_id | familia | hogar | owner | TTL | rotation | blast_radius | short_lived? |
|-----------|---------|-------|-------|-----|----------|--------------|--------------|
| `stripe_live_api_key` (ej: `sk_fake_live_...`) | api-key | 4 (AWS Secrets Manager) | payments | 365d | manual | alto | candidate (STS no aplica, pero scope-narrow) |
| `postgres_app_user_password` | db-cred | 4 (Secrets Manager) | platform | 90d | manual | alto | yes (migrar a Vault dynamic DB creds) |
| `datadog_api_key` | api-key | 2 (K8s Secret montado como env var) | observability | never | none | medio | no (Datadog no soporta OIDC general) |
| `datadog_api_key` (copia) | api-key | 1 (en un `helmfile.yaml` cometido) | observability | n/a | n/a | **catastrofico** | n/a |
| `ghcr_push_token` (classic PAT) | api-key | 2 (GitHub Actions secret) | platform | 90d | manual | alto | **yes** (migrar a OIDC + GitHub-provided GITHUB_TOKEN) |
| `aws_deploy_role_access_key` (AKIAFAKE...) | api-key | 2 (GH Actions secret) | platform | 730d | none | **catastrofico** | **yes** (OIDC federation con `aws-actions/configure-aws-credentials`) |
| `cosign_signing_key` | signing | 4 (Vault KV) | security | 180d | manual | alto | **yes** (migrar a cosign keyless/sigstore) |
| `tls_edge_privkey` (ingress) | cert | 4 (cert-manager + Secrets Manager) | platform | 60d | auto (cert-manager/ACME) | alto | yes (ACME ya es automático) |
| `ssh_legacy_bastion_key` | ssh | 3 (archivo cifrado SOPS en repo infra) | platform | never | none | medio | candidate (SSH CA + certificados cortos) |
| `jwt_signing_key_hmac` | signing | 5 (KMS alias) | platform | 365d | auto (envelope + versioning) | medio | n/a (ya está en KMS, bien) |
| `s3_backup_kek` (data encryption key) | encryption | 5 (KMS CMK) | data-eng | annual | auto | bajo | n/a |

(Observa cómo `datadog_api_key` aparece dos veces: una en el hogar legítimo (#2) y otra en el hogar prohibido (#1). Esa duplicación es precisamente lo que la plantilla pide hacer visible.)

## Sección C — Top 3 riesgos

1. **`datadog_api_key` cometido en `helmfile.yaml` (hogar #1).**
   - Blast radius **catastrófico**: aunque el repo sea privado, está en la historia; cualquier fork interno, cache de CI, backup o auditoría previa lo expone. Datadog puede enviar métricas falsas, consumir cuota, exfiltrar config.
   - **Acción**: `rotar primero → revocar la vieja en Datadog → `git filter-repo` para purgar historia → mover a Secrets Manager → referencia por secret ref en manifiesto`.
   - **Principio aplicado**: *un secreto en Git se asume comprometido para siempre* (§4.1 + §4.5).

2. **`aws_deploy_role_access_key` (AKIAFAKE..., 2 años, scope amplio).**
   - Blast radius **catastrófico**: si tiene `s3:*`/`iam:*` sobre la cuenta, es ownage. 730 días de ventana con `p_diaria=0.001` → >50 % de probabilidad acumulada.
   - **Acción**: migrar a **OIDC federation** con `aws-actions/configure-aws-credentials@v4`, rol narrow (`s3:PutObject` en el prefijo de releases), token 15 min. **Eliminar la key estática** y la pareja de GH Actions secrets.
   - **Principio aplicado**: *short-lived > long-lived* (§6) + *mínimo privilegio* (§5.2).

3. **`ghcr_push_token` (classic PAT, 90 días, manual).**
   - Blast radius **alto**: `write:packages` sobre la organización + típicamente scope `repo` por defecto. Si se filtra permite envenenar la supply chain publicando imágenes maliciosas.
   - **Acción**: usar `GITHUB_TOKEN` provisto por el runner con `permissions: packages: write`. Sin PAT estática.
   - **Principio aplicado**: *short-lived > long-lived* (§6) + *mínimo privilegio* por job (§5.2).

## Sección D — Plan a 90 días

1. **Semana 1 — stop the bleeding.**
   - Rotar `datadog_api_key` **y** limpiar la historia del repo (`git filter-repo`).
   - Rotar `aws_deploy_role_access_key` y revocar la vieja aunque todavía no esté migrada.
   - Motivo: son los dos riesgos catastróficos activos; cada día que pasan vivos degrada probabilidad.

2. **Semanas 2–4 — eliminar long-lived crítico #1 (AWS).**
   - Configurar OIDC trust policy en IAM; crear rol `ci-artifact-uploader` narrow.
   - Reemplazar `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` por `aws-actions/configure-aws-credentials@v4` + `role-to-assume`.
   - Verificar en pipeline y **borrar los secrets de GH Actions** antes de cerrar la semana 4.
   - Motivo: elimina el secret estático de mayor blast radius.

3. **Semanas 5–7 — eliminar long-lived crítico #2 (GHCR).**
   - Reemplazar `ghcr_push_token` por `GITHUB_TOKEN` con `permissions: packages: write` por job.
   - Borrar la PAT clásica.
   - Motivo: segunda clase de secret estático de alto riesgo supply-chain.

4. **Semanas 8–10 — DB creds dinámicas.**
   - Alta de Vault (o uso de RDS IAM auth donde el engine lo permita).
   - Reemplazar `postgres_app_user_password` por **dynamic DB creds** con TTL 1 h.
   - Motivo: elimina el secret long-lived "más usado" de la app.

5. **Semanas 11–12 — cosign keyless.**
   - Migrar firma de imágenes de `cosign_signing_key` a Sigstore keyless (OIDC del workflow + certificado efímero de Fulcio).
   - Borrar la signing key custodiada en Vault.
   - Motivo: cierra la última fuente large-lived relevante antes de que se institucionalice.

**Resultado al día 90**: 0 keys AWS estáticas, 0 PATs clásicas en pipeline, DB con creds dinámicas, firma keyless, Datadog como único long-lived restante (fuera del alcance de OIDC) pero correctamente aislado en secret manager + scope mínimo.

## Punto a repetir hasta que suene aburrido

> No se migran "los secretos" en abstracto: se **inventaría**, se **ordena por blast radius**, y se eliminan **long-lived primero** usando OIDC/WI/dynamic cuando el proveedor lo permite. Lo que queda, al secret manager con scope mínimo.
