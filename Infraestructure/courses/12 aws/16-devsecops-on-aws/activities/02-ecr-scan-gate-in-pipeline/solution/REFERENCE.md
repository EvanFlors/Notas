# REFERENCE — aws-16-02-ecr-scan-gate-in-pipeline

> Una **referencia** razonada. No es la unica respuesta correcta; es un modelo contra el que compararte.

## 1. `terraform/main.tf` (modelo)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ECR repo endurecido:
# - IMMUTABLE: nadie puede sobrescribir un tag ya publicado (anti-ataque de supply-chain
#   que "re-publica" :latest con contenido distinto).
# - scan_on_push: dispara basic scanning cada push. En solitario no bloquea deploys;
#   el gate del pipeline lo hace.
# - encryption KMS: encriptacion at-rest con CMK (recomendado para compliance).
resource "aws_ecr_repository" "app" {
  name                 = var.repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}

# Lifecycle: evitar bloat de imagenes untagged.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener como maximo N imagenes untagged"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = var.max_untagged_images
        }
        action = { type = "expire" }
      }
    ]
  })
}
```

## 2. `terraform/variables.tf` (modelo)

```hcl
variable "aws_region" {
  description = "AWS region for the ECR repo."
  type        = string
  default     = "us-east-1"
}

variable "repo_name" {
  description = "Nombre del repositorio ECR."
  type        = string
  default     = "demo-app"
}

variable "kms_key_arn" {
  description = "ARN de la KMS CMK para encriptacion at-rest. null = clave AWS/ECR default."
  type        = string
  default     = null
}

variable "max_untagged_images" {
  description = "Numero maximo de imagenes untagged a retener antes de expirar."
  type        = number
  default     = 10
}
```

## 3. `terraform/outputs.tf` (modelo)

```hcl
output "repository_url" {
  description = "URL del repositorio ECR para `docker push`."
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR."
  value       = aws_ecr_repository.app.arn
}
```

## 4. `.github/workflows/build-scan-gate.yml` (modelo)

```yaml
name: build-scan-gate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions: {}

env:
  AWS_REGION: us-east-1
  ECR_REPO: demo-app
  # Placeholder; en real: ${{ secrets.ECR_REGISTRY }} o un output del terraform.
  ECR_REGISTRY: 111122223333.dkr.ecr.us-east-1.amazonaws.com

