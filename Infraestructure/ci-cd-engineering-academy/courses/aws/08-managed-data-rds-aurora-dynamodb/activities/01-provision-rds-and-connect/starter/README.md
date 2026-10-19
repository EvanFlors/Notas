# Starter — aws-08-01-provision-rds-and-connect

Pasos resumidos (la narrativa completa esta en `../README.md`).

1. Preparar la carpeta de trabajo:
   ```bash
   mkdir -p /tmp/aws-08-rds
   cp main.tf /tmp/aws-08-rds/main.tf
   ```
2. Opcional: `terraform init && terraform plan -input=false` para validar HCL.
3. Levantar Postgres local:
   ```bash
   docker run -d --name aws08-pg -e POSTGRES_PASSWORD=lab -e POSTGRES_USER=lab \
     -e POSTGRES_DB=appdb -p 55432:5432 postgres:16
   ```
4. Modelar el esquema (`users`, `orders`, `order_items`) y practicar queries.
5. Escribir `/tmp/aws-08-rds/TOPOLOGY.md` con 4 secciones: hallazgos, ADR multi-AZ, esquema SQL, conexion segura.
6. Validar:
   ```bash
   bash ../tests/validate.sh /tmp/aws-08-rds
   ```
7. Limpieza:
   ```bash
   docker rm -f aws08-pg
   rm -rf /tmp/aws-08-rds
   ```
