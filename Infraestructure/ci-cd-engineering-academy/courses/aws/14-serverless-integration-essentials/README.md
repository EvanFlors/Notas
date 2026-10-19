# aws-14 — Serverless para integraciones (lo justo)

## Identificación

- **ID:** `aws-14-serverless-integration-essentials`
- **Curso:** `aws`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `aws-02` (IAM), `aws-05` (S3 / storage), `aws-09` (compute). Nociones de Python 3 y Docker a nivel usuario. Haber tocado alguna vez un `handler(event, context)` ayuda, pero no es imprescindible.

## Objetivo

Dominar **lo justo** de serverless en AWS para resolver **integraciones y automatizaciones**: enganchar un evento (S3, cron, webhook, mensaje en cola) con un trozo de código corto y, cuando haga falta, orquestar varios pasos. **No** es un curso de serverless full ni un reemplazo de ECS/EKS para workloads largos.

Al terminar, un alumno debe poder:

- Decidir, para una integración concreta, si Lambda es la elección correcta frente a un contenedor en ECS/Fargate o un cronjob en EKS.
- Diseñar un **mini-pipeline event-driven** (p. ej. S3 → Lambda → SNS → SQS → Lambda) con **DLQ** y **visibility timeout** bien pensados.
- Escribir un `handler` Python idempotente, con validación de evento, logging estructurado y manejo de errores que **no pierda ni duplique** mensajes.
- Leer y escribir una **ASL** (Amazon States Language) básica de Step Functions suficiente para orquestar 3–5 pasos.
- Nombrar los **costos ocultos** típicos (logs de Lambda, invocaciones de EventBridge, requests de API Gateway) y qué palanca mueve cada uno.

## Alcance

Este módulo cubre:

- **Lambda**: runtimes, modelo de concurrencia (hasta 1000 simultáneas por default por región, no por función), memoria=CPU, timeouts, cold starts, provisioned concurrency, SnapStart, Lambda layers, container image deployment, el ciclo `init → invoke → freeze → shutdown`.
- **API Gateway**: REST vs HTTP vs WebSocket, auth (IAM, JWT, Lambda authorizer), usage plans y por qué REST cobra ~3x más que HTTP para la mayoría de casos.
- **EventBridge**: buses (default vs custom), rules, patrones de evento, cross-account, schemas, **pipes** (source → filter → enrichment → target sin Lambda intermedia).
- **SQS**: `standard` (at-least-once, out-of-order, enorme throughput) vs **FIFO** (exactly-once procesada, orden por `MessageGroupId`, 300 msg/s por grupo), `VisibilityTimeout`, `ReceiveMessageWaitTimeSeconds` (long polling), **DLQ** y `maxReceiveCount`, redrive policy.
- **SNS**: topics, fanout a múltiples SQS, `FIFO` topics, filter policies, cross-region replication.
- **Step Functions**: Standard vs Express, ASL, estados (`Task`, `Choice`, `Parallel`, `Map`, `Wait`, `Succeed`, `Fail`), retry/catch, Service integrations directas (sin Lambda de pegamento).
- El **criterio Lambda vs ECS/EKS** (duración de la invocación, patrón de carga, cold starts aceptables, costo mensual estimado).

Lo que **no** cubre:

- Serverless framework / SAM / CDK como herramientas. El énfasis es en el **modelo mental** y en la **arquitectura**; Terraform cubrirá el provisioning real en los proyectos capstone.
- Lambda@Edge y CloudFront Functions (van en `aws-13-public-endpoints-dns-tls-cdn`).
- Appsync, GraphQL serverless, DynamoDB Streams en profundidad (sale en el módulo de bases de datos).
- Observabilidad de serverless con `lambda-powertools` más allá de un ejemplo de logging/metrics. La observabilidad vendor-neutral vive en el curso `opentelemetry`.

## Costo real en AWS: **cero euros en este módulo**

**Todos** los demos ejecutables usan **LocalStack** (`localstack:latest` en Docker). Nada se despliega en una cuenta AWS real. Los archivos ASL de Step Functions se validan **estructuralmente** (JSON bien formado, estados referenciados, `StartAt` presente, nombres únicos) sin ejecutarlos contra el servicio real. Las referencias a ARNs, cuentas y regiones son **placeholders** (`123456789012`, `us-east-1`, nombres de ejemplo). Si al leer el curso ves `arn:aws:...:123456789012:...`, es inventado a propósito.

Si LocalStack no está disponible en tu máquina, el validador **salta** la parte ejecutable con un mensaje `SKIP: localstack not available` y no la cuenta como fallo. El trabajo escrito y la revisión del handler siguen siendo ejercitables.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución desde este directorio):
  - `01-lambda-handler-anatomy/` — anatomía de un `handler(event, context)` Python real, con las piezas que casi todos olvidan (idempotencia, logging estructurado, retorno correcto para el invoker).
  - `02-event-driven-pipeline-diagram/` — diagrama ASCII anotado de un pipeline S3 → Lambda → SNS → SQS → Lambda con DLQ, visibility timeout y zonas de riesgo marcadas.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-lambda-sqs-localstack-demo/` — demo ejecutable (si hay Docker + LocalStack): levantar Lambda + SQS en LocalStack, enviar un mensaje, ver el handler ejecutarse. `SKIP` limpio si no hay LocalStack.
  - `02-event-driven-design-decisions/` — análisis escrito: para un escenario dado, decidir topología event-driven, DLQ, visibility timeout, FIFO vs standard, Lambda vs ECS. Entregable `DECISIONS.md`.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar el modelo de concurrencia de Lambda sin confundirlo con "paralelismo dentro de una invocación". Nombrar los 3 primitivos de EventBridge (bus, rule, target). Distinguir SQS standard vs FIFO en una línea cada uno. |
| Operativa (sin cuenta AWS real) | Levantar un demo Lambda + SQS en LocalStack, enviar un mensaje y confirmar que el handler lo procesó. Leer un `activity.yaml` y usar su `validate.sh` para medir tu progreso. |
| Arquitectónica | Dado un flujo ("procesar imágenes subidas a S3 y notificar a un canal"), diseñar la topología correcta (quién dispara, quién transforma, quién notifica, dónde está la DLQ) y justificarla. |
| Decisión | Dado un workload concreto, argumentar Lambda vs ECS/EKS con cifras aproximadas (duración, invocaciones/día, costo mensual estimado). |

## Criterios de evaluación

- Para 3 workloads dados (uno corto bursty, uno largo steady, uno cron pesado), elige Lambda / ECS / EKS justificado.
- Diseña un mini-pipeline event-driven con DLQ y visibility timeout coherentes, explicando por qué cada valor.
- Entrega las 2 actividades con sus validadores en verde (o `SKIP` limpio donde aplique).
- Nombra 3 costos ocultos típicos y qué knob los controla.

## Entregables

- Topología event-driven del escenario de la actividad `02-event-driven-design-decisions` en `DECISIONS.md`.
- Evidencia (log o captura ASCII) de que el demo Lambda + SQS en LocalStack funcionó, **o** justificación documentada de por qué saltaste (sin LocalStack instalado).

## Siguiente módulo

→ `aws-15-multi-account-org-identity-center` — operar múltiples cuentas con gobernanza central y SSO.
