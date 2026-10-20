# aws-09 — KMS, Secrets Manager y SSM Parameter Store

## Identificación

- **ID:** `aws-09-kms-secrets-manager-parameter-store`
- **Curso:** `aws`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `aws-02` (IAM), `aws-05` (VPC/networking) y `aws-06` (RDS). Nociones básicas de criptografía simétrica (AES-GCM) y de JSON policies IAM.

## Objetivo

Gestionar **claves criptográficas y secretos** en AWS sin incurrir en las malas prácticas típicas: credenciales embebidas en código, secretos en variables de entorno sin cifrar, policies demasiado abiertas y rotación manual que nadie hace. Al terminar deberías poder decidir, defender y operar la combinación **KMS + Secrets Manager + SSM Parameter Store** para una aplicación real.

## Alcance

Este módulo cubre:

- **KMS**: tipos de CMK (AWS-managed, customer-managed, customer-provided — BYOK/XKS), estructura de una **key policy** y su interacción con IAM policies, **envelope encryption** (data keys), **rotación automática** anual, **multi-Region keys** y por qué `kms:Decrypt` sin una condición de contexto es un error común.
- **Secrets Manager**: creación y versionado (`AWSCURRENT`, `AWSPENDING`, `AWSPREVIOUS`), **rotación automática integrada** con RDS/Redshift/DocumentDB (Lambda rotator), replicación cross-Region, costo por secreto.
- **SSM Parameter Store**: tiers **standard** (gratis, 4 KB) vs **advanced** (8 KB, policies, throughput mayor), tipos `String`, `StringList` y `SecureString` (cifrado con KMS), jerarquía por path (`/app/prod/db/host`).
- **Criterio de uso**: cuándo Parameter Store (config no sensible, feature flags, endpoints) y cuándo Secrets Manager (credenciales rotables, secretos compartidos con rotación).

El flujo de **envelope encryption** se demuestra en vivo con `boto3` contra **LocalStack**. La **rotación de RDS** se trata como **walkthrough** (no se levanta RDS real); el entregable es un diseño justificado de la Lambda rotator y de la key policy que la habilita.

Lo que **no** cubre:

- CloudHSM, XKS externo (se mencionan de pasada).
- Firma asimétrica con KMS (`asymmetric` CMKs) — se verá si surge en el capstone.
- Private CA de ACM — se cubre en `aws-13`.
- Secretos para EKS/K8s con *external-secrets operator* — se verá en `aws-11`.

## Fundamentos clave

- **Envelope encryption**: KMS cifra una **data key** simétrica; la data key cifra el payload localmente. Esto evita hacer un round-trip a KMS por cada byte y permite cifrar objetos grandes a costo constante.
- **Key policy vs IAM policy**: la key policy es la **fuente de autoridad primaria** de una CMK. Una IAM policy que conceda `kms:Decrypt` **no sirve de nada** si la key policy no delega en IAM (`"Principal": {"AWS": "arn:aws:iam::<acct>:root"}` + `"Action": "kms:*"`). Confusión típica: "principal del rol" (`arn:aws:iam::<acct>:role/<name>`) vs "principal del servicio" (`secretsmanager.amazonaws.com`).
- **Rotación de Secrets Manager**: ciclo de 4 pasos — `createSecret` → `setSecret` → `testSecret` → `finishSecret` — ejecutados por una Lambda que AWS provee (templates oficiales) o que escribes tú.
- **Parameter Store SecureString**: internamente llama a `kms:Encrypt`/`kms:Decrypt`. El tamaño total (texto plano) sigue limitado por el tier.

## Materiales

- **`theory/lesson.md`** — lección profunda con 11 secciones.
- **`examples/`** — tres ejemplos demostrativos (lectura y análisis; algunos ejecutables contra LocalStack):
  - `01-cmk-with-key-policy/` — anatomía de una key policy para un rol de aplicación + servicio (Secrets Manager).
  - `02-secrets-manager-rotation-walkthrough/` — recorrido guiado por el ciclo de rotación de 4 pasos, con pseudo-código de la Lambda rotator.
  - `03-ssm-parameter-store-securestring/` — demo ejecutable (LocalStack) de `SecureString` cifrado con una CMK propia.
- **`activities/`** — dos actividades **independientes**:
  - `01-store-and-fetch-secret-from-app/` — crear CMK, guardar un secreto *fake* en Secrets Manager y un parámetro `SecureString` en SSM contra LocalStack; escribir un consumidor `boto3` que haga **envelope encryption** sobre un payload local y resuelva ambos valores desde la "app".
  - `02-rotate-rds-password-automatically/` — walkthrough + diseño: documentar la rotación RDS vía Secrets Manager (red, IAM, key policy, Lambda rotator, ventana de corte) y defender Secrets Manager vs Parameter Store para 5 ítems dados.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar envelope encryption en 3 frases. Distinguir key policy de IAM policy y nombrar el principal correcto (servicio vs rol). Enumerar los 4 pasos de rotación de Secrets Manager. |
| Operativa | Crear una CMK con policy correcta, guardar un `SecureString` cifrado con esa CMK, resolver un secreto desde `boto3`, y hacer envelope encryption E2E contra LocalStack. |
| Arquitectónica | Diseñar la jerarquía de secretos y parámetros de una app (prod/stg/dev × app × componente). Decidir Secrets Manager vs Parameter Store para 5 ítems con criterio argumentado. |

## Criterios de evaluación

- Dado un stack dado, clasifica correctamente 5 ítems entre Secrets Manager y Parameter Store, con una razón citando **rotación, tamaño, costo o visibilidad** por ítem.
- Explica por qué una IAM policy sola no abre una CMK cuando la key policy no delega en IAM.
- Describe el ciclo `createSecret`/`setSecret`/`testSecret`/`finishSecret` en orden.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables del capstone

- Credenciales (DB, API tokens de terceros) en **Secrets Manager**, con rotación donde aplique.
- Configuración (endpoints, feature flags, tamaños de pool) en **SSM Parameter Store**.
- Ambos consumidos desde la app vía **IAM role** (nunca por access keys en env vars).

## Siguiente módulo

→ `aws-10-containers-ecr-ecs-fargate-apprunner` — llevar la app a contenedores en ECS/Fargate consumiendo estos secretos/parámetros vía task role.
