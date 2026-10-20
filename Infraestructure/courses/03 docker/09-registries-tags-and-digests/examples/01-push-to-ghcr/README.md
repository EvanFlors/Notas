# Ejemplo 01 — Login, tag y push (dual-mode)

## Concepto que demuestra

El ciclo completo **build → tag → login → push** contra un registry OCI, usando dos modos:

- `MODE=local` (default): levanta un `registry:2` propio en `localhost:5000` (sin autenticación — el image oficial lo permite así por diseño para dev).
- `MODE=live`: publica a **GHCR** (`ghcr.io/<owner>/dkr-09-example`) autenticándote con un `gh auth token`.

Ambos modos ejercitan los mismos conceptos (`docker tag` con nombre completo, `docker push`, inspección de digest). La diferencia es contra qué registry hablas.

## Objetivo

Al terminar podrás responder:
- ¿Qué formato tiene el nombre completo de una imagen en un registry?
- ¿Qué pasa paso a paso en un `docker push`?
- ¿Cuál es el **digest** canónico de una imagen y de dónde se lee?
- ¿Qué cambia (y qué no) entre pushear a un registry local y a GHCR?

## Archivos del ejemplo

```
files/
├── Dockerfile         # imagen trivial que imprime un timestamp
├── app.sh             # script de demo
└── run-local.sh       # drive del ciclo completo contra localhost:5000
```

## Prerrequisitos

- Docker Engine corriendo (`docker ps` no debe fallar).
- Puerto `5000` libre en el host (si no, exporta `REGISTRY_PORT=5001`).
- **Modo `live` (opcional)**: `gh` autenticado (`gh auth status`) y un repo tuyo en GitHub con `packages: write`.

## Ejecución — MODE=local (default)

```bash
cd courses/docker/09-registries-tags-and-digests/examples/01-push-to-ghcr/files
bash run-local.sh
```

El script hace, en orden:

1. Si no corre, levanta `docker run -d --rm --name dkr09-registry -p 5000:5000 registry:2`.
2. Construye la imagen local `dkr09-demo:dev` desde el `Dockerfile`.
3. Taggea como `localhost:5000/evan/dkr09-demo:v1.0.0` y como `:latest`.
4. `docker push` de ambos tags.
5. Resuelve el **digest** canónico con `docker inspect --format '{{index .RepoDigests 0}}'`.
6. Pullea por digest y confirma que el ID local corresponde.
7. Imprime un reporte y deja el registry corriendo (para que puedas experimentar). Para limpiarlo: `docker stop dkr09-registry`.

Salida esperada (abreviada):

```
== dkr-09 example 01: push to local registry ==
+ docker run -d --rm --name dkr09-registry -p 5000:5000 registry:2
+ docker build -t dkr09-demo:dev .
+ docker tag dkr09-demo:dev localhost:5000/evan/dkr09-demo:v1.0.0
+ docker push localhost:5000/evan/dkr09-demo:v1.0.0
...
DIGEST: localhost:5000/evan/dkr09-demo@sha256:<64 hex>
+ docker pull localhost:5000/evan/dkr09-demo@sha256:<64 hex>
OK — tag y digest apuntan al mismo manifest
```

## Ejecución — MODE=live (opcional, publica a GHCR)

```bash
# requiere: gh auth status OK, con scope write:packages
export OWNER=$(gh api user -q .login)
MODE=live bash run-local.sh
```

En este modo el script:

1. Verifica `gh auth status`.
2. `docker login ghcr.io -u "$OWNER" --password-stdin` usando `gh auth token`.
3. Construye y taggea como `ghcr.io/$OWNER/dkr09-demo:v1.0.0` y `:latest`.
4. Pushea.
5. Lee el digest y muestra la URL `https://github.com/$OWNER?tab=packages` para que lo veas en la UI.

## Interpretación

- El nombre `localhost:5000/evan/dkr09-demo:v1.0.0` tiene cuatro partes: **host** (`localhost:5000`), **namespace** (`evan`), **repo** (`dkr09-demo`), **ref** (`:v1.0.0`).
- `docker push` sube **capas** (dedup por digest) + **config** + **manifest**. El registry responde con `Docker-Content-Digest: sha256:...` que es el digest canónico de la imagen.
- `RepoDigests` en `docker inspect` es `<registry/name>@sha256:...`. Ese es el string que debes pinnear en producción.
- El `registry:2` que levantas localmente **no tiene auth** por default; es apropiado para dev y para este ejercicio, nunca para producción.

## Errores frecuentes

- **`Get "https://localhost:5000/v2/": http: server gave HTTP response to HTTPS client`** — Docker Desktop en algunas versiones intenta HTTPS a `localhost`. Normalmente `localhost:5000` está en la lista de "insecure registries" por default; si no, agrégalo en `Settings → Docker Engine`.
- **`port is already allocated`** — algo escucha en `:5000`. Exporta `REGISTRY_PORT=5001` y re-ejecuta (el script lo respeta).
- **`unauthorized: authentication required`** (modo live) — tu token no tiene scope `write:packages`. Re-genera: `gh auth refresh -s write:packages`.
- **`denied: permission_denied: write_package` (GHCR)** — el repo del paquete está asociado a otro usuario/org. Verifica `OWNER`.

## Limpieza

```bash
# Local
docker stop dkr09-registry 2>/dev/null || true
docker rmi dkr09-demo:dev localhost:5000/evan/dkr09-demo:v1.0.0 localhost:5000/evan/dkr09-demo:latest 2>/dev/null || true

# Live (GHCR): borrar el package desde la UI o con gh api
# gh api -X DELETE /user/packages/container/dkr09-demo
```
