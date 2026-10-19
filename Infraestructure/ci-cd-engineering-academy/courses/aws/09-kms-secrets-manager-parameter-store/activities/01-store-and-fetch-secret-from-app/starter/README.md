# Starter — aws-09-01-store-and-fetch-secret-from-app

## Pasos

1. Lee `../README.md`.
2. Prepara el scratch:
   ```bash
   mkdir -p /tmp/aws-09-store-fetch
   cd /tmp/aws-09-store-fetch
   ```
3. Copia `key-policy.template.json` a `/tmp/aws-09-store-fetch/key-policy.json` y adapta la cuenta y rol a los tuyos (en LocalStack: cuenta `000000000000`, rol `arn:aws:iam::000000000000:role/checkout-task`).
4. (Opcional) Levanta LocalStack:
   ```bash
   docker run --rm -d --name localstack -p 4566:4566 \
     -e SERVICES=kms,secretsmanager,ssm \
     localstack/localstack
   ```
5. Ejecuta el setup:
   ```bash
   bash setup.sh /tmp/aws-09-store-fetch
   ```
6. Envelope encryption:
   ```bash
   python3 envelope.py --scratch /tmp/aws-09-store-fetch \
     --payload "fake-card-token-NOT-REAL-0001"
   ```
7. "Arranque" simulado de la app:
   ```bash
   python3 app.py --scratch /tmp/aws-09-store-fetch
   ```
8. Valida:
   ```bash
   bash ../tests/validate.sh /tmp/aws-09-store-fetch
   ```
9. Limpieza:
   ```bash
   bash cleanup.sh /tmp/aws-09-store-fetch
   ```

> **Importante:** los valores son *fake*. No pongas secretos reales aquí.

## Dependencias Python

```
boto3
cryptography
```

Instala con `pip install -r requirements.txt`.
