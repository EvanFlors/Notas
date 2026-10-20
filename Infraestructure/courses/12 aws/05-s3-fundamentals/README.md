# aws-05 — S3: fundamentos con seguridad por default

## Identificación

- **ID:** `aws-05-s3-fundamentals`
- **Curso:** `aws`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `aws-02-iam-fundamentals`. Deseable: `aws-01-model-regions-billing-and-free-tier` (perfiles CLI). No se requiere cuenta AWS real para las actividades: usamos **LocalStack** para el plano de datos.

## Objetivo

Usar S3 con **seguridad razonable desde el día uno**: bucket privado, versioning, lifecycle, cifrado en reposo y acceso restringido por bucket policy. Al terminar deberías poder crear buckets que **no se filtren por accidente** y auditar un bucket público ajeno proponiendo la corrección mínima.

## Alcance

Cubre:

- Modelo de objeto: bucket, key, versión; **naming global** y por qué ya no puedes llamar a tu bucket `data`.
- **Storage classes** (Standard, IA, One Zone-IA, Intelligent-Tiering, Glacier Instant/Flexible/Deep Archive) y cuándo elegir cada una.
- **Versioning**: habilitarlo, borrados "soft" vía *delete marker*, impacto en costos.
- **Lifecycle rules** declarativas: transition entre clases, expiration, limpieza de versiones no actuales y multipart uploads abortadas.
- **Block Public Access** (BPA) a nivel cuenta y bucket (default sano desde 2023).
- **Bucket policies vs ACLs**: ACLs deshabilitadas por default moderno (`BucketOwnerEnforced`), por qué.
- **Encryption at-rest**: SSE-S3, SSE-KMS, DSSE-KMS; mención a SSE-C.
- **Access logging** a un bucket separado; **S3 Event Notifications** (SQS/SNS/Lambda/EventBridge).
- **CORS** para subidas desde navegador.
- **Presigned URLs** para subidas/descargas con credencial efímera.

No cubre (otros módulos):

- Replicación cross-region (CRR/SRR) y Object Lock → `aws-13`.
- S3 Access Points y Multi-Region Access Points → `aws-13`.
- CloudFront + OAC frente a S3 origin → `aws-13`.
- IAM avanzado (conditions complejas, cross-account, Access Analyzer) → `aws-06`.
- KMS key policy en profundidad → `aws-09`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos de lectura (no se ejecutan al pie de la letra):
  - `01-safe-bucket-defaults-tf/` — bloque Terraform de un bucket privado con versioning + SSE-KMS + BPA + ownership controls, comentado línea a línea.
  - `02-presigned-upload/` — flujo de presigned URL para upload desde un cliente (boto3 genera la URL, `curl` sube el objeto).
  - `03-lifecycle-to-glacier/` — regla de lifecycle con transiciones a IA → Glacier Instant → Deep Archive y expiración de versiones no actuales.
- **`activities/`** — dos actividades **independientes**:
  - `01-provision-and-upload-with-cli-and-boto3/` — contra **LocalStack**, provisiona bucket seguro, sube un objeto con `aws s3` CLI y con `boto3`, verifica versioning y lifecycle, valida JSON de lifecycle y bucket policy.
  - `02-detect-and-fix-public-bucket/` — recibes la configuración de un bucket "público" (JSON+policy) y produces un `AUDIT.md` con hallazgos y los JSON corregidos (bucket policy mínima y BPA activo).
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué **BPA es la red de seguridad** y por qué los "leaks de S3" históricos vinieron de ACLs/policies permisivas. Diferenciar SSE-S3 vs SSE-KMS vs DSSE-KMS. |
| Operativa | Crear un bucket con versioning, lifecycle, SSE-KMS y bucket policy mínima, por CLI o Terraform. Generar y consumir una presigned URL. |
| Arquitectónica | Decidir storage class y lifecycle para 3 workloads (hot/warm/cold). Auditar un bucket público y proponer la corrección mínima que no rompe su uso legítimo. |

## Criterios de evaluación

- Puede escribir una **bucket policy mínima** que permita a un rol concreto `GetObject` sobre un prefijo específico, con `aws:SecureTransport = true` como condición.
- Puede explicar qué hace cada *setting* de **Block Public Access** y por qué los 4 deben estar en `true` salvo caso justificado.
- Puede diseñar una **lifecycle rule** que mueva objetos a Glacier Deep Archive tras 180 días y limpie versiones no actuales tras 30 días.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Bucket seguro provisionado con versioning + lifecycle + SSE-KMS + BPA (sale de la actividad 01).
- Documento de auditoría + JSONs corregidos para un bucket público (sale de la actividad 02).

## Siguiente módulo

→ `aws-06-iam-advanced` — SCPs, permission boundaries, cross-account y Access Analyzer para refinar permisos iterativamente.
