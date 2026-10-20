# Actividad 01 — Pipeline WIF sin keys estáticas (TF plan + GHA + ADR)

## 1. Identificación

- **ID:** `gcp-10-01-wif-pipeline-no-keys-adr`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-10-devsecops-platform-wif-binauthz-finops`
- **Dificultad:** advanced
- **Duración estimada:** 100–120 min
- **Tipo:** architecture (independent — sin dependencia de 02 ni 03)

## 2. Contexto

Tu organización tiene hoy un pipeline en GitHub Actions que publica imágenes a Artifact Registry usando una **service account key JSON** guardada en `secrets.GCP_SA_KEY`. La key fue creada hace 14 meses, no se ha rotado, tiene `roles/editor` sobre el project, y Security Command Center la señala cada semana como riesgo. El equipo quiere eliminar la key completamente antes del próximo audit.

Tu encargo: **diseñar y escribir** el pipeline nuevo basado en Workload Identity Federation. No vas a aplicar nada: el entregable son **archivos Terraform** (que un operador podría `terraform plan` y `apply` en Fase 4), el **workflow de GitHub Actions**, y un **ADR** que explica las decisiones.

**Importante**: no hay project GCP real. No se provisiona nada. Los IDs son placeholders (`my-project-123`, pool, provider, etc.). **No se incurre en coste.**

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir TF que define pool + provider OIDC + binding sobre una SA.
- Pinnear el provider al repo correcto vía `attribute_condition`.
- Escribir un workflow GHA con `permissions: id-token: write` y la action `google-github-actions/auth@v2`, **sin** usar `secrets.GCP_SA_KEY`.
- Justificar el pinning y el principio de mínimo privilegio en el ADR.

## 4. Prerrequisitos

- `gcp-02` (IAM + impersonation), `gcp-09` (org / cloud identity).
- Herramientas: `bash`, `grep`, `terraform` (opcional — solo para `fmt`/`validate`, no se requiere auth GCP). Un editor Markdown/YAML/HCL.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-10-01-wif/terraform
mkdir -p /tmp/gcp-10-01-wif/.github/workflows
cd /tmp/gcp-10-01-wif
```

Puedes usar otro directorio y pasarlo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `terraform/wif.tf`

Debe definir **al menos**:

- `google_iam_workload_identity_pool` (pool `github-pool` o similar).
- `google_iam_workload_identity_pool_provider` con:
  - `oidc { issuer_uri = "https://token.actions.githubusercontent.com" }`
  - `attribute_mapping` incluyendo `google.subject`, `attribute.repository`, `attribute.ref`.
  - `attribute_condition` que referencia **`assertion.repository`** (pinning al repo).
- `google_service_account` para el publisher.
- `google_service_account_iam_member` con `role = "roles/iam.workloadIdentityUser"` y `member = "principalSet://..."` filtrando por `attribute.repository`.
- Al menos un recurso de permisos sobre Artifact Registry (`google_artifact_registry_repository_iam_member`) con rol **`roles/artifactregistry.writer`** (no `writer` + roles amplios).

### 5.3 Escribe `.github/workflows/publish.yml`

- `on: push: branches: [main]`.
- `permissions: id-token: write` (y `contents: read`).
- Usa `google-github-actions/auth@v2` con `workload_identity_provider` y `service_account`.
- **No** debe aparecer en el archivo `secrets.GCP_SA_KEY` ni similar.
- Build + push de la imagen a `europe-west1-docker.pkg.dev/<project>/<repo>/<name>:${{ github.sha }}` (los IDs pueden ser placeholders).

### 5.4 Escribe `ADR-WIF-PIPELINE.md`

Secciones obligatorias (el validador las busca):

1. `# ADR` en el título.
2. `## Estado` (o `## Status`).
3. `## Contexto` (o `## Context`).
4. `## Decisión` (o `## Decision`).
5. `## Consecuencias` (o `## Consequences`).
6. `## Alternativas` (o `## Alternatives` — al menos 2 descartadas).

Contenido mínimo (el validador comprueba tokens):

- Menciona **Workload Identity Federation** (o WIF).
- Menciona **GitHub Actions** y **Artifact Registry**.
- Menciona **`attribute_condition`** o `attribute.repository` (prueba de que entiendes el pin).
- Menciona explícitamente que **no se usan service account keys**.
- Al menos 2 alternativas descartadas (subheadings o items numerados).

> **Nota**: no uses el nombre `ANALYSIS.md`. Usa `ADR-WIF-PIPELINE.md`.

### 5.5 Entregables

```
/tmp/gcp-10-01-wif/
├── terraform/wif.tf
├── .github/workflows/publish.yml
└── ADR-WIF-PIPELINE.md
```

## 6. Validación

```bash
bash tests/validate.sh /tmp/gcp-10-01-wif
```

El validador comprueba **estructura** (no semántica real contra GCP). Compara con `solution/REFERENCE.md` para autoevaluarte.

## 7. Preguntas de reflexión

1. ¿Qué pasa si olvidas `attribute_condition` pero el binding en la SA sí filtra por `attribute.repository`? ¿Hay riesgo? ¿Cuál?
2. ¿Por qué el workflow necesita `id-token: write` explícitamente? ¿Qué es inseguro de activarlo globalmente?
3. ¿Cómo rotarías esta configuración si el repo cambia de nombre (`acme/checkout` → `acme/checkout-service`)?
4. Si otros 10 repos necesitan publicar imágenes, ¿crearías 10 pools, 10 providers o 10 bindings? ¿Por qué?

## 8. Limpieza

```bash
rm -rf /tmp/gcp-10-01-wif
```
