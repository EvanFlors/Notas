# Actividad 01 — Pipeline OIDC GHA → AWS, sin access keys humanas

## 1. Identificación

- **ID:** `aws-16-01-full-oidc-pipeline-no-keys`
- **Tecnología:** `aws`
- **Módulo:** `aws-16-devsecops-on-aws`
- **Dificultad:** advanced
- **Duración estimada:** 90–120 min
- **Tipo:** mini-project

## 2. Contexto

Vas a construir, **en local y sin desplegar nada en AWS**, los tres artefactos que forman un pipeline con autenticación OIDC:

1. **Terraform HCL** del `aws_iam_openid_connect_provider` para `token.actions.githubusercontent.com` y un `aws_iam_role` con trust policy que pinnea el claim `sub` a un repo y un ref exactos.
2. **Workflow de GitHub Actions** que consume el rol usando `aws-actions/configure-aws-credentials@v4`, con `permissions.id-token: write` **a nivel de job** (no global).
3. **ADR** (`ADR-oidc-sub-pinning.md`) que defiende por qué pinnear `sub` con `StringEquals` a `repo:ORG/REPO:ref:refs/heads/main` es necesario y por qué `StringLike` con wildcard es inaceptable.

**No se despliega nada.** Validamos con `terraform validate` (que **no** requiere credenciales), estructura (grep) y, si está instalado, Checkov para análisis estático del HCL.

## 3. Objetivos

Al terminar deberías poder, sin mirar la lección:

- Escribir desde cero el bloque mínimo de Terraform para OIDC provider + IAM Role.
- Pinnear el `sub` correctamente para 3 patrones (`main`, `environment: prod`, `tags/v*`).
- Explicar en un ADR por qué los wildcards en `sub` son un hallazgo crítico.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 1-2).
- Haber recorrido `../../examples/01-oidc-gha-to-aws-role/`.
- Herramientas **obligatorias**: `bash`, `terraform` (>= 1.5), un editor.
- Herramientas **opcionales** (si faltan, el validador reporta `SKIP`):
  - `checkov` — análisis estático HCL.
  - `trivy` — segundo análisis estático HCL.

