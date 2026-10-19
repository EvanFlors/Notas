# Actividad 02 — Gate de scanning de ECR en pipeline

## 1. Identificacion

- **ID:** `aws-16-02-ecr-scan-gate-in-pipeline`
- **Tecnologia:** `aws`
- **Modulo:** `aws-16-devsecops-on-aws`
- **Dificultad:** advanced
- **Duracion estimada:** 60-90 min
- **Tipo:** independent

## 2. Contexto

Vas a construir, **en local y sin desplegar nada en AWS**, los tres artefactos que forman un gate de vulnerabilidades sobre imagenes de contenedor publicadas a ECR:

1. **Terraform HCL** de un `aws_ecr_repository` con `image_scanning_configuration.scan_on_push = true`, `image_tag_mutability = "IMMUTABLE"` y `encryption_configuration` con `encryption_type = "KMS"`.
2. **Workflow de GitHub Actions** que (a) autentica con OIDC (reutiliza el rol construido en la actividad 01), (b) construye y publica la imagen, (c) espera a que ECR termine el scan basico y (d) **falla** el pipeline si hay findings de severidad `CRITICAL` o `HIGH`.
3. **ADR** (`ADR-ecr-scanning-tier.md`) que compara **basic scanning** (gratis, CVE DB de Clair, actualizacion diaria) vs **enhanced scanning** (Inspector v2, costo por imagen activa por mes, cobertura OS + lenguajes, deep inspection) y recomienda cuando usar cada uno.

**No se despliega nada.** Validamos con `terraform validate` (no requiere credenciales), estructura (grep + jq-like checks) y, si estan instalados, Checkov y Trivy para analisis estatico del HCL.

## 3. Objetivos

Al terminar deberias poder, sin mirar la leccion:

- Escribir desde cero el bloque minimo de Terraform para un repo ECR endurecido (scan_on_push + IMMUTABLE + KMS).
- Escribir un step de workflow que lea `aws ecr describe-image-scan-findings` y devuelva exit code != 0 si hay findings CRITICAL/HIGH.
- Explicar en un ADR en que caso basic basta (presupuesto cero, cobertura CVE OS) y cuando enhanced se justifica (compliance, cobertura de dependencias de lenguaje, Lambda).

## 4. Prerrequisitos

- Haber terminado `../01-full-oidc-pipeline-no-keys/` (reutilizas el rol OIDC conceptualmente).
- Haber leido `../../theory/lesson.md` seccion sobre scanning e Inspector.
- Haber recorrido `../../examples/02-inspector-scan-ecr/`.
- Herramientas **obligatorias**: `bash`, `terraform` (>= 1.5), `jq`, un editor.
- Herramientas **opcionales** (si faltan, el validador reporta `SKIP`):
  - `checkov` — analisis estatico HCL.
  - `trivy` — segundo analisis estatico HCL.

