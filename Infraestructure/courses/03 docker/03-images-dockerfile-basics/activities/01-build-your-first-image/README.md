# Actividad 01 — Construye tu primera imagen (FastAPI mínima)

## 1. Identificación

- **ID:** `dkr-03-01-build-your-first-image`
- **Tecnología:** `docker`
- **Módulo:** `dkr-03-images-dockerfile-basics`
- **Dificultad:** beginner
- **Duración estimada:** 50–60 min
- **Tipo:** guided-lab

## 2. Contexto

Primera imagen propia construida de cero. La actividad te da un proyecto
Python/FastAPI incompleto en `/tmp/dkr-03-01/` y un `Dockerfile` placeholder que
**no cumple todavía**. Tu trabajo es reemplazarlo por un `Dockerfile` correcto que
cumpla los criterios de aceptación: build limpio, usuario no-root, exec form,
`/healthz` responde HTTP 200, tamaño razonable (< 250 MB).

Si Docker no está instalado o el daemon no responde, el validador hace **SKIP
gracioso** (sale con éxito pero marca los checks como saltados). Esto permite
que el repo valide en CI sin obligar a tener Docker en todos los runners.

## 3. Objetivos

Al terminar:

- Escribes un `Dockerfile` que construye sin errores.
- La imagen corre y responde HTTP 200 en `/healthz` desde el host.
- El proceso dentro del contenedor corre como un UID no-root (≥ 1000).
- `CMD` o `ENTRYPOINT` está en exec form (JSON array).
- El `.dockerignore` existe y excluye al menos `.git/`, `__pycache__/`, `.venv/`,
  `.env*`.
- `docker run --rm <image> echo ok` imprime `ok` (prueba que la imagen contiene
  un shell/binario y es ejecutable).
- La imagen pesa < 250 MB (holgura razonable para `python:3.12-slim`).
- `tests/validate.sh` pasa.

## 4. Prerrequisitos

