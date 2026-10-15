# Teoria — Dockerfile idiomatico y cache

> Leccion profunda, pensada para 3 horas incluyendo exploracion en consola. Lenguaje: prosa en espanol, codigo y comandos en ingles.

---

## 1. Punto de partida: por que la cache es la diferencia entre segundos y minutos

Cuando ejecutas `docker build`, BuildKit no procesa el Dockerfile de forma lineal e ingenua. Construye un **DAG** (grafo dirigido aciclico) de operaciones y, para cada una, calcula una **clave de cache**. Si esa clave ya existe en el store local (o en el remote cache que configures), reutiliza el resultado y salta la ejecucion.

En apps interpretadas (Python, Node, Ruby) la instruccion mas cara es casi siempre la de instalar dependencias: `pip install -r requirements.txt`, `npm ci`, `bundle install`. Hablamos de **decenas de segundos a varios minutos**. En cambio, copiar codigo fuente y lanzar `python -m compileall` cuesta milisegundos.

El objetivo entero del modulo cabe en una frase:

> **Hacer que la instruccion cara (`pip install`) dependa solo del lockfile, no del codigo. Asi cambiar el codigo nunca invalida la cache de las dependencias.**

Ese es el 80% del valor. El resto (healthchecks, labels, `--mount=type=cache`) refina.

---

## 2. Modelo mental: que entra en el hash de cache

Para cada instruccion, BuildKit calcula una clave que depende de:

```
cache_key(step N) = hash(
  cache_key(step N-1),            # el padre en el grafo
  instruction_text,               # el texto literal de la linea
  input_files_hash,               # para COPY/ADD: hash del contenido copiado
  build_args_referenced,          # ARGs usados en esta linea
  platform                        # linux/amd64 vs linux/arm64
)
```

Consecuencias practicas que debes internalizar:

1. **Cambiar una linea invalida todo lo que viene abajo.** No lo que viene arriba.
2. **Reordenar `COPY requirements.txt` y `COPY . .` cambia radicalmente el comportamiento.**
3. **Un comentario cuenta como cambio textual** (es parte de `instruction_text`). Un espacio en blanco al final tambien.
4. **El contenido del archivo copiado se hashea.** Si tocas una coma en `requirements.txt`, la cache de `pip install` muere. Si tocas `app.py` sin tocar `requirements.txt`, no.
5. **El contexto no entra entero en el hash**; solo lo que efectivamente se copia (BuildKit es inteligente, y `.dockerignore` ayuda a reducirlo mas).

Diagrama mental:

```
FROM python:3.12-slim        ──┐
WORKDIR /app                   │  cache estable (cambia rara vez)
RUN apt-get install libpq-dev  │
COPY requirements.txt .      ──┤  cambia solo si editas el lockfile
RUN pip install -r req...    ──┤  <── la instruccion CARA; aqui vive la cache
COPY . .                     ──┤  cambia en cada edicion de codigo
CMD ["python", "app.py"]     ──┘  siempre barata
```

Si tiras `COPY . .` arriba de `pip install`, cualquier edicion de un `.md` invalida el `pip install`. Eso es exactamente el anti-patron que vamos a evitar.

---

## 3. Orden canonico de instrucciones (para apps interpretadas)

El patron que debes memorizar:

