# Starter — aws-14-01-lambda-sqs-localstack-demo

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio de trabajo:
   ```bash
   mkdir -p /tmp/aws-14-lambda-sqs
   cp handler.py /tmp/aws-14-lambda-sqs/
   ```
3. Si tienes Docker + LocalStack, sigue §5 del README para levantar, crear la cola y la Lambda, y enviar un mensaje de prueba.
4. Si **no** tienes Docker o LocalStack, igualmente ejecuta el validador — hará `SKIP` limpio en la parte de infra y verificará el handler estructuralmente.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/14-serverless-integration-essentials/activities/01-lambda-sqs-localstack-demo/tests/validate.sh /tmp/aws-14-lambda-sqs
   ```
6. Compara tu solución con `../solution/REFERENCE.md`.

## Archivos

- `handler.py` — handler Python mínimo que puedes empaquetar y subir a LocalStack como la Lambda `orders-worker`. Es intencionalmente **sin dependencias externas** para evitar tener que empaquetar `boto3` u otras libs; LocalStack ya lo tiene en su runtime Python.
