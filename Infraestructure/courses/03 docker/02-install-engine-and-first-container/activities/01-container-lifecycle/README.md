# dkr-02-01 — Ciclo de vida de un contenedor Redis

## 1. Identificación

- **ID:** `dkr-02-01-container-lifecycle`
- **Tecnología:** docker
- **Módulo:** `02-install-engine-and-first-container`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a operar el ciclo de vida completo de un contenedor Redis: arrancar, inspeccionar, interactuar, parar, matar, y limpiar. Redis es ideal para esta práctica: imagen pequeña, con un puerto conocido (6379), con un `redis-cli` empacado y con un PID 1 que maneja SIGTERM correctamente.

La actividad no te hace memorizar flags — te hace **demostrar que entiendes qué pasa en cada paso**. El validador comprueba el estado final: un contenedor específico corriendo con los flags correctos, un segundo contenedor exited con causa controlada, y un archivo de notas con la inspección guardada.

## 3. Objetivos

Al terminar, deberías poder:

- Arrancar un contenedor con `--name`, `-p`, `-e`, `-d`, `--restart`.
- Diferenciar `docker exec` de "entrar al contenedor" en un sentido conceptual.
- Parar un contenedor limpiamente con `stop` y entender por qué no usas `kill` por default.
- Extraer campos específicos de `docker inspect` con `--format`.
- Dejar la máquina limpia (sin contenedores huérfanos del lab).

## 4. Prerrequisitos

- Docker instalado, versión ≥ 20.10. Verifica: `docker --version`.
- Daemon arriba: `docker info` no da error.
- Puertos 16379 y 16380 libres en el host (usamos puertos altos para evitar colisiones con Redis locales).
- `curl`, `bash` ≥ 4.
- Sin costo (imagen Redis es pública).

## 5. Instrucciones

Trabaja en `/tmp/dkr-02-01/`. Crea el directorio:

```bash
mkdir -p /tmp/dkr-02-01 && cd /tmp/dkr-02-01
```

### Paso 1 — contenedor Redis "cache" (principal)

1. Arranca Redis con **estos requisitos exactos** (el validador los verifica):
   - nombre: `cache`
   - detached (`-d`)
   - puerto: publica el 6379 interno al **16379** del host (`-p 16379:6379`)
   - restart policy: `unless-stopped`
   - variable de entorno: `-e REDIS_ROLE=primary`
   - imagen: `redis:7-alpine`
2. Verifica con `docker ps` que aparece como `Up`.
3. Prueba conectividad desde el host:
   ```bash
   docker exec cache redis-cli ping   # debe responder PONG
   ```
4. Inserta un par de keys:
   ```bash
   docker exec cache redis-cli SET greeting "hola docker"
   docker exec cache redis-cli SET module "dkr-02"
   ```

### Paso 2 — guardar `inspect` comentado

Extrae y guarda en `/tmp/dkr-02-01/notas-inspect.md` lo siguiente, en Markdown, con una línea de comentario tuya debajo de cada campo:

```bash
docker inspect --format '{{.State.Status}}'                  cache
docker inspect --format '{{.State.Pid}}'                     cache
docker inspect --format '{{.Config.Entrypoint}}'             cache
docker inspect --format '{{.Config.Cmd}}'                    cache
docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' cache
docker inspect --format '{{json .Config.Env}}'               cache
docker inspect --format '{{json .NetworkSettings.Ports}}'    cache
```

El archivo debe tener la forma:

```markdown
# notas-inspect — cache

## State.Status: running
_Comentario_: el contenedor está vivo porque el daemon reporta "running"...

## State.Pid: 12345
_Comentario_: ...

...
```

### Paso 3 — contenedor "oneshot" que termina solo

Lanza un segundo contenedor que:

- nombre: `oneshot`
- NO uses `--rm` (necesitamos verlo exited luego).
- imagen: `redis:7-alpine`
- comando: `redis-cli --version` (saldrá en < 1 s con exit 0).

Verifica después con `docker ps -a | grep oneshot` que está `Exited (0)`.

### Paso 4 — parar `cache` limpiamente

```bash
time docker stop cache
```

Debe tardar < 2 s. Si tarda ~10 s, algo no está bien en tus flags.

Luego **elimina** `cache` y `oneshot` con `docker rm` (no uses `rm -f`).

### Paso 5 — validar

```bash
bash /ruta/al/repo/courses/docker/02-install-engine-and-first-container/activities/01-container-lifecycle/tests/validate.sh
```

**IMPORTANTE**: el validador se ejecuta en dos momentos:

- Antes de `stop`/`rm`: verifica que `cache` corre con los flags correctos, que `oneshot` está exited, y que `notas-inspect.md` existe con los campos pedidos.
- Si corres el validador después de `rm`, fallará (es intencional: valida el **estado del lab**, no la historia).

Mira el script si quieres saber qué verifica exactamente.

## 6. Resultado esperado

- `docker ps` muestra `cache` corriendo con mapping `0.0.0.0:16379->6379/tcp`.
- `docker ps -a` muestra `oneshot` como `Exited (0)`.
- `docker exec cache redis-cli GET greeting` devuelve `hola docker`.
- `/tmp/dkr-02-01/notas-inspect.md` contiene los 7 campos del Paso 2.
- `docker stop cache` tarda menos de 2 s.
- `docker rm cache oneshot` elimina ambos sin `-f`.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS` cuando se ejecuta en el estado correcto (antes de parar).
- No queda ningún contenedor con esos nombres tras la limpieza.
- Las notas tienen comentarios **tuyos**, no solo salida de comandos.

## 8. Validación

```bash
bash courses/docker/02-install-engine-and-first-container/activities/01-container-lifecycle/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué pasaría si hubieras arrancado `cache` sin `-d`? ¿Y sin `--name`?
2. `--restart unless-stopped` — ¿qué pasa si reinicias el daemon de Docker? ¿Y si haces `docker stop` tú mismo?
3. ¿`oneshot` consume CPU/memoria mientras está `Exited`? ¿Qué sigue existiendo en el daemon?
4. ¿Por qué el validador falla si lo corres después de hacer `docker rm cache`?

## 10. Extensiones

- Repite el Paso 1 con `-p 16380:6379` en vez de `16379:6379`. ¿Cambia algo dentro del contenedor? ¿Y en el host?
- Lanza `cache` con `--init` y compara `ps -ef` dentro.
- Mide con `time` cuánto tarda un `docker stop` vs un `docker kill` en `cache`.

## 11. Limpieza

```bash
docker rm -f cache oneshot >/dev/null 2>&1 || true
rm -rf /tmp/dkr-02-01
```
