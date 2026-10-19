# aws-01 — Modelo de AWS, regiones, billing y Free Tier

## Identificación

- **ID:** `aws-01-model-regions-billing-and-free-tier`
- **Curso:** `aws`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** nociones básicas de cloud (qué es IaaS/PaaS, qué es una API HTTP, qué es un VPS). No se requiere cuenta de AWS activa para completar el módulo: todos los ejercicios tienen una variante **sin coste** (LocalStack, Terraform `plan`, documentación escrita).

## Objetivo

Entender el **modelo global de AWS** (cuentas, regiones, AZs, servicios globales vs regionales), el **modelo de facturación** (Free Tier, Budgets, Cost Explorer, Pricing Calculator) y las **primeras higienes de seguridad** (MFA en root, usuario administrativo con MFA, presupuesto con alerta) **antes** de provisionar un solo recurso de pago. Al terminar deberías poder:

- Explicar por qué la cuenta **root** no se usa a diario y qué pasa si se compromete.
- Diferenciar servicios **globales** (IAM, Route 53, CloudFront, Organizations, WAF global, ACM para CloudFront) de **regionales** (casi todo lo demás) y por qué eso importa al leer el ARN.
- Configurar la **AWS CLI v2** con **perfiles** (`~/.aws/config`, `~/.aws/credentials`) y entender la precedencia de resolución de credenciales.
- Explicar qué firma **SigV4** y por qué `aws sts get-caller-identity` es el primer chequeo que corres siempre.
- Crear un **presupuesto con alerta por email** como *primer paso obligatorio* antes de cualquier otro módulo del curso.

## Alcance

Este módulo cubre:

- El **modelo de cuenta**: qué es una cuenta AWS, por qué es la unidad de facturación y aislamiento, qué es Organizations (introducción).
- **Regiones y AZs**: criterios reales para elegir región (latencia, compliance, precio por servicio, disponibilidad de servicio), el *latency map* y por qué el gráfico "us-east-1 es la más barata" es verdad a medias.
- **Servicios globales vs regionales**: cómo lo reconoces en el ARN (`arn:aws:iam::123456789012:user/...` sin región vs `arn:aws:s3:::bucket` sin región pero por otra razón, vs `arn:aws:ec2:us-east-1:123456789012:instance/i-...`).
- El **plano de API**: endpoints por región (`ec2.us-east-1.amazonaws.com`), **SigV4** (qué firma, por qué), y la cadena de resolución de credenciales de la CLI/SDK.
- **AWS CLI v2**: instalación, perfiles con nombre, variables de entorno, SSO/Identity Center (introducción), `aws configure`, `aws sts get-caller-identity`.
- **Modelo de facturación**: Free Tier (always-free vs 12-month vs trial), Billing & Cost Management, **AWS Budgets** con alertas, Cost Explorer, Pricing Calculator.
- **Seguridad inicial**: MFA en root, usuario administrativo (o SSO) con MFA, por qué las *access keys* en root son el peor smell posible.

Lo que **no** cubre (se verá después):

- Detalle de políticas IAM y lógica de evaluación → `aws-02`.
- Guardrails de org (SCPs, boundaries) → `aws-06`.
- VPCs, EC2, S3 → `aws-03`, `aws-04`, `aws-05`.
- Terraform al detalle (se asume el curso `terraform` como prerrequisito del curso de AWS en general, pero este módulo **no** depende de él).

Este módulo es **90 % conceptual + 10 % práctica sin coste**. No se provisiona nada que pueda cobrarse. Los ejemplos usan **LocalStack** y **Terraform `plan`** sobre credenciales ficticias; las actividades son documentos operables y evidencia de higiene mínima.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y práctica contra LocalStack / plan):
  - `01-cli-profiles-and-sts/` — configurar perfiles de AWS CLI y entender `sts get-caller-identity` contra LocalStack (sin tocar AWS real).
  - `02-budget-with-sns-alert/` — Terraform `plan` de un `aws_budgets_budget` + topic SNS para alerta por email, sin `apply`.
- **`activities/`** — dos actividades **independientes**:
  - `01-safe-account-setup/` *(guided-lab)* — producir un `ACCOUNT-SETUP.md` que documente, paso a paso y con comandos reales, cómo dejar una cuenta nueva en estado seguro (MFA en root, admin con MFA, presupuesto con alerta). No ejecuta en AWS: entrega el runbook y lo valida estructuralmente.
  - `02-root-mfa-and-admin-user/` *(independent, obligatoria antes de cualquier otro módulo)* — ADR + checklist firmados que demuestran que el estudiante entiende *por qué* el root se bloquea y *qué pasa* si no se hace.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir cuenta, región y AZ sin confundirlas. Enumerar al menos 4 servicios globales y por qué lo son. Explicar SigV4 en una frase. |
| Operacional | Configurar perfiles de la CLI, ejecutar `aws sts get-caller-identity` contra LocalStack, diseñar un presupuesto con alerta. |
| Seguridad | Enumerar las 5 primeras higienes de cuenta nueva en el orden correcto y justificar por qué el root no debe tener access keys. |
| Costo | Estimar el coste mensual de un workload trivial con la Pricing Calculator y detectar los 3 cargos "silenciosos" clásicos (NAT Gateway, egress, snapshots). |

## Validación global del módulo

```bash
bash activities/01-safe-account-setup/tests/validate.sh
bash activities/02-root-mfa-and-admin-user/tests/validate.sh
python3 ../../../scripts/validate-activities.py
```

Ambos validadores de actividad son **estructurales**: comprueban que los entregables existen y contienen las secciones requeridas, **no** la semántica. Para autoevaluación semántica, compara con `solution/REFERENCE.md` o `solution/TEMPLATE.md` de cada actividad.

## Advertencia de costes

> Ningún comando de este módulo cuesta dinero. Los ejemplos corren contra **LocalStack** o se quedan en **`terraform plan`**. **No ejecutes `terraform apply` contra una cuenta AWS real** mientras estudias este módulo: aún no hemos visto cómo poner guardrails. Si tu entorno no tiene LocalStack o Terraform, los scripts hacen *skip* con un mensaje claro, nunca fallan por ausencia de infra.