**Costos:** cero. No se despliega nada.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-16-01-oidc
cd /tmp/aws-16-01-oidc
```

Puedes usar otro directorio pasándoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribir `terraform/main.tf`

Debe contener **al menos**:

- `terraform { required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } } }` y `required_version`.
- `provider "aws"` con `region` fija (p. ej. `us-east-1`).
- `aws_iam_openid_connect_provider` con:
  - `url = "https://token.actions.githubusercontent.com"`
  - `client_id_list = ["sts.amazonaws.com"]`
  - `thumbprint_list` con al menos un thumbprint (AWS lo recalcula; incluye uno de referencia).
- `aws_iam_role` con `assume_role_policy` (data source `aws_iam_policy_document` o `jsonencode`) que:
  - `principals { type = "Federated", identifiers = [aws_iam_openid_connect_provider.github.arn] }`.
  - `actions = ["sts:AssumeRoleWithWebIdentity"]`.
  - `condition` con `test = "StringEquals"` sobre `token.actions.githubusercontent.com:aud = "sts.amazonaws.com"`.
  - `condition` con `test = "StringEquals"` sobre `token.actions.githubusercontent.com:sub = "repo:miorg/mirepo:ref:refs/heads/main"` (o un placeholder equivalente).
- **NO** debe aparecer en todo el archivo: `StringLike` combinado con wildcard en `sub`, ni `aws_access_key_id`, ni `aws_secret_access_key`, ni un `sub` igual a `repo:*`.

### 5.3 Escribir `terraform/variables.tf` y `terraform/outputs.tf`

- `variables.tf`: variable para el repo (`github_repo` como `"miorg/mirepo"`), para el ref (`github_ref` como `"refs/heads/main"`), para el nombre del rol.
- `outputs.tf`: output `role_arn` del `aws_iam_role` creado.

### 5.4 Escribir `.github/workflows/deploy.yml`

Workflow mínimo que:

- Se dispara en `push` sobre `main`.
- Define `permissions.id-token: write` y `permissions.contents: read` **a nivel de job** (no al top).
- Usa `aws-actions/configure-aws-credentials@v4` con `role-to-assume: <ARN placeholder>` y `aws-region`.
- Hace una llamada read-only de verificación: `aws sts get-caller-identity`.
- **NO** menciona `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` en ningún sitio.

### 5.5 Escribir `ADR-oidc-sub-pinning.md`

ADR en el formato estándar (`Context`, `Decision`, `Consequences`, `Alternatives`). Debe:

- Explicar qué protege el pinning del `sub` claim.
- Comparar `StringEquals` con un ref exacto vs `StringLike` con wildcard.
- Mencionar al menos **3 patrones** de `sub` recomendados (`refs/heads/main`, `environment:prod`, `refs/tags/v*`).
- Dar al menos **una** consecuencia negativa de pinning estricto (p. ej. fricción al cambiar de branch default) y cómo mitigarla.

### 5.6 Validación local

```bash
cd terraform
terraform init -backend=false
terraform validate
cd ..
bash <ruta-repo>/courses/aws/16-devsecops-on-aws/activities/01-full-oidc-pipeline-no-keys/tests/validate.sh /tmp/aws-16-01-oidc
```

El validador:

- Comprueba que los 4 artefactos existen.
- Hace `grep` estructural sobre el HCL (presencia de condiciones, ausencia de access keys).
- Si `terraform` está instalado, corre `terraform init -backend=false` y `terraform validate` (sin credenciales AWS).
- Si `checkov` está instalado, lo corre sobre `terraform/`.
- Si `trivy` está instalado, corre `trivy config terraform/`.
- Si falta `checkov` o `trivy`, los reporta como `SKIP` (no es un fallo).

## 6. Resultado esperado

Estructura final en el directorio de trabajo:

```
/tmp/aws-16-01-oidc/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── .github/
│   └── workflows/
│       └── deploy.yml
└── ADR-oidc-sub-pinning.md
```

Y el validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: `terraform validate` pasa; validador estructural pasa.
- **Seguridad**: no hay `StringLike` con wildcard en `sub`, no hay access keys hardcodeadas.
- **Calidad**: ADR articulado, con `Context`, `Decision`, `Consequences`, `Alternatives`.
- **Reproducibilidad**: cualquiera que lea el repo entiende qué asume el rol y bajo qué condiciones.

## 8. Preguntas de reflexión

1. ¿Qué pasa si el equipo cambia el branch default a `develop`? ¿Qué habría que actualizar y en qué orden?
2. Si quisieras permitir deploys **también** desde tags `v*` sin tocar el `main.tf`, ¿cómo refactorizarías la condition?
3. ¿Por qué `permissions.id-token: write` debe estar a nivel de job y no top-level?
4. ¿Qué defensa en profundidad añade `aud = sts.amazonaws.com` cuando `sub` ya está pinneado?
5. Si tu organización usa **GitHub Enterprise Server** (self-hosted), ¿qué cambia en el `issuer`?

## 9. Extensiones

- Añadir un segundo rol para PRs (`sub = "repo:miorg/mirepo:pull_request"`) con permisos **solo** de lectura (p. ej. `ReadOnlyAccess`).
- Añadir un `aws_iam_policy` adjunto al rol que permita solo las acciones mínimas para el deploy (ejemplo: `ecr:*`, `s3:PutObject`, `cloudformation:*`).
- Añadir un `cosign sign --yes` tras el push de imagen en el workflow (sin ejecutarlo, solo el YAML).

## 10. Limpieza

```bash
rm -rf /tmp/aws-16-01-oidc
```

No hay procesos ni cuentas AWS que tocar.