```dockerfile
# 1. Base image (cambia una vez al mes)
FROM python:3.12-slim

# 2. ENV estables que no dependen del codigo
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 3. System deps (cambian rara vez; combina en un RUN)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 \
      curl \
 && rm -rf /var/lib/apt/lists/*

# 4. WORKDIR
WORKDIR /app

# 5. LOCKFILE primero
COPY requirements.txt ./

# 6. Instalar deps (la instruccion CARA; su cache depende solo del lockfile)
RUN pip install -r requirements.txt

# 7. CODIGO al final
COPY . .

# 8. Usuario no-root
RUN useradd -r -u 1001 app && chown -R app:app /app
USER app

# 9. Metadata y runtime
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Por que funciona:** editar `app.py` solo invalida desde el paso 7 hacia abajo. Pasos 1–6 vienen de cache. Rebuild caliente: segundos.

Variacion para Node:

```dockerfile
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
```

Variacion para Rust/Go compilados: el patron cambia (ver `dkr-07` multi-stage). Aqui solo tratamos apps interpretadas.

---

## 4. `COPY` vs `ADD`: por que la guia oficial prefiere `COPY`

Las dos instrucciones existen por razones historicas. Diferencias concretas:

| Capacidad | `COPY` | `ADD` |
|-----------|--------|-------|
| Copiar archivos locales a la imagen | si | si |
| Permisos y ownership (`--chown`, `--chmod`) | si | si |
| Extraer automaticamente un `.tar(.gz|.bz2|.xz)` local | **no** | si |
| Descargar una URL remota como archivo | no (usa `RUN curl`) | si |
| Verificar checksum (`--checksum`) | no | si (BuildKit) |

Reglas practicas:

1. **Por defecto, usa `COPY`.** Hace una cosa y la hace claramente.
2. Para descargar artefactos remotos usa `RUN curl -fsSL ... | sha256sum -c` dentro del mismo `RUN`, no `ADD <url>`. Razones:
   - `ADD <url>` no cachea bien (no re-verifica el remoto).
   - El tarball queda como archivo entero en la capa, incluso si solo necesitas un binario.
3. Si **de verdad** necesitas extraer un tar local (ej. un rootfs de base), `ADD rootfs.tar.gz /` es legitimo y mas limpio que `COPY` + `RUN tar -xzf`.

La guia oficial de Docker lo resume en una linea: *"COPY is preferred over ADD. ADD should only be used when its special features (tar extraction, URL fetch) are explicitly needed."*

---

## 5. Capas, `RUN` combinados y el matiz de BuildKit

Cada instruccion `RUN`, `COPY` y `ADD` crea una capa en el layer graph. Historicamente la recomendacion era:

> *Combina todos los `apt-get` en un solo `RUN` para no dejar capas intermedias con la cache de apt.*

Eso sigue siendo cierto para `apt-get`, pero por una razon mas sutil:

```dockerfile
# MAL — tres capas, la cache de apt queda en la segunda y la tercera no la borra
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

`rm` en la tercera capa **no reduce** el tamano de la imagen porque las capas son aditivas: la segunda capa ya contiene esos archivos. La correcta:

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

**Matiz BuildKit:** con `--mount=type=cache,target=/var/cache/apt`, puedes mantener la cache de apt *fuera* del filesystem de la imagen. Ahi la motivacion para combinar se debilita; el combinado sigue siendo util para claridad y para evitar que un `update` cachee y un `install` corra con una lista desactualizada (bug clasico).

Reglas:

- `apt-get update && apt-get install && rm`: **siempre en el mismo `RUN`**.
- `--no-install-recommends`: siempre; evita decenas de MB de deps opcionales.
- Para el lockfile de la app, un `RUN` separado esta bien (su cache depende solo del lockfile, no mezcles).

---

## 6. `--mount=type=cache`: persistir caches entre builds

BuildKit (sintaxis `# syntax=docker/dockerfile:1`) permite montar un directorio **persistente entre builds pero fuera de la imagen final**:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

Que gana:

- La primera vez descarga wheels a `/root/.cache/pip`.
- La segunda vez, aunque la cache de la *capa* este invalidada (porque cambiaste el lockfile), `pip` reutiliza wheels locales en vez de volver a descargarlas de PyPI.

Que **no** gana:

- No sustituye el ordenamiento correcto. Si pones `COPY . .` arriba, igual pierdes.
- No es reproducible bit-a-bit entre maquinas: la cache es local a tu builder.

Analogo para apt:

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl
```

Nota: `--mount=type=cache` **no entra** en la imagen final (los archivos del mount no quedan en la capa). Es puro acelerador de build.

---

## 7. `ARG` vs `ENV`: build-time vs runtime

Dos variables, dos ciclos de vida distintos.

```dockerfile
ARG APP_VERSION=0.0.0        # Solo visible durante el build
ENV APP_VERSION=${APP_VERSION}  # Persiste en la imagen y en el contenedor
```

| Aspecto | `ARG` | `ENV` |
|---------|-------|-------|
| Visible durante el build | si | si |
| Visible en el contenedor en runtime | **no** | si |
| Queda en `docker history` | **si** (en texto plano) | si |
| Se puede sobrescribir en `build` | si (`--build-arg`) | no directamente |
| Se puede sobrescribir en `run` | n/a | si (`-e`) |

Consecuencias de seguridad:

- **Nunca pases secretos por `ARG`.** Quedan en `docker history` y son visibles para cualquiera con la imagen. El patron correcto es `--mount=type=secret` (tema de `dkr-07`).
- **Usa `ARG` para parametrizar el build**: version del paquete, usuario UID, feature flags que compilan.
- **Usa `ENV` para configurar la app**: `PYTHONUNBUFFERED=1`, `LANG=C.UTF-8`, defaults de la app.

Pequena trampa: un `ARG` declarado antes de `FROM` **solo** es visible en la linea `FROM`. Para usarlo dentro del stage hay que re-declararlo:

```dockerfile
ARG PY_VERSION=3.12
FROM python:${PY_VERSION}-slim
ARG PY_VERSION             # re-declarar para usarlo aqui abajo
RUN echo "built on python ${PY_VERSION}"
```

---

## 8. `HEALTHCHECK`: cuando la app esta *lista*, no solo *arrancada*

Docker (y Compose, y Swarm, y Kubernetes via equivalencias) usa el `HEALTHCHECK` del Dockerfile como senal de **readiness**. Sin healthcheck, un orquestador considera el contenedor "sano" apenas el proceso arranca, lo cual es casi siempre falso para un servidor web que todavia esta compilando templates o abriendo conexiones a la DB.

Forma:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1
```