**Costos:** cero. No se despliega nada. En `ADR-ecr-scanning-tier.md` documentas los costos de los dos tiers de scanning para defender la decision en tu organizacion.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-16-02-ecr/terraform
mkdir -p /tmp/aws-16-02-ecr/.github/workflows
cd /tmp/aws-16-02-ecr
```

Puedes usar otro directorio pasandoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribir `terraform/main.tf`

Debe contener **al menos**:

- `terraform { required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } } }` y `required_version`.
- `provider "aws"` con `region` fija.
- `aws_ecr_repository` con:
  - `name = var.repo_name`.
  - `image_tag_mutability = "IMMUTABLE"`.
  - `image_scanning_configuration { scan_on_push = true }`.
  - `encryption_configuration { encryption_type = "KMS" }` (opcionalmente con `kms_key = var.kms_key_arn`).
- `aws_ecr_lifecycle_policy` que mantenga como maximo N imagenes untagged (p. ej. 10) para evitar bloat.
- **NO** debe aparecer en todo el archivo: `image_tag_mutability = "MUTABLE"`, `scan_on_push = false`, encryption `"AES256"` sin justificacion, ni `aws_access_key_id` / `aws_secret_access_key`.

### 5.3 Escribir `terraform/variables.tf` y `terraform/outputs.tf`

- `variables.tf`: `repo_name` (default `"demo-app"`), `kms_key_arn` (default `null`), `max_untagged_images` (default `10`), `aws_region` (default `"us-east-1"`).
- `outputs.tf`: output `repository_url` del `aws_ecr_repository`.

### 5.4 Escribir `.github/workflows/build-scan-gate.yml`

Workflow minimo que:

- Se dispara en `push` sobre `main` y `pull_request`.
- Define `permissions.id-token: write` y `permissions.contents: read` **a nivel de job** (no al top).
- Usa `aws-actions/configure-aws-credentials@v4` con `role-to-assume: <ARN placeholder>` (el del rol creado en actividad 01).
- Construye la imagen con `docker build` y la publica con `docker push` al repo ECR.
- Despues del push, llama a `aws ecr describe-image-scan-findings` en un loop con backoff hasta ver `scanStatus.status == "COMPLETE"`.
- Lee `findingSeverityCounts.CRITICAL` y `findingSeverityCounts.HIGH` y si suman > 0, hace `exit 1` para **cortar** el pipeline.
- **NO** menciona `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY`.

Puedes aceptar excepciones documentadas usando un archivo de allowlist (`.cve-allowlist`), pero esta es una **extension**, no un requisito.

### 5.5 Escribir `ADR-ecr-scanning-tier.md`

ADR en el formato estandar (`Context`, `Decision`, `Consequences`, `Alternatives`). Debe:

- Explicar que hace basic scanning (Clair, OS CVEs, actualizacion diaria, **gratis**).
- Explicar que hace enhanced scanning (Inspector v2, OS + lenguaje, continuous rescanning, **$0.09/imagen/mes** aproximadamente).
- Nombrar al menos **2 criterios** para elegir enhanced sobre basic (p. ej. compliance que requiere cobertura de dependencias de lenguaje; necesidad de rescanning continuo sin re-publicar; vista unificada con Inspector sobre EC2/Lambda).
- Dar al menos **una** consecuencia negativa de enhanced (coste no trivial a escala; findings mas ruidosos que requieren triage).
- Mencionar explicitamente el valor numerico del costo mensual aproximado por imagen y referenciar que el calculo real debe hacerse con la calculadora de AWS.

### 5.6 Validacion local

```bash
cd terraform
terraform init -backend=false
terraform validate
cd ..
bash <ruta-repo>/courses/aws/16-devsecops-on-aws/activities/02-ecr-scan-gate-in-pipeline/tests/validate.sh /tmp/aws-16-02-ecr
```

El validador:

- Comprueba que los 4 artefactos existen.
- Hace `grep` estructural sobre el HCL (scan_on_push, IMMUTABLE, KMS, ausencia de access keys).
- Si `terraform` esta instalado, corre `terraform init -backend=false` y `terraform validate` (sin credenciales AWS).
- Si `checkov` esta instalado, lo corre sobre `terraform/`.
- Si `trivy` esta instalado, corre `trivy config terraform/`.
- Si falta `checkov` o `trivy`, los reporta como `SKIP` (no es un fallo).

## 6. Resultado esperado

Estructura final en el directorio de trabajo:

```
/tmp/aws-16-02-ecr/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── .github/
│   └── workflows/
│       └── build-scan-gate.yml
└── ADR-ecr-scanning-tier.md
```

Y el validador en verde.

## 7. Criterios de aceptacion

- **Funcionalidad**: `terraform validate` pasa; validador estructural pasa.
- **Seguridad**: no hay `MUTABLE`, no hay `scan_on_push = false`, no hay access keys hardcodeadas.
- **Gate**: el workflow termina con `exit 1` ante findings `CRITICAL` o `HIGH`.
- **Calidad**: ADR articulado, con `Context`, `Decision`, `Consequences`, `Alternatives`, y numeros concretos de costo.
- **Reproducibilidad**: cualquiera que lea el repo entiende que tier se eligio y por que.

## 8. Preguntas de reflexion

1. Si tu equipo tiene presupuesto cero y la aplicacion es un binario Go estatico publicado en una imagen `scratch`, ¿basic o enhanced? Justifica.
2. Si tu compliance exige escanear dependencias de Python/Node continuamente aunque la imagen no cambie, ¿basic o enhanced?
3. ¿Que pasa si un finding `HIGH` lleva 6 meses sin fix upstream? ¿Como lo manejas sin romper deploys indefinidamente?
4. ¿Por que `IMMUTABLE` es relevante para la narrativa de seguridad? ¿Que ataque previene?
5. Si el `scan_on_push` falla silenciosamente (p. ej. ECR en una region sin cobertura basica), ¿como lo detectas antes de que un deploy sin escanear pase el gate?

## 9. Extensiones

- Anadir un `aws_ecr_registry_scanning_configuration` a nivel de cuenta para habilitar `enhanced` scanning y rules para filtrar repos por tag `scan-tier=enhanced`.
- Anadir un step de `cosign sign --yes` para firmar la imagen justo despues de que el gate pase (sin ejecutarlo, solo el YAML).
- Anadir un `aws_ecr_repository_policy` que solo permita `BatchGetImage` desde el account root de produccion y rechace cualquier otro principal.
- Reemplazar el loop de polling por un **EventBridge rule** que dispare un step function cuando `scanStatus == COMPLETE` (pseudo-codigo en el README, no se despliega).

## 10. Limpieza

```bash
rm -rf /tmp/aws-16-02-ecr
```

No hay procesos ni cuentas AWS que tocar.
