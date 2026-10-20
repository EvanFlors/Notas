# Guía de corrección — ejercicio operativo (instructor-only)

Este documento es para el **evaluador**. No distribuir al candidato.
`validate.sh` cubre el gate automático; esta guía cubre la rúbrica cualitativa, errores comunes, señales de "respondió sin entender" y preguntas de seguimiento.

## 1. Solución de referencia (resumen)

### Dockerfile esperado (sketch)

```dockerfile
# syntax=docker/dockerfile:1.7

ARG BASE_RUNTIME=gcr.io/distroless/python3-debian12:nonroot@sha256:<DIGEST>
ARG BASE_BUILDER=python:3.12-slim@sha256:<DIGEST>

FROM ${BASE_BUILDER} AS builder
WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=secret,id=gh_token \
    PIP_INDEX_URL="https://x-access-token:$(cat /run/secrets/gh_token)@pypi.internal.acme.local/simple" \
    pip install --prefix=/install --no-warn-script-location -r requirements.txt
COPY app ./app

FROM ${BASE_RUNTIME}
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /build/app ./app
USER nonroot
EXPOSE 8000
ENTRYPOINT ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Puntos **no negociables**:

- `# syntax` presente (habilita BuildKit).
- `COPY requirements.txt` **antes** de `COPY app`.
- `--mount=type=secret` para `gh_token`. Debe consumirse en el mismo `RUN`.
- Base final por **digest**, no tag mutable.
- `USER` no-root explícito.
- `ENTRYPOINT` en **forma exec** (JSON array) → señales llegan a PID 1.

### compose.yaml esperado (sketch)

- Sin `privileged`, sin `docker.sock`, sin bind al código fuente en runtime.
- `read_only: true` + `tmpfs: [/tmp]`.
- `cap_drop: [ALL]`; `cap_add` **sólo** si bindea < 1024 (y aquí no, porque mapea `8000:8000`).
- `security_opt: ["no-new-privileges:true"]`.
- `pids_limit`, `mem_limit`, `cpus`.
- Secrets como archivos (`secrets:` top-level) montados en `/run/secrets/*`.
- Postgres sin `ports:` (o `127.0.0.1:5432:5432` sólo si justifica debugging local).
- `depends_on: condition: service_healthy` con healthcheck sobre `pg_isready`.

## 2. Errores comunes y cómo puntuarlos

| Error | Nivel máximo alcanzable |
|-------|-------------------------|
| Mantiene `ENTRYPOINT uvicorn ...` en forma shell | OP-1 ≤ 1 (rompe señales, misma clase que el starter) |
| Usa `ARG GH_TOKEN` y lo pasa en el `pip install` | OP-3 = 0 (red flag) |
| Multi-stage pero copia el builder entero (`COPY --from=builder / /`) | OP-2 ≤ 1 |
| Base `alpine` sin diagnosticar musl/C-extensions | OP-2 ≤ 1 |
| `latest` o tag mutable en `FROM` | OP-4 ≤ 1 |
| `cap_add: [SYS_ADMIN]` o similar sin justificar | OP-5 = 0 |
| `trivy image --exit-code 0` o sin flag `--severity` | OP-6 ≤ 1 |
| `cosign sign-blob` en vez de `cosign sign` sobre imagen | OP-7 ≤ 1 |
| Entrega `cosign.key` | descalifica OP-7 y aplica red flag global |

## 3. Señales de "respondió sin entender"

- Pega una solución de internet con `FROM alpine` + `apk add` cuando la app usa `cryptography` o `psycopg2-binary` (no probó la imagen → `cryptography` falla al compilar o requiere wheels que no existen para musl en todas las versiones).
- `notes.md` repite literalmente los enunciados sin medir ni justificar.
- `--mount=type=secret` presente pero el `RUN` también hace `echo $GH_TOKEN` o lo escribe a disco.
- Digests "falsos" (longitud distinta a 64 hex) — pedir reproducir el pin en vivo.
- Dice "distroless no tiene shell" pero su `ENTRYPOINT` es `["/bin/sh", ...]`.

## 4. Red flags (invalidación)

Ver `competency-matrix.yaml` → `red_flags`. Las que el gate automático **sí** detecta:

- `docker.sock` en `compose.yaml`.
- `cosign.key` entregada.
- `ARG` con nombres tipo secreto en `Dockerfile`.
- Token dummy filtrado en history o layers.
- `privileged: true`.

Las que requieren revisión humana:

- `curl | bash` desde fuente no verificada en algún `RUN`.
- `cosign verify --insecure-ignore-tlog` sin razón.
- Hardcode de credenciales fuera de `compose.yaml` (p. ej. en `app/`).

## 5. Preguntas de seguimiento (live only)

1. "Enséñame con `docker image inspect` el `User` efectivo de tu imagen final. ¿Qué pasaría si lo cambio a `root` por línea de comandos con `--user 0`? ¿Lo frenaría algo?" *(verifica entendimiento de que `--user` del runtime sobrepasa el `USER` del Dockerfile, por eso hace falta `no-new-privileges` y, en orquestadores, policies).*
2. "Si tu base `@sha256:...` desaparece del registry upstream (p. ej. gc), ¿puedes rebuildear la misma imagen bit a bit?" *(reproducibilidad real → necesita mirror interno).*
3. "Rota la clave de cosign y re-firma. ¿Qué deben hacer los consumidores que ya cachearon la firma anterior?"
4. "Haz que `trivy` falle: añade `pyyaml==5.3.1` a `requirements.txt`. Luego explícame cómo elegirías entre bump de versión vs ignorar la CVE."
5. "Convierte el `--mount=type=secret` a `--mount=type=secret,required=true` y rompe el build omitiéndolo. ¿Qué error ves y por qué es la configuración correcta en CI?"

## 6. Puntuación agregada

```
score_op = 0.10*OP1 + 0.10*OP2 + 0.12*OP3 + 0.08*OP4 + 0.20*OP5 + 0.20*OP6 + 0.20*OP7
         (cada OPx en 0..3)
pct_op   = score_op / 3 * 100
```

La operativa pesa 40% del examen total. Mínimo exigido en esta parte: 50%.