- Docker 24+ con el daemon corriendo (`docker info`). Si no, el validador hace SKIP.
- `curl`.
- Puerto 8000 libre en el host (o cambia `HOST_PORT` en el validador).
- Conectividad a `registry-1.docker.io` para pullear `python:3.12-slim` la primera vez.
- Costo: $0 (todo local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash courses/docker/03-images-dockerfile-basics/activities/01-build-your-first-image/starter/bootstrap.sh /tmp/dkr-03-01
```

El bootstrap crea `/tmp/dkr-03-01/project/` con:

```
project/
├── Dockerfile              ← PLACEHOLDER; tienes que reemplazarlo
├── .dockerignore           ← PLACEHOLDER vacio; tienes que llenarlo
├── requirements.txt
└── app/
    ├── __init__.py
    └── main.py
```

El `main.py` ya trae una app FastAPI con endpoints `/` y `/healthz`. No necesitas
tocar código Python.

### 5.2 Edita el `Dockerfile`

Debe cumplir, al menos:

| Criterio | Detalle |
|----------|---------|
| Base | `FROM python:3.12-slim` (acepta otros tags `python:3.12-*`). |
| Workdir | `WORKDIR /app` (o similar bajo `/`). |
| Deps primero | `COPY requirements.txt` + `RUN pip install -r requirements.txt` **antes** de copiar el código. |
| Código | `COPY app ./app`. |
| Usuario no-root | Crear un usuario (`useradd` o `adduser`) con UID ≥ 1000 y declarar `USER <uid-o-nombre>` antes del `CMD`/`ENTRYPOINT`. |
| Exec form | `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` (array JSON). |
| EXPOSE | `EXPOSE 8000` (documental; el validador no depende de esto pero es buena práctica). |

### 5.3 Edita el `.dockerignore`

Al menos debe excluir: `.git/`, `__pycache__/`, `.venv/`, `.env*`.

### 5.4 Validar

```bash
bash courses/docker/03-images-dockerfile-basics/activities/01-build-your-first-image/tests/validate.sh /tmp/dkr-03-01
```

El validador:

1. Chequea que `docker` existe y el daemon responde (SKIP gracioso si no).
2. Chequea estructura del proyecto (`Dockerfile` ≠ placeholder, `.dockerignore` no vacío).
3. Hace `docker build -t dkr-03-01:test .`.
4. Chequea `docker run --rm dkr-03-01:test echo ok` imprime `ok`.
5. Chequea exec form (`docker image inspect` → `.Config.Cmd` o `.Entrypoint` es array con > 1 elemento o un binario conocido).
6. Chequea `USER` no-root (`.Config.User` ≠ "" y ≠ "0" / "root").
7. Arranca el contenedor con `-p 8000:8000`, espera y hace `curl /healthz` esperando HTTP 200.
8. Chequea tamaño de la imagen < 250 MB (configurable con `MAX_MB`).
9. Para y limpia el contenedor.

## 6. Resultado esperado

- `tests/validate.sh` termina con `RESULT: N/N checks OK.` y `exit 0`.
- (Si Docker no está disponible) imprime `SKIP: docker no disponible` y termina `exit 0`.
- Puedes correr `curl http://localhost:8000/healthz` manualmente mientras el
  contenedor está arriba y ver `{"status":"ok"}`.

## 7. Criterios de aceptación

- [ ] `Dockerfile` existe y no es el placeholder.
- [ ] `.dockerignore` existe con las entradas mínimas.
- [ ] `docker build` termina con éxito.
- [ ] `docker run --rm <img> echo ok` imprime `ok`.
- [ ] `.Config.User` del `inspect` NO es root.
- [ ] `.Config.Cmd` o `.Config.Entrypoint` es array (exec form).
- [ ] `curl /healthz` responde 200.
- [ ] Tamaño de imagen < 250 MB.

## 8. Validación

```bash
bash courses/docker/03-images-dockerfile-basics/activities/01-build-your-first-image/tests/validate.sh /tmp/dkr-03-01
```

Variables opcionales:

- `HOST_PORT=8080` — usa otro puerto si el 8000 está ocupado.
- `MAX_MB=300` — relaja el límite de tamaño.
- `IMAGE_TAG=my-test:v1` — cambia el tag temporal.

## 9. Preguntas de reflexión

1. ¿Por qué `COPY requirements.txt .` + `RUN pip install` **antes** del `COPY app`? ¿Qué ganas y qué pierdes?
2. ¿Por qué `USER` **no** te protege de todo? Enumera dos tipos de ataque donde `USER` no es suficiente.
3. ¿Qué cambia en la salida de `docker inspect` entre exec form y shell form del `CMD`? Pruébalo cambiando el `CMD` a shell form y re-ejecutando `docker image inspect`.
4. Si cambias una sola línea del `main.py` y rebuildeas, ¿qué capas se re-crean y cuáles se reusan? Verifica con `docker history`.
5. ¿Qué pasaría si pusieras `USER appuser` **antes** del `RUN pip install`? Pruébalo y explica el error.

## 10. Extensiones (opcional)

- **E1** — Añade un `HEALTHCHECK` que llame a `/healthz` cada 30 s. Verifica con `docker ps` que aparece `(healthy)`.
- **E2** — Añade `ARG APP_VERSION=dev` y una `LABEL org.opencontainers.image.version=$APP_VERSION`. Verifica con `docker image inspect --format '{{.Config.Labels}}'`.
- **E3** — Cambia la base a `python:3.12-alpine` y observa qué rompe. (Pista: wheels de `uvicorn[standard]` para musl.)
- **E4** — Compara `docker history` de tu imagen vs la del `examples/01-dockerfile-python-app/`. ¿Qué diferencias hay y por qué?

## 11. Limpieza

```bash
docker rm -f dkr-03-01-ct 2>/dev/null || true
docker rmi dkr-03-01:test 2>/dev/null || true
rm -rf /tmp/dkr-03-01
```
