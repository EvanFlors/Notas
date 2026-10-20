# Actividad 01 — Endurecer un contenedor FastAPI

## 1. Identificación

- **ID:** `dkr-13-01-harden-fastapi-container`
- **Tecnología:** `docker`
- **Módulo:** `13-runtime-security-and-hardening`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregamos una app FastAPI mínima (un endpoint `GET /health` y `GET /`) con un Dockerfile **inseguro por default** y un `run.sh` que la arranca con los defaults de Docker. Tu trabajo es endurecer **la imagen** y **el comando de ejecución** hasta que un validador compruebe los seis controles exigidos vía `docker inspect`.

Esta es la actividad que valida que puedes aplicar el patrón productivo completo (lección §12.4). El validador no te dice *cómo* arreglarlo, sólo *qué* falta.

## 3. Objetivos

Al terminar:

- Tu Dockerfile declara `USER <uid>:<gid>` con UID numérico >= 1000.
- Tu contenedor en ejecución cumple:
  1. `Config.User` numérico no vacío y no root.
  2. `HostConfig.ReadonlyRootfs: true`.
  3. `HostConfig.CapDrop` incluye `ALL` (y `CapAdd` está vacío o es mínimo).
  4. `HostConfig.SecurityOpt` incluye `no-new-privileges:true`.
  5. `HostConfig.Memory` > 0.
  6. `HostConfig.PidsLimit` > 0.
- La app responde `GET /health` con 200 OK en `http://127.0.0.1:8000/health`.
- `tests/validate.sh` termina con `RESULT: 6/6 OK`.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` y reproducido los tres ejemplos.
- Docker funcional (`docker info` OK). No se requiere red externa fuera del pull inicial de la base image. **Costo**: $0.
- Python 3 no es necesario (la app se instala dentro de la imagen).

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/01-harden-fastapi-container/starter/bootstrap.sh /tmp/dkr13-01
```

Esto crea `/tmp/dkr13-01/work/` con:

- `app/main.py` — FastAPI con `GET /` y `GET /health`.
- `app/requirements.txt` — `fastapi` + `uvicorn`.
- `Dockerfile` — **PLACEHOLDER inseguro** (root, FS escribible, sin HEALTHCHECK).
- `run.sh` — **PLACEHOLDER inseguro** (sin ningún hardening).

Mientras ambos placeholders estén en el estado inicial, el validador fallará.

### 5.2 Edita `Dockerfile`

Debe:

- Partir de una base image pinned (`python:3.12-slim` por ejemplo; **no** `latest`).
- Crear un usuario `app` con UID/GID 10001.
- `COPY --chown=app:app` para que el UID 10001 pueda leer la app.
- Instalar `requirements.txt` con `pip --no-cache-dir`.
- Terminar con `USER 10001:10001`.
- `EXPOSE 8000`.
- `ENTRYPOINT` que arranque uvicorn en 0.0.0.0:8000.

### 5.3 Edita `run.sh`

Debe emitir un `docker run -d` con, mínimo:

- `--name dkr13-01-app`.
- `--user 10001:10001`.
- `--read-only`.
- Un `--tmpfs` para `/tmp` (uvicorn no necesita más).
- `--cap-drop=ALL`.
- `--security-opt no-new-privileges:true`.
- `--memory=256m` (y `--memory-swap=256m`).
- `--pids-limit=100`.
- `--cpus=0.5` (opcional pero recomendado).
- `-p 127.0.0.1:8000:8000`.
- La imagen `dkr13-01:v1`.

### 5.4 Build y run

```bash
cd /tmp/dkr13-01/work
docker build -t dkr13-01:v1 .
bash run.sh
```

Espera unos segundos y prueba:

```bash
curl -s http://127.0.0.1:8000/health
# {"status":"ok"}
```

### 5.5 Valida

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/01-harden-fastapi-container/tests/validate.sh /tmp/dkr13-01
```

Debe terminar con `RESULT: 6/6 OK` (y SKIP opcional de Trivy si no está instalado).

## 6. Resultado esperado

- `/tmp/dkr13-01/work/Dockerfile` y `/tmp/dkr13-01/work/run.sh` editados.
- Contenedor `dkr13-01-app` en estado `running`.
- `curl http://127.0.0.1:8000/health` → `{"status":"ok"}`.
- `docker inspect dkr13-01-app` muestra los seis controles.
- `tests/validate.sh` → `RESULT: 6/6 OK`.

## 7. Criterios de aceptación

- [ ] `Config.User` != "" y != "root" y != "0".
- [ ] `HostConfig.ReadonlyRootfs` = true.
- [ ] `HostConfig.CapDrop` contiene `ALL`.
- [ ] `HostConfig.SecurityOpt` contiene `no-new-privileges:true`.
- [ ] `HostConfig.Memory` > 0.
- [ ] `HostConfig.PidsLimit` > 0.
- [ ] `curl /health` → `{"status":"ok"}`.
- [ ] (Bonus, si Trivy instalado) `trivy image dkr13-01:v1` no reporta CRITICAL con fix.

## 8. Validación

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/01-harden-fastapi-container/tests/validate.sh /tmp/dkr13-01
```

El validador:

1. Chequea que el contenedor `dkr13-01-app` existe y está `running`.
2. Lee `docker inspect` y aplica las seis comprobaciones.
3. Hace `curl /health` (si `curl` está disponible).
4. Opcional: corre `trivy image` si está instalado — SKIP si no.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `--read-only` pero NO `--tmpfs /tmp`? ¿Qué hace uvicorn que falla?
2. ¿Por qué `USER 10001:10001` numérico y no `USER app:app`?
3. Agrega `--cap-add=NET_BIND_SERVICE` y cambia el puerto a 80 adentro. ¿Qué más tienes que cambiar para que funcione?
4. Mide con `docker stats` el consumo real del contenedor. ¿Son razonables tus `--memory=256m` y `--pids-limit=100`?
5. ¿Qué cambiaría si corrieras esto en rootless Docker? ¿Alguno de los controles sobra?

## 10. Extensiones

- **E1** — Reemplaza la base `python:3.12-slim` por una **distroless** (`gcr.io/distroless/python3-debian12`) y re-mide tamaño con `docker images`.
- **E2** — Añade un `HEALTHCHECK` en el Dockerfile y verifica con `docker ps` que la columna STATUS muestra `(healthy)`.
- **E3** — Convierte el `docker run` a un `compose.yaml` equivalente con `services.<svc>.security_opt`, `read_only`, `tmpfs`, `cap_drop`, `deploy.resources.limits`. Comprueba con `docker compose up -d` + `docker inspect`.
- **E4** — Añade un seccomp profile custom (parte del default de moby/moby, elimina 2–3 syscalls que uvicorn no usa) y pruébalo con `--security-opt seccomp=./myapp-seccomp.json`.

## 11. Limpieza

```bash
docker rm -f dkr13-01-app 2>/dev/null || true
docker rmi dkr13-01:v1 2>/dev/null || true
rm -rf /tmp/dkr13-01
```
