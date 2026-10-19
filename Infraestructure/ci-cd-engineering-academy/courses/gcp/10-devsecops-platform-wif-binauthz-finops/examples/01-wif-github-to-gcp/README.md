# Ejemplo 01 — WIF desde GitHub Actions a GCP (lectura y análisis)

**No se ejecuta nada.** Es un ejemplo demostrativo para leer, discutir y entender.

## 1. Objetivo

Mostrar la anatomía mínima de un pipeline GitHub Actions que publica una imagen a Artifact Registry **sin usar una service account key**. Toda la autenticación va vía Workload Identity Federation.

## 2. Terraform mínimo (lado GCP)

```hcl
# Pool: agrupador lógico para "GitHub Actions".
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
  description               = "WIF pool para repos de la org acme"
}

# Provider OIDC dentro del pool.
resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  # Pin: solo el repo acme/checkout puede usar este provider.
  attribute_condition = "assertion.repository == \"acme/checkout\""
}

# Service account que el pipeline impersona.
resource "google_service_account" "gha_publisher" {
  account_id   = "gha-publisher"
  display_name = "GitHub Actions image publisher"
}

# Binding: solo tokens del repo acme/checkout pueden impersonar la SA.
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.gha_publisher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/acme/checkout"
}

# Permiso de la SA: escribir en el repo Artifact Registry concreto.
resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = "my-project-123"
  location   = "europe-west1"
  repository = "prod-images"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.gha_publisher.email}"
}
```

## 3. Workflow (lado GitHub Actions)

```yaml
# .github/workflows/publish.yml
name: build-and-publish
on:
  push:
    branches: [main]

permissions:
  id-token: write   # necesario para OIDC
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-oidc
          service_account: gha-publisher@my-project-123.iam.gserviceaccount.com

      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud auth configure-docker europe-west1-docker.pkg.dev --quiet

      - name: Build & push
        run: |
          docker build -t europe-west1-docker.pkg.dev/my-project-123/prod-images/checkout:${{ github.sha }} .
          docker push europe-west1-docker.pkg.dev/my-project-123/prod-images/checkout:${{ github.sha }}
```

## 4. Qué observar

1. **No hay `secrets.GCP_SA_KEY`**. No existe tal secret.
2. `permissions: id-token: write` es imprescindible: habilita a GHA emitir el OIDC JWT.
3. `attribute_condition` pinnea el provider al repo. Un fork malicioso que intente impersonar es rechazado en el intercambio del token.
4. El binding en la SA usa `principalSet://...attribute.repository/acme/checkout` como **segunda defensa**. Si olvidaras el `attribute_condition`, el binding seguiría filtrando.
5. La SA tiene **solo** `roles/artifactregistry.writer` sobre **solo** el repo `prod-images`. Es el principio de mínimo privilegio aplicado al pipeline.

## 5. Qué pasa si falla la validación OIDC

- Si `attribute_condition` no se cumple → `AuthorizeToken` falla con `PERMISSION_DENIED` y Audit Logs muestra el claim que no matchea.
- Si el binding en la SA no incluye tu `principalSet://...` → `GenerateAccessToken` falla.
- Si tu `service_account` en el workflow no existe → auth falla antes del intercambio.

## 6. Pregunta de discusión

¿Qué pasa si cambias `attribute.repository == 'acme/checkout'` por `startsWith(assertion.repository, 'acme/')`? ¿Por qué ese cambio sería inseguro aunque "funcione"?
