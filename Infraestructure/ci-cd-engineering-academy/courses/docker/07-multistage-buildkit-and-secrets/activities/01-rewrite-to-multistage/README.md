# dkr-07-01 — Reescribir un Dockerfile monolitico a multi-stage

## 1. Identificacion

- **ID:** `dkr-07-01-rewrite-to-multistage`
- **Tecnologia:** docker
- **Modulo:** 07-multistage-buildkit-and-secrets
- **Dificultad:** intermediate
- **Duracion estimada:** 70 min
- **Tipo:** guided-lab

## 2. Contexto

Heredas un Dockerfile de una app Python/Flask. El build "funciona" y la imagen "arranca", pero pesa casi 1 GB y en una auditoria se encontraron `gcc`, `make` y headers de dev dentro de la imagen productiva. En Kubernetes los pods tardan segundos extra en bajar la imagen cada vez que arrancan.

Tu trabajo: reescribir el Dockerfile a **multi-stage** para que la imagen final pese **menos de 150 MB** y **no contenga toolchain de build**, sin cambiar la funcionalidad.

## 3. Objetivos

- Diagnosticar por que la imagen monolitica es tan grande.
- Separar un stage `builder` (con `gcc`, headers, pip wheels) de un stage `runtime` slim.
- Usar `COPY --from=builder /wheels /wheels` para traer solo los wheels.
- Lograr imagen final `multistage-lab:latest` con `docker images` reportando `< 150 MB`.
- Verificar con `docker run --rm multistage-lab sh -c 'command -v gcc'` que falla (no hay gcc).

## 4. Prerrequisitos

- Haber completado `dkr-06-dockerfile-idiomatic-and-caching`.
- Haber leido `theory/lesson.md` secciones 1-4 y 11.
- Docker Engine ≥ 20.10 con BuildKit (default en ≥ 23).
- `bash`, `python3`.
- Red para descargar `python:3.12` y `python:3.12-slim` la primera vez (~1.2 GB).
- Permisos: tu usuario en el grupo `docker` o `sudo`.
- Infraestructura: workspace temporal en `/tmp/dkr-07-01/`.
- **Costos:** ninguno (local).

## 5. Instrucciones

### Paso 0 — Bootstrap

Genera el workspace temporal con el Dockerfile monolitico y la app:

```bash
cd courses/docker/07-multistage-buildkit-and-secrets/activities/01-rewrite-to-multistage
bash starter/bootstrap.sh
cd /tmp/dkr-07-01
ls
```

Deberias ver `Dockerfile`, `app.py`, `requirements.txt`, `.dockerignore`.

### Paso 1 — Medir el estado inicial

```bash
docker build -t multistage-lab:baseline .
docker images multistage-lab:baseline
docker history multistage-lab:baseline | head -20
docker run --rm multistage-lab:baseline sh -c "command -v gcc && gcc --version | head -1"
```

Observa: tamano aprox. 900+ MB, `gcc` presente en la imagen final.

### Paso 2 — Disenar el multi-stage

En papel (o en comentarios en el Dockerfile), responde:

1. ¿Que necesita el stage `builder`? (base pesada con `gcc`, headers de `libpq`, etc.)
2. ¿Que necesita el stage `runtime`? (base slim, interprete, librerias dinamicas finales como `libpq5`).
3. ¿Que artefacto cruza del builder al runtime? (los wheels compilados).

### Paso 3 — Reescribir el Dockerfile

Reemplaza `/tmp/dkr-07-01/Dockerfile` siguiendo el patron de la seccion 11 de la leccion:

- Primera linea: `# syntax=docker/dockerfile:1`.
- Stage 1: `FROM python:3.12 AS builder`. Instala toolchain. Corre `pip wheel --wheel-dir /wheels -r requirements.txt`.
- Stage 2: `FROM python:3.12-slim AS runtime`. Instala solo las libs dinamicas necesarias (`libpq5`). `COPY --from=builder /wheels /wheels`. `pip install --no-index --find-links=/wheels /wheels/*.whl` y luego `rm -rf /wheels`. Copia `app.py`. `USER` no-root. `CMD`.

La app sigue sirviendo en el puerto 8000 con `/health`.

### Paso 4 — Verificar

```bash
cd /tmp/dkr-07-01
docker build -t multistage-lab:latest .
docker images multistage-lab:latest   # debe ser < 150 MB
docker run --rm multistage-lab:latest sh -c "command -v gcc" || echo "no gcc (ok)"
```

Luego corre el validador:

```bash
bash courses/docker/07-multistage-buildkit-and-secrets/activities/01-rewrite-to-multistage/tests/validate.sh
```

## 6. Resultado esperado

- Imagen `multistage-lab:latest` **< 150 MB**.
- `docker run --rm multistage-lab:latest sh -c 'command -v gcc'` falla (sin gcc).
- La app arranca y responde a `GET /health` con 200.
- Validador imprime `RESULT: X/X checks OK`.

## 7. Criterios de aceptacion

- [ ] Primera linea del Dockerfile: `# syntax=docker/dockerfile:1`.
- [ ] Al menos dos stages, con el stage final nombrado `runtime` o similar.
- [ ] Hay al menos un `COPY --from=<stage>`.
- [ ] Tamano final de la imagen `< 150 MB`.
- [ ] `gcc` NO esta en la imagen final.
- [ ] La app responde a `curl http://localhost:8000/health` con 200 cuando se corre con `-p 8000:8000`.
- [ ] Un `USER` no-root esta activo en el runtime.

## 8. Validacion

```bash
bash courses/docker/07-multistage-buildkit-and-secrets/activities/01-rewrite-to-multistage/tests/validate.sh
```

El validador comprueba, en `/tmp/dkr-07-01/`:

1. Que el Dockerfile tenga `# syntax=docker/dockerfile:1`.
2. Que haya al menos dos `FROM` y al menos un `COPY --from=`.
3. Que el build termine OK.
4. Que la imagen final pese **< 150 MB**.
5. Que `gcc` no exista en la imagen final.
6. Que la app arranque y responda `/health` con 200.

Si Docker no esta instalado o el daemon no responde, el validador imprime `SKIP` y sale 0.

## 9. Preguntas de reflexion

- ¿Por que el `COPY --from=builder /wheels /wheels` seguido de `rm -rf /wheels` no deja los wheels en la imagen? (Pista: cuentan como una capa cada uno).
- Si en vez de generar wheels copias `/usr/local/lib/python3.12/site-packages` del builder al runtime, ¿funciona? ¿Que problema tiene?
- ¿Que ganaria la imagen si cambias el runtime a `gcr.io/distroless/python3`? ¿Que perderias?
- Si tu app no tiene extensiones C, ¿sigue valiendo la pena multi-stage? ¿Por que?

## 10. Extensiones

- **E1** — Agrega un tercer stage `test` que corra `pytest` sobre `app.py`. Hazlo opcional con `--target test`.
- **E2** — Agrega `--mount=type=cache,target=/root/.cache/pip` en el builder y mide la diferencia en el segundo build.
- **E3** — Usa `pip install --compile` en el runtime y mide el impacto en cold-start.
- **E4** — Cambia el runtime a `python:3.12-alpine` y documenta que falla (musl vs glibc con extensiones C).

## 11. Limpieza

```bash
docker rmi multistage-lab:latest multistage-lab:baseline 2>/dev/null || true
docker builder prune -af >/dev/null 2>&1 || true
rm -rf /tmp/dkr-07-01
```
