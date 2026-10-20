# dkr-04-01 — Persistir datos de Postgres con un volumen nombrado

## 1. Identificación

- **ID:** `dkr-04-01-persist-postgres-data`
- **Tecnología:** docker
- **Módulo:** `04-storage-volumes-bind-mounts-tmpfs`
- **Dificultad:** beginner
- **Duración estimada:** 30 min
- **Tipo:** guided-lab

## 2. Contexto

Un equipo levanta Postgres en un contenedor para desarrollo. Después de reiniciar la laptop, descubren que las tablas creadas el día anterior no están. El `pgdata` vivía en el upperdir del contenedor y se descartó.

Vas a montar Postgres **correctamente** con un volumen nombrado, probar que los datos sobreviven a la destrucción y recreación del contenedor, y además practicar un backup frío del volumen con `tar`.

## 3. Objetivos

- Crear un volumen Docker nombrado y montarlo en `/var/lib/postgresql/data`.
- Insertar datos, destruir el contenedor y recrearlo verificando persistencia.
- Hacer backup del volumen a un `.tar.gz` usando un contenedor efímero.

## 4. Prerrequisitos

- Docker ≥ 20 (`docker --version`).
- ~250 MB de pull (`postgres:16-alpine`, `busybox`).
- Directorio escribible en el host (`/tmp/` por default).
- Permisos para correr `docker` sin `sudo` (grupo `docker`).

Si Docker no está disponible el validador saltará con mensaje claro.

## 5. Instrucciones

Esta actividad es guiada: ejecuta `starter/run.sh` que arma todo paso a paso, imprime qué está haciendo y deja el entorno listo para que el validador verifique.

```bash
cd courses/docker/04-storage-volumes-bind-mounts-tmpfs/activities/01-persist-postgres-data
bash starter/run.sh
```

Pasos que ejecuta (y debes entender):

1. Limpieza previa (`docker rm -f`, `docker volume rm`).
2. `docker volume create dkr04-pg-data`.
3. `docker run` de Postgres con `--mount type=volume,source=dkr04-pg-data,target=/var/lib/postgresql/data`.
4. Espera activa a que Postgres acepte conexiones.
5. `CREATE TABLE marcadores (nota text)` + `INSERT INTO marcadores VALUES ('persisted-by-dkr04-01')`.
6. **Destruye** el contenedor por completo con `docker rm -f`.
7. Lanza un contenedor **nuevo** con el **mismo** volumen.
8. Espera y lee la fila para comprobar que sobrevivió.
9. Hace backup frío del volumen a `/tmp/dkr04-pg-backup.tar.gz`.

Al terminar, corre el validador:

```bash
bash tests/validate.sh
```

Si todo pasa, limpia:

```bash
bash starter/cleanup.sh
```

## 6. Resultado esperado

- Volumen `dkr04-pg-data` presente.
- Contenedor `dkr04-pg` corriendo con el volumen montado en `/var/lib/postgresql/data`.
- Query `SELECT nota FROM marcadores` devuelve `persisted-by-dkr04-01` después de un ciclo completo de `rm` + `run`.
- Archivo `/tmp/dkr04-pg-backup.tar.gz` existe y contiene al menos el fichero `PG_VERSION` dentro.

## 7. Criterios de aceptación

- `tests/validate.sh` exit code 0.
- El volumen fue creado explícitamente (no implícito).
- Backup `.tar.gz` legible (`tar tzf` lo lista sin error).

## 8. Validación

```bash
bash tests/validate.sh
```

El script:

- Verifica que Docker esté disponible (si no, SKIP con exit 0).
- Verifica existencia del volumen, del contenedor en estado `running`, de la tabla + fila, y del backup.
- Imprime un reporte y exit code claro.

## 9. Preguntas de reflexión

- ¿Qué pasa si borras el volumen con `docker volume rm` antes del segundo `run`? Pruébalo en una copia.
- Si en vez de volumen usaras un bind mount a `/tmp/pgdata`, ¿qué ganarías y qué perderías?
- ¿Por qué el backup con `tar` requiere parar Postgres o al menos ser consciente de un `pg_dump` lógico es más seguro? ¿Cuándo serviría cada uno?
- ¿Qué `docker inspect dkr04-pg --format '{{json .Mounts}}'` revela sobre el mount?

## 10. Extensiones

1. Restaurar el backup a un volumen nuevo (`dkr04-pg-data-restored`) y arrancar Postgres contra él.
2. Reemplazar `tar` por `pg_dump` ejecutado dentro del contenedor y comparar los dos backups.
3. Añadir un segundo contenedor (otra app) que escriba en el mismo volumen y observa qué pasa (típicamente **no** debes compartir pgdata entre dos Postgres — es un error).

## 11. Limpieza

```bash
bash starter/cleanup.sh
```

Ejecuta: `docker rm -f dkr04-pg`, `docker volume rm dkr04-pg-data`, `rm -f /tmp/dkr04-pg-backup.tar.gz`.
