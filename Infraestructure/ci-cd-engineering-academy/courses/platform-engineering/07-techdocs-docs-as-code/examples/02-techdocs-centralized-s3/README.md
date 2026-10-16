# Example 02 — TechDocs centralized con S3 (walkthrough)

Este ejemplo es **walkthrough-only**: muestra el pipeline CI y la configuración Backstage que juntos implementan el modo *centralized* publicando a **AWS S3**. No se ejecuta porque requiere cuenta AWS y bucket real. El patrón es idéntico para `googleGcs` y `azureBlobStorage` — cambia solo el `publisher-type`.

## Topología

```
   repo del servicio                      Backstage
   ─────────────────                      ─────────
   docs/*.md                              app-config.yaml
   mkdocs.yml                             (publisher: awsS3)
   catalog-info.yaml                             │
          │                                      │
          │ push a main                          │
          ▼                                      │
   GitHub Actions                                │
   ─────────────                                 │
   techdocs-cli generate                         │
   techdocs-cli publish --publisher-type awsS3   │
          │                                      │
          ▼                                      │
     S3 bucket  ◄───────── lee ──────────────────┘
   platform-techdocs-prod/
     default/component/<name>/
       index/
       index.html, ...
```

El **punto clave:** Backstage **no genera** HTML. Solo lee el bucket. El coste del render se amortiza a 1 vez por commit (en CI), no 1 vez por request (en Backstage).

## Pipeline — `.github/workflows/techdocs.yml`

```yaml
name: techdocs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'
      - 'catalog-info.yaml'
  workflow_dispatch:

concurrency:
  group: techdocs-${{ github.ref }}
  cancel-in-progress: true

permissions:
  id-token: write        # OIDC federado hacia AWS
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install TechDocs toolchain
        run: |
          npm install -g @techdocs/cli
          pip install mkdocs mkdocs-techdocs-core

      - name: Build site (strict)
        run: |
          mkdocs build --strict --site-dir ./_site_check
          rm -rf ./_site_check   # solo para fallar temprano si hay link roto

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/techdocs-publisher
          aws-region: us-east-1

      - name: Generate & publish
        run: |
          ENTITY="default/component/${{ github.event.repository.name }}"
          techdocs-cli generate --no-docker --verbose
          techdocs-cli publish \
            --publisher-type awsS3 \
            --storage-name "$TECHDOCS_BUCKET" \
            --awsBucketRootPath "" \
            --entity "$ENTITY"
        env:
          TECHDOCS_BUCKET: platform-techdocs-prod
```

### Qué observar en el pipeline

- **OIDC, no access keys.** `id-token: write` + `role-to-assume` → cero secretos rotables.
- **`paths:` filter.** Un cambio en `src/` no re-publica docs. Reduce latencia y coste.
- **`mkdocs build --strict` *antes* de publish.** Doble pasada deliberada: el build strict detecta links rotos y falla el PR antes de ensuciar el bucket. (En optimización final se puede consolidar).
- **`concurrency` group.** Dos pushes rápidos a main no se pisan.
- **`entity` triplete.** `default/component/<name>` — `techdocs-cli` lo usa como path prefix dentro del bucket. Debe coincidir con el `metadata.namespace/kind/name` del `catalog-info.yaml` o Backstage no lo encuentra.

## IAM role (resumen)

Trust policy del `techdocs-publisher` role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:example-org/*:ref:refs/heads/main" }
    }
  }]
}
```

Permisos del role (mínimo):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::platform-techdocs-prod",
      "arn:aws:s3:::platform-techdocs-prod/*"
    ]
  }]
}
```

## `app-config.yaml` de Backstage

```yaml
techdocs:
  builder: external         # 👈 CLAVE: Backstage NO genera
  generator:
    runIn: local            # irrelevante en external, pero debe estar
  publisher:
    type: awsS3
    awsS3:
      bucketName: platform-techdocs-prod
      region: us-east-1
      # Credenciales: IRSA si corres en EKS, o chain default (SDK) con instance profile.
```

## Bucket — buenas prácticas

- **Versioning encendido** (recuperarte de un publish defectuoso con revert).
- **Server-side encryption** (SSE-S3 mínimo, SSE-KMS si política de org lo exige).
- **Sin ACL público.** Backstage lee con credenciales; el bucket es privado.
- **Lifecycle rule mínimo:** expirar versiones no-current después de 90 días. **No** mover a Glacier (las docs son hot data).
- **CORS:** no se necesita porque Backstage proxy-serves los assets.

## Coste

Órdenes de magnitud (us-east-1, 2026 pricing):

- 500 Components × 10 MB cada uno = 5 GB → **~$0.12/mes** de storage.
- Request cost: dominado por `GetObject` desde Backstage (cacheable). Despreciable (< $5/mes salvo que Backstage no cachee nada).

## Walkthrough — qué NO ejecutar aquí y por qué

- `techdocs-cli publish` real: requeriría un bucket + IAM role reales. Fuera del scope del módulo (y violaría la regla "no cloud cost").
- Levantar Backstage en modo external: requeriría una instancia Backstage ya desplegada (`plat-04`). Se cubre en el capstone.

## Variantes GCS / Azure

```yaml
# GCS
publisher:
  type: googleGcs
  googleGcs:
    bucketName: platform-techdocs-prod
    credentials: ${GOOGLE_APPLICATION_CREDENTIALS_JSON}   # o Workload Identity en GKE

# Azure Blob
publisher:
  type: azureBlobStorage
  azureBlobStorage:
    containerName: techdocs
    credentials:
      accountName: platformtechdocsprod
      # auth por Managed Identity preferido
```

Mismo CLI: `techdocs-cli publish --publisher-type googleGcs` / `azureBlobStorage`.

## Checklist para pasar de in-situ a centralized

- [ ] Bucket creado + IAM role con OIDC trust.
- [ ] Pipeline CI en todos los repos "golden path" (vía template Backstage).
- [ ] `app-config.yaml` con `builder: external`.
- [ ] Un servicio piloto publicando y visible en Backstage.
- [ ] Comunicación interna (changelog) explicando el cambio al resto de equipos.
- [ ] Deprecar modo in-situ en la staging instance (si existía).