Parametros:

- `--interval`: cada cuanto corre el check.
- `--timeout`: cuanto espera antes de considerar fallo.
- `--start-period`: periodo de gracia inicial (fallos no cuentan).
- `--retries`: cuantos fallos consecutivos antes de marcar `unhealthy`.

Buenas practicas:

- El endpoint debe ser **barato** (no hagas queries pesadas a la DB en `/health`).
- Debe reflejar **readiness** real (DB conectada, migraciones corridas), no solo que el proceso respira.
- Prefiere `curl -fsS` (fail silent, show errors) para que el exit code sea significativo.
- Si tu imagen no tiene `curl`, agregalo o usa `wget`/`python -c "import urllib.request..."`.

Nota Kubernetes: K8s **ignora** el `HEALTHCHECK` del Dockerfile; usa `livenessProbe`/`readinessProbe` del pod spec. Aun asi declararlo es util para `docker` directo, Compose y Swarm.

---

## 9. `LABEL` y los OCI standard annotations

Los **OCI image annotations** son un conjunto de claves estandar bajo el prefijo `org.opencontainers.image.*` que todo registry y herramienta de supply chain entiende. Agregarlos cuesta nada y mejora enormemente la trazabilidad.

Set recomendado:

```dockerfile
LABEL org.opencontainers.image.title="my-app" \
      org.opencontainers.image.description="FastAPI service for X" \
      org.opencontainers.image.version="1.2.3" \
      org.opencontainers.image.authors="Equipo Plataforma <plat@example.com>" \
      org.opencontainers.image.source="https://github.com/example/my-app" \
      org.opencontainers.image.documentation="https://github.com/example/my-app#readme" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.revision="abc1234" \
      org.opencontainers.image.created="2026-01-15T12:00:00Z" \
      org.opencontainers.image.vendor="Example Inc"
```

Verificable con:

```bash
docker inspect --format '{{json .Config.Labels}}' my-app:latest | jq
```

Los campos `revision` y `created` suelen venir por `--build-arg` desde CI (git SHA, timestamp del build). Patron tipico:

```dockerfile
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}"
```

Herramientas como `syft`, `trivy`, `cosign` y los UIs de GHCR/Harbor leen estos labels para mostrar metadata uniforme.

---

## 10. Imagen funcional y no interactiva

Un error comun: imagenes que parecen funcionar en local pero fallan en CI por asumir TTY o preguntar interactivamente.

Controles minimos:

```dockerfile
# apt no debe preguntar nada
ENV DEBIAN_FRONTEND=noninteractive

# Python debe flushear logs inmediatamente (clave para ver logs en Docker/K8s)
ENV PYTHONUNBUFFERED=1

# No escribir .pyc innecesarios en el filesystem de la imagen
ENV PYTHONDONTWRITEBYTECODE=1

# Timezone explicito (si tu app timestampea)
ENV TZ=UTC

# Localizacion UTF-8 (evita UnicodeDecodeError raros)
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Usuario no-root
RUN useradd -r -u 1001 app
USER app

# Forma exec para que el proceso reciba senales directamente
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0"]
```

Senales en PID 1 (recordatorio de `dkr-02`): la **forma exec** (`CMD ["x", "y"]`) hace que tu proceso sea PID 1 y reciba `SIGTERM` directo. La **forma shell** (`CMD python app.py`) ejecuta `/bin/sh -c` como PID 1 y la senal se pierde en el camino.

