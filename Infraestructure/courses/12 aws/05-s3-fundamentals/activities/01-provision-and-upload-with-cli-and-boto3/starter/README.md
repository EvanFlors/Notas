# Starter — aws-05-01-provision-and-upload-with-cli-and-boto3

## Pasos resumidos

1. Lee `../README.md`.
2. Levanta LocalStack:

   ```bash
   docker run --rm -d --name aws-05-localstack -p 4566:4566 -e SERVICES=s3 localstack/localstack:latest
   ```

3. Prepara el working dir:

   ```bash
   mkdir -p /tmp/aws-05-upload
   cd /tmp/aws-05-upload
   ```

4. Produce estos entregables (ver `../README.md` §5.4–5.7):
   - `lifecycle.json`
   - `bucket-policy.json`
   - `event-notification.json`
   - `bucket-name.txt`
   - `listing.txt`
   - `NOTES.md`

5. Valida:

   ```bash
   bash <ruta-repo>/courses/aws/05-s3-fundamentals/activities/01-provision-and-upload-with-cli-and-boto3/tests/validate.sh /tmp/aws-05-upload
   ```

6. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Si no tienes docker

Puedes completar la actividad escribiendo los JSON y las notas; el validador imprimira `SKIP` para los chequeos dinamicos y evaluara solo lo estructural. No se penaliza.
