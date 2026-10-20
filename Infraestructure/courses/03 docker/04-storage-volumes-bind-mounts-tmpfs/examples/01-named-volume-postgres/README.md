# Ejemplo 01 — Postgres con volumen nombrado

## Concepto que demuestra

Un **volumen nombrado** desacopla el ciclo de vida de los datos del ciclo de vida del contenedor. Vas a:

1. Arrancar Postgres con `pgdata` montado como volumen.
2. Crear una tabla y una fila.
3. Destruir el contenedor por completo (`docker rm -f`).
4. Levantar un contenedor nuevo con el mismo volumen.
5. Comprobar que la fila sigue ahí.

Si lo haces sin volumen (prueba al final), la fila desaparece.

## Prerrequisitos

- Docker instalado (`docker --version` ≥ 24).
- Puerto no requerido (todo pasa dentro de la red default; usamos `exec`).
- Red: pull de `postgres:16-alpine` (~230 MB) la primera vez.

## Ejecución

Copia-pega en orden. **Lee la salida de cada paso antes del siguiente.**

```bash
# 0. Limpieza por si algo quedó de corridas previas
docker rm -f dkr04-pg >/dev/null 2>&1 || true
docker volume rm dkr04-pgdata >/dev/null 2>&1 || true

# 1. Crear el volumen explícitamente (opcional: --mount lo exigiría)
docker volume create dkr04-pgdata
docker volume inspect dkr04-pgdata

# 2. Arrancar Postgres con el volumen montado en el pgdata
docker run -d --name dkr04-pg \
  --mount type=volume,source=dkr04-pgdata,target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=devpass \
  postgres:16-alpine

# Espera un par de segundos a que inicialice
sleep 5
docker logs --tail 5 dkr04-pg

# 3. Crear tabla + fila
docker exec -e PGPASSWORD=devpass dkr04-pg \
  psql -U postgres -c "CREATE TABLE clientes (id serial PRIMARY KEY, nombre text);"
docker exec -e PGPASSWORD=devpass dkr04-pg \
  psql -U postgres -c "INSERT INTO clientes (nombre) VALUES ('Ada');"
docker exec -e PGPASSWORD=devpass dkr04-pg \
  psql -U postgres -c "SELECT * FROM clientes;"

# 4. Destruir el contenedor. Nota: el volumen sigue vivo.
docker rm -f dkr04-pg
docker volume ls | grep dkr04-pgdata

# 5. Recrear otro contenedor con el MISMO volumen
docker run -d --name dkr04-pg \
  --mount type=volume,source=dkr04-pgdata,target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=devpass \
  postgres:16-alpine
sleep 5

# 6. ¿Sobrevivió la fila?
docker exec -e PGPASSWORD=devpass dkr04-pg \
  psql -U postgres -c "SELECT * FROM clientes;"
# Debe mostrar: 1 | Ada
```

### Comparativa: sin volumen

```bash
docker rm -f dkr04-pg
docker run -d --name dkr04-pg-novol -e POSTGRES_PASSWORD=devpass postgres:16-alpine
sleep 5
docker exec -e PGPASSWORD=devpass dkr04-pg-novol \
  psql -U postgres -c "INSERT INTO clientes (nombre) VALUES ('Grace');" 2>&1 | head -1
# ERROR: no existe la tabla -- es otro Postgres, con pgdata vacío.
docker rm -f dkr04-pg-novol
```

## Limpieza

```bash
docker rm -f dkr04-pg dkr04-pg-novol 2>/dev/null || true
docker volume rm dkr04-pgdata 2>/dev/null || true
```

## Qué debiste observar

- `docker volume inspect` muestra `Mountpoint` dentro de `/var/lib/docker/volumes/...` (en Linux; en Docker Desktop vive dentro de la VM).
- Tras `docker rm -f dkr04-pg`, `docker volume ls` sigue listando `dkr04-pgdata`.
- Al recrear el contenedor con el mismo volumen, Postgres **no** reinicializa (ve que `PG_VERSION` existe en `pgdata`) y la tabla + fila siguen ahí.
- Sin volumen, cada `docker run` arranca con un pgdata vacío.

## Para profundizar

- `docker inspect dkr04-pg --format '{{json .Mounts}}'` para ver el mount desde el punto de vista del contenedor.
- Backup lógico con `pg_dump` ejecutado en el contenedor (preferido para DBs vs tar frío del `pgdata`).