---

## 11. Anti-patrones y como se diagnostican

### 11.1 `COPY . .` antes de instalar deps

```dockerfile
# MAL
FROM python:3.12-slim
WORKDIR /app
COPY . .                          # <── cualquier cambio invalida el pip install
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

**Sintoma:** `docker build` tarda lo mismo cada vez.
**Diagnostico:** `docker build --progress=plain` muestra `[2/4] COPY . .` cambiando siempre y disparando `[3/4] RUN pip install` sin cache.
**Fix:** mover `COPY requirements.txt` arriba y hacer `COPY . .` al final.

### 11.2 Usar `latest` como base

```dockerfile
FROM python:latest        # MAL — reproducibilidad rota
```

**Problema:** mismo Dockerfile, builds en dias distintos, imagenes distintas. Pin minimo: `python:3.12-slim`. Pin ideal: `python:3.12-slim@sha256:abc...` (tema de `dkr-09`).

### 11.3 `apt-get update` y `install` en `RUN` separados

```dockerfile
RUN apt-get update              # cache aqui
RUN apt-get install -y curl     # usa un index desactualizado
```

**Problema:** si BuildKit cachea el `update` por semanas, el `install` corre con un index obsoleto y puede fallar o traer paquetes viejos.
**Fix:** combinalos.

### 11.4 Dejar artefactos de build en la imagen final

```dockerfile
RUN apt-get install -y gcc build-essential libpq-dev \
 && pip install psycopg2
# gcc y build-essential (300+ MB) viajan a produccion
```

**Fix completo:** multi-stage (modulo `dkr-07`). Fix minimo: desinstalar al final del mismo `RUN`:

```dockerfile
RUN apt-get install -y --no-install-recommends gcc libpq-dev \
 && pip install psycopg2 \
 && apt-get purge -y gcc \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
```

### 11.5 Secretos por `ARG`

```dockerfile
ARG GITHUB_TOKEN           # MAL — queda en docker history
RUN git clone https://x-access-token:${GITHUB_TOKEN}@github.com/org/repo
```

**Diagnostico:** `docker history --no-trunc <image>` lo muestra en texto plano.
**Fix:** `--mount=type=secret` (modulo `dkr-07`).

---

## 12. Diagnostico y preguntas de evaluacion

### 12.1 Herramientas de diagnostico

```bash
# Historia de capas con tamanos
docker history <image>

# Historia completa, sin truncar (ve ARGs filtrados aqui)
docker history --no-trunc <image>

# Progreso detallado del build (ve que esta cacheado y que no)
docker build --progress=plain -t <image> .

# Inspeccion del filesystem capa por capa (opcional, ver dkr-11)
dive <image>
```

Pistas a leer:

- `CACHED` al lado de un step en `--progress=plain` = cache hit.
- Sin `CACHED` = re-ejecucion. Si ves `pip install` sin `CACHED` en rebuild caliente, algo arriba cambio.
- Capas gigantes en `docker history` (>100 MB) suelen ser artefactos de build o caches no limpiadas.

### 12.2 Preguntas para probarte

Responde sin consultar el Dockerfile ni la leccion:

1. Que entra exactamente en el hash de cache de una instruccion `COPY`?
2. Por que `COPY . .` arriba de `RUN pip install` destruye la cache?
3. Cual es la diferencia operativa entre `ARG` y `ENV` para pasar la version de la app?
4. Por que la guia oficial recomienda `COPY` sobre `ADD`? Da un caso en el que `ADD` sea la opcion correcta.
5. Que ventaja da `--mount=type=cache,target=/root/.cache/pip` si cambia el lockfile?
6. Que diferencia hay entre el `HEALTHCHECK` de Docker y la `readinessProbe` de Kubernetes?
7. Lista cinco OCI standard annotations y para que sirve cada uno.
8. Por que `apt-get update` y `apt-get install` deben ir en el mismo `RUN`?
9. Como demostrarias que un `GITHUB_TOKEN` pasado por `ARG` quedo filtrado en la imagen?
10. Dado un Dockerfile que tarda 3 minutos en rebuild caliente, cual es la primera cosa que miras en el output de `docker build --progress=plain`?

Si no puedes responder al menos 8 de las 10 sin consultar, re-lee las secciones 2, 3, 7 y 9 antes de hacer las actividades.
