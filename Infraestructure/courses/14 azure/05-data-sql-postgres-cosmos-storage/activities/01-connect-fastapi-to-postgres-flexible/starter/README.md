# Starter — az-05-01-connect-fastapi-to-postgres-flexible

Pasos resumidos (la narrativa completa esta en `../README.md`).

1. Preparar la carpeta de trabajo:
   ```bash
   mkdir -p /tmp/az-05-pg
   cp main.tf /tmp/az-05-pg/main.tf
   ```
2. (Opcional) `terraform init && terraform plan -input=false` para validar HCL. Fallara al pedir subscription — es esperado.
3. Levantar Postgres local:
   ```bash
   docker run -d --name az05-pg \
     -e POSTGRES_PASSWORD=lab -e POSTGRES_USER=lab -e POSTGRES_DB=appdb \
     -p 55432:5432 postgres:16
   ```
4. Modelar el esquema (`users`, `orders`, `order_items`), ver `../README.md` seccion 5.
5. Escribir `/tmp/az-05-pg/TOPOLOGY.md` con 4 secciones:
   - A hallazgos del audit (>=2 con la palabra `Hallazgo`),
   - B ADR Postgres Flexible (tier, HA, private access, Entra ID auth, backups, >=2 nombres de atributos TF),
   - C esquema SQL con indice justificado,
   - D comparativa Azure SQL vs Postgres Flexible.
6. Validar:
   ```bash
   bash ../tests/validate.sh /tmp/az-05-pg
   ```
7. Limpieza:
   ```bash
   docker rm -f az05-pg 2>/dev/null || true
   rm -rf /tmp/az-05-pg
   ```