jobs:
  build-scan-gate:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111122223333:role/gha-mirepo-prod
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: gha-${{ github.run_id }}

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$ECR_REGISTRY"

      - name: Build image
        run: |
          IMAGE_TAG="${GITHUB_SHA}"
          docker build -t "$ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG" .
          echo "IMAGE_TAG=$IMAGE_TAG" >> "$GITHUB_ENV"

      - name: Push image
        run: docker push "$ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG"

      - name: Wait for ECR scan to COMPLETE
        run: |
          for i in $(seq 1 30); do
            STATUS=$(aws ecr describe-image-scan-findings \
              --repository-name "$ECR_REPO" \
              --image-id imageTag="$IMAGE_TAG" \
              --query 'imageScanStatus.status' \
              --output text 2>/dev/null || echo "IN_PROGRESS")
            if [ "$STATUS" = "COMPLETE" ]; then
              echo "Scan COMPLETE after $i poll(s)."
              exit 0
            fi
            if [ "$STATUS" = "FAILED" ]; then
              echo "Scan FAILED. Aborting pipeline."
              exit 1
            fi
            echo "Scan status: $STATUS (attempt $i/30). Sleeping 10s..."
            sleep 10
          done
          echo "Scan did not COMPLETE within timeout. Aborting."
          exit 1

      - name: Gate on CRITICAL/HIGH findings
        run: |
          FINDINGS=$(aws ecr describe-image-scan-findings \
            --repository-name "$ECR_REPO" \
            --image-id imageTag="$IMAGE_TAG" \
            --query 'imageScanFindings.findingSeverityCounts' \
            --output json)
          CRIT=$(echo "$FINDINGS" | jq -r '.CRITICAL // 0')
          HIGH=$(echo "$FINDINGS" | jq -r '.HIGH // 0')
          echo "CRITICAL=$CRIT HIGH=$HIGH"
          if [ "$CRIT" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
            echo "FAIL: CRITICAL=$CRIT HIGH=$HIGH exceeds threshold."
            exit 1
          fi
          echo "OK: no CRITICAL/HIGH findings."
```

## 5. `ADR-ecr-scanning-tier.md` (modelo)

```markdown
# ADR — Eleccion de tier de ECR scanning (basic vs enhanced)

## Context

ECR ofrece dos tiers de scanning de vulnerabilidades sobre imagenes de contenedor:

- **Basic scanning**: usa la base de datos CVE de Clair, cubre vulnerabilidades a nivel de sistema operativo del container, se dispara on push cuando `image_scanning_configuration.scan_on_push = true`, y es **gratis**. La base se actualiza diariamente pero una imagen no se re-escanea si no se re-publica.
- **Enhanced scanning**: lo provee Amazon Inspector v2. Cubre OS + dependencias de lenguajes (Python, Node, Java, Go, Ruby, .NET), hace **continuous rescanning** cuando aparecen nuevos CVEs sin requerir re-publicar la imagen, y produce findings consolidados en Security Hub. Cuesta aproximadamente **$0.09 USD por imagen activa por mes** (consultar calculadora oficial para la region y volumen reales).

El equipo necesita decidir que tier aplicar por repo y como escalarlo a varios repos sin sorpresas en la factura.

## Decision

- **Default = basic** para repos nuevos y repos cuya aplicacion es un binario estatico sin dependencias de lenguaje relevantes (p. ej. Go, Rust compilados a `scratch`).
- **Enhanced** se habilita selectivamente para:
  1. Repos de aplicaciones con dependencias de lenguaje significativas (Python/Node/Java) donde la cobertura de CVE OS no basta.
  2. Repos sujetos a compliance (PCI, HIPAA, SOC2) que exige rescanning continuo documentado.
  3. Repos de alta criticidad (payments, auth) donde el delta de coste es despreciable frente al blast radius de una regresion.
- La habilitacion de enhanced se hace via `aws_ecr_registry_scanning_configuration` a nivel de cuenta con filtros por tag (`scan-tier=enhanced`), no manualmente por repo.
- **Siempre** `scan_on_push = true`, incluso para basic, porque el coste adicional es cero y da linea base.
- El pipeline **falla** ante findings `CRITICAL` o `HIGH`, sin importar el tier. Excepciones por CVE+justificacion viven en un allowlist versionado.

## Consequences

**Positivas**:

- Coste controlado: solo pagamos enhanced por los repos que lo justifican.
- Compliance verificable: los repos sujetos a auditoria tienen rescanning continuo que no depende de re-publicar.
- Gate uniforme: el pipeline no se preocupa del tier, solo lee los findings; el tier es una decision de registry, no de pipeline.

**Negativas**:

- Coste no trivial a escala en enhanced: 1000 imagenes activas = ~$90/mes. Hay que vigilar el crecimiento. Mitigacion: la lifecycle policy expira imagenes untagged a 10 y imagenes tagged a N dias segun el repo.
- Findings mas ruidosos en enhanced (incluye dependencias de lenguaje): requiere triage y un allowlist disciplinado. Mitigacion: ownership por repo con SLA de 7 dias para CRITICAL y 30 dias para HIGH.
- Riesgo de depender de la DB de CVEs ajena: si Inspector tarda en incorporar un CVE nuevo, el gate no lo captura. Mitigacion: cosign + verificacion en admision + un segundo scanner (Trivy) en el CI como defensa en profundidad.

## Alternatives

1. **Enhanced para todos los repos** — rechazada: coste lineal al numero de imagenes activas, muchos repos no se benefician (binarios estaticos, imagenes de utilidad raramente desplegadas).
2. **Basic para todos, Trivy en CI como unico scanner de dependencias** — considerada: Trivy cubre dependencias de lenguaje gratis, pero no da rescanning continuo (si la imagen no vuelve a pasar por CI, no se re-escanea). Se adopta Trivy en CI **ademas** de ECR scanning, no en su lugar.
3. **Sin scanning, confiar en firma cosign** — rechazada: la firma garantiza la cadena, no la ausencia de CVEs. Son controles ortogonales.
4. **Scanning externo tipo Snyk/Prisma** — fuera de alcance de este modulo; se considera en revisiones posteriores si Inspector v2 se queda corto.

## Status

Accepted.
```

## 6. Lo que NO debe aparecer en ninguno de los entregables

- `image_tag_mutability = "MUTABLE"`.
- `scan_on_push = false`.
- `aws_access_key_id` / `aws_secret_access_key` en ningun archivo.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` en secrets o env del workflow.
- `permissions: write-all` o `permissions.id-token: write` a nivel top-level.
- Account IDs reales. Usamos `111122223333` como placeholder.
- Costos inventados sin referenciar la calculadora oficial.

## 7. Punto a repetir hasta que suene aburrido

> El tier de scanning es una decision **por repo** (o por tag), no por organizacion. Habilitar enhanced para todo "porque la seguridad es prioridad" es como pagar por un seguro de autos a los libros: el riesgo no esta ahi. Elegir el tier adecuado es parte de la higiene DevSecOps, igual que no escanear nada es parte de la negligencia.
