# Starter — aws-08-02-dynamodb-partition-key-design

Pasos (ver `../README.md` para el detalle).

1. Carpeta de trabajo:
   ```bash
   mkdir -p /tmp/aws-08-dynamodb
   cp model.py /tmp/aws-08-dynamodb/model.py
   ```
2. (Opcional) levantar LocalStack:
   ```bash
   docker run -d --name aws08-localstack -p 4566:4566 \
     -e SERVICES=dynamodb localstack/localstack:latest
   ```
3. Ejecutar:
   ```bash
   cd /tmp/aws-08-dynamodb
   python3 model.py | tee run.log
   ```
   Sin LocalStack el script sale 0 con `SKIP: LocalStack not available`.
4. Escribir `/tmp/aws-08-dynamodb/ACCESS_PATTERNS.md` con 4 secciones:
   A patrones, B modelo single-table, C hot partition + sharding, D ejecucion.
5. Validar:
   ```bash
   bash ../tests/validate.sh /tmp/aws-08-dynamodb
   ```
6. Limpieza:
   ```bash
   docker rm -f aws08-localstack 2>/dev/null || true
   rm -rf /tmp/aws-08-dynamodb
   ```
