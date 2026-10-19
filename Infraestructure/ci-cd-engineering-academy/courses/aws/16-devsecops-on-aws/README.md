# aws-16 — DevSecOps en AWS

## Identificación

- **ID:** `aws-16-devsecops-on-aws`
- **Curso:** `aws`
- **Nivel:** producción
- **Duración estimada:** 7 h
- **Prerrequisitos:** `aws-02-iam`, `aws-10-containers`, `aws-11-eks`, `aws-15-org-idc`, cursos **github-actions** y **docker** Nivel 4.

## Objetivo

Aterrizar en AWS los controles DevSecOps que ya conoces del programa: **autenticar pipelines sin claves humanas** (OIDC GitHub Actions → IAM Role), **identidad de workloads** sin secretos (IRSA / Pod Identity), **rotación automática de secretos**, **scanning de imágenes** (ECR + Inspector), **detección de amenazas** (GuardDuty), **firma y verificación** de imágenes (cosign + policy-controller/Kyverno), **registro de configuración** (Config + conformance packs) y el marco **AWS Security Reference Architecture** (SRA).

El principio que atraviesa el módulo: **nunca uses access keys humanas**. Si existe una key larga, existe la pregunta "¿quién la tiene y dónde está rotada?". La respuesta correcta es "ninguna existe".

## Alcance

Este módulo cubre:

- **OIDC GitHub Actions → AWS**: cómo el *claim* `sub` del token JWT emitido por GHA se mapea a una `AssumeRoleWithWebIdentity` sobre un IAM Role. Por qué pinnear a `repo:owner/repo:ref:refs/heads/main` (o `:environment:prod`) es la línea entre "cualquier fork puede asumir mi rol" y "solo la pipeline de main de este repo".
- **IRSA vs Pod Identity** en EKS: el modelo clásico (service account anotada + OIDC provider del cluster) y el modelo nuevo (`eks-pod-identity-agent` + `aws_eks_pod_identity_association`). Cuándo elegir cada uno.
- **Secrets Manager** con rotación automática: la Lambda rotator que AWS provee para RDS, y cómo verificarla en Terraform `plan`.
- **ECR scanning** — básico (gratuito, CVE DB) vs **enhanced** (Inspector v2, costo por imagen y mes). Cuándo cada uno.
- **Inspector v2** para EC2, ECR y Lambda. Modelo de activación por cuenta.
- **GuardDuty** — detección por findings a partir de VPC Flow Logs, DNS logs, CloudTrail, EKS audit logs, S3 data events. Modelo de costo por GB.
- **Firma de imágenes con cosign** y verificación en admisión en EKS vía **sigstore policy-controller** o **Kyverno**. Keyless (OIDC) vs key-based.
- **AWS Config** — configuration recording + conformance packs (NIST, PCI, CIS). Costo por item de configuración + por evaluación de regla.
- **AWS Security Reference Architecture (SRA)** — cuentas dedicadas de `log-archive` y `security-tooling`.
- **IAM Access Analyzer**, **Security Hub**, **Macie**, **WAF** — vista panorámica y cuándo tocan a este módulo.

Lo que **no** cubre (o se cubre en otros módulos):

- Instalar EKS, redes VPC, KMS CMK — ver `aws-10`, `aws-11`, `aws-03`, `aws-09`.
- Landing zone completa, FinOps, Well-Architected — ver `aws-17`.
- Operar GuardDuty/Security Hub a nivel de organización — se menciona, no se despliega.

**Importante — costos y seguridad**: este módulo es **100 % local**. **No se despliega nada en una cuenta AWS real**. Todas las actividades son Terraform `init -backend=false` + `validate`, análisis estático (Checkov/Trivy si están instalados, `SKIP` si no), y ADRs razonados. No hay riesgo de factura. Los costos de los servicios *reales* se documentan en `theory/lesson.md` para que puedas defender la decisión en tu organización.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones, cubriendo OIDC, IRSA/Pod Identity, rotación, scanning, GuardDuty, firma y verificación, Config y SRA.
- **`examples/`** — ejemplos de **lectura y análisis** (no se despliegan):
  - `01-oidc-gha-to-aws-role/` — diagrama del flujo OIDC + ejemplo de trust policy con el `sub` claim pinneado y los errores clásicos.
  - `02-inspector-scan-ecr/` — comparación básico vs enhanced y lectura de un finding real.
  - `03-cosign-verify-in-eks/` — flujo firmar en CI, verificar en admisión; diferencias entre policy-controller y Kyverno.
  - `04-secrets-manager-rds-rotation/` — anatomía de la Lambda rotator y los 4 pasos (`createSecret`, `setSecret`, `testSecret`, `finishSecret`).
- **`activities/`** — dos actividades:
  - `01-full-oidc-pipeline-no-keys/` — **mini-proyecto**. Escribir Terraform HCL para el OIDC provider + IAM Role con trust policy pinneada, workflow de GHA que lo consume, y ADR que defiende el *scoping* del `sub` claim. Valida estructura + opcionalmente Checkov.
  - `02-ecr-scan-gate-in-pipeline/` — **independiente**. Escribir Terraform HCL para un ECR repo con `scan_on_push`, workflow de GHA con gate por severidad (CRITICAL/HIGH), y ADR comparando scanning básico vs enhanced con costos.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `sub` pinneado a un ref específico es la frontera de seguridad del OIDC. Distinguir IRSA de Pod Identity y cuándo elegir cada uno. Comparar ECR basic scanning vs enhanced con sus costos. |
| Operativa | Escribir el Terraform para el OIDC provider + IAM Role sin credenciales humanas. Añadir un gate de ECR scanning en un workflow de GHA. Definir una política de admisión para verificar firmas cosign. |
| Arquitectónica | Defender por escrito, con un ADR, decisiones sobre pinning de ref, basic vs enhanced scanning y keyless vs key-based signing. Auditar un pipeline existente para brechas DevSecOps. |

## Criterios de evaluación

- Define OIDC federation y explica, en una frase, qué protege el pinning del claim `sub`.
- Nombra 3 condiciones mínimas que deben estar en una `trust policy` de un IAM Role para GHA (`token.actions.githubusercontent.com:aud`, `token.actions.githubusercontent.com:sub`, `Principal.Federated` con el ARN del OIDC provider).
- Entrega las dos actividades con validador estructural en verde (y Checkov/Trivy en verde si están instalados).
- Entrega un ADR por actividad justificando una decisión concreta.
- Puede auditar por escrito un workflow con access keys hardcodeadas y proponer la migración paso a paso.

## Entregables

- Terraform HCL del OIDC provider + IAM Role con `sub` pinneado (actividad 01).
- Workflow GHA con `permissions.id-token: write` y uso de `aws-actions/configure-aws-credentials@v4` (actividad 01).
- ADR `ADR-oidc-sub-pinning.md` (actividad 01).
- Terraform HCL del ECR repo con `scan_on_push` y workflow con gate por severidad (actividad 02).
- ADR `ADR-ecr-scanning-tier.md` (actividad 02).

## Siguiente módulo

→ `aws-17-platform-finops-and-well-architected` — operar AWS como plataforma: landing zone, costos, DR, Well-Architected.
