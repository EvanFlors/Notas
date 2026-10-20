# Recursos — aws-14

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia (enlaces y pricing cambian).

## Oficiales — Lambda

- Developer Guide: `https://docs.aws.amazon.com/lambda/latest/dg/welcome.html`
- Runtimes: `https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html`
- Modelo de ejecución (`init → invoke → freeze`): `https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html`
- Concurrency: `https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html`
- Lambda Power Tuning (optimizar memoria vs costo): `https://github.com/alexcasalboni/aws-lambda-power-tuning`
- AWS Lambda Powertools for Python: `https://docs.powertools.aws.dev/lambda/python/latest/`

## Oficiales — API Gateway

- Choose between REST, HTTP and WebSocket: `https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html`
- Pricing: `https://aws.amazon.com/api-gateway/pricing/`

## Oficiales — EventBridge

- User guide: `https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html`
- Event patterns: `https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html`
- Pipes: `https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes.html`

## Oficiales — SQS

- Developer Guide: `https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html`
- Standard vs FIFO: `https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html`
- Visibility timeout: `https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html`
- Dead-letter queues: `https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html`

## Oficiales — SNS

- Developer Guide: `https://docs.aws.amazon.com/sns/latest/dg/welcome.html`
- Message filtering: `https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html`
- Fanout pattern (SNS → SQS): `https://docs.aws.amazon.com/sns/latest/dg/sns-common-scenarios.html`

## Oficiales — Step Functions

- Developer Guide: `https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html`
- Amazon States Language (ASL) spec: `https://states-language.net/spec.html`
- Standard vs Express: `https://docs.aws.amazon.com/step-functions/latest/dg/concepts-standard-vs-express.html`
- Service integrations: `https://docs.aws.amazon.com/step-functions/latest/dg/concepts-service-integrations.html`

## LocalStack (lo que usamos en los demos)

- LocalStack docs: `https://docs.localstack.cloud/`
- Imagen Docker: `localstack/localstack:latest`
- Lambda en LocalStack: `https://docs.localstack.cloud/user-guide/aws/lambda/`
- SQS en LocalStack: `https://docs.localstack.cloud/user-guide/aws/sqs/`
- SNS en LocalStack: `https://docs.localstack.cloud/user-guide/aws/sns/`
- Step Functions en LocalStack: `https://docs.localstack.cloud/user-guide/aws/stepfunctions/`

Nota: LocalStack **Community** cubre Lambda, SQS, SNS, EventBridge y Step Functions (modo básico) suficientes para los ejemplos del módulo. Features avanzadas de Lambda (SnapStart, provisioned concurrency fine-grained) requieren LocalStack Pro — no las usamos aquí.

## Lecturas y charlas

- "Serverless Patterns Collection" (AWS): `https://serverlessland.com/patterns`
- "Idempotency with Lambda Powertools": `https://docs.powertools.aws.dev/lambda/python/latest/utilities/idempotency/`
- "Operating Lambda" series (AWS Compute Blog): buscar "Operating Lambda: Understanding event-driven architecture".

## Checklist de verificación requerida en Fase 4

- Precio actual de API Gateway REST vs HTTP (cambia; validar en calculator).
- Precio actual por millón de eventos custom en EventBridge.
- Soporte actual de LocalStack Community para Step Functions (modo distributed Map, etc.).
- Versión actual de `aws-lambda-powertools` y breaking changes recientes.
- Si Lambda ha ampliado el límite de 15 min (histórico; a día de hoy sigue siendo 15 min).

## Contexto AWS que ya debes saber

- `aws-02` IAM: cómo escribir trust policies y permission policies — Lambda y Step Functions se pisan si el role no permite las acciones.
- `aws-05` S3: trigger S3 → Lambda es el ejemplo canónico.
- `aws-09` compute: para comparar Lambda vs EC2/ECS/EKS con cifras concretas.
