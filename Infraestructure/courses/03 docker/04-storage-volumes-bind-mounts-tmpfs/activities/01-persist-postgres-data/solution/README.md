# Solución — dkr-04-01

Esta actividad es un `guided-lab`: la solución es el propio `starter/run.sh`.

## Comandos clave (resumen)

```bash
docker volume create dkr04-pg-data

docker run -d --name dkr04-pg \
  --mount type=volume,source=dkr04-pg-data,target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=devpass \
  postgres:16-alpine

# ... insertar fila ...

docker rm -f dkr04-pg

docker run -d --name dkr04-pg \
  --mount type=volume,source=dkr04-pg-data,target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=devpass \
  postgres:16-alpine

# fila sigue ahí

# Backup frío
docker run --rm \
  -v dkr04-pg-data:/data:ro \
  -v /tmp:/backup \
  busybox tar czf /backup/dkr04-pg-backup.tar.gz -C /data .
```

## Por qué funciona

- El volumen `dkr04-pg-data` vive en `/var/lib/docker/volumes/dkr04-pg-data/_data/` (Linux). Es independiente del `upperdir` del contenedor.
- `docker rm -f` destruye el contenedor y su upperdir, pero **no** toca el volumen (no se pasó `-v` a `rm`, y el volumen es *nombrado*).
- Al relanzar con el mismo `source=dkr04-pg-data`, Postgres encuentra `PG_VERSION` presente y **no** reinicializa el cluster. Las tablas, roles y WAL siguen ahí.

## Variantes y notas

- `-v dkr04-pg-data:/var/lib/postgresql/data` haría lo mismo con sintaxis corta. Para scripts se prefiere `--mount` por claridad.
- Si en vez del volumen pasas una ruta absoluta (`-v /tmp/pgdata:/var/lib/postgresql/data`) estás usando **bind mount**: funciona, pero Postgres puede fallar con `Permission denied` si el directorio del host no es propiedad del UID interno 70 (postgres en la imagen alpine) o 999 (debian base). El volumen gestionado evita ese dolor.
- `pg_dump` suele ser preferible al tar frío para bases en producción porque garantiza consistencia transaccional. El tar frío sirve cuando puedes parar el servicio o cuando el filesystem soporta snapshots atómicos.
