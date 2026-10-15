# Ejemplo 02 — Pin por digest

## Concepto que demuestra

Por qué referenciar una imagen por **digest** (`name@sha256:...`) es cualitativamente distinto a referenciarla por **tag** (`name:v1`): el digest es inmutable, el tag no.

El ejemplo levanta un `registry:2` local, publica *dos builds distintos* al mismo tag `v1`, y muestra:

1. Que el tag `v1` cambia de digest entre pushes.
2. Que cada digest individual sigue siendo pulleado idéntico aunque el tag haya migrado.
3. Que un `FROM localhost:5000/evan/base:v1` en otro Dockerfile es *implícitamente* no-reproducible, mientras que `FROM localhost:5000/evan/base@sha256:...` sí lo es.

## Objetivo

Al terminar podrás responder:
- Dado un tag y dos pushes al mismo tag, ¿qué garantiza el digest y qué no garantiza el tag?
- ¿Qué significa "pin by digest" para un `Dockerfile` base y para un deploy?
- ¿Cómo resuelvo el digest desde la CLI sin consultar la UI del registry?

## Archivos del ejemplo

```
files/
├── Dockerfile.v1a       # produce manifest A
├── Dockerfile.v1b       # produce manifest B (misma imagen, un byte distinto)
└── run-local.sh         # drive del ejercicio completo contra localhost:5000
```

## Prerrequisitos

- Docker Engine corriendo.
- Puerto `5000` libre (o export `REGISTRY_PORT=5001`).

## Ejecución

```bash
cd courses/docker/09-registries-tags-and-digests/examples/02-pin-by-digest/files
bash run-local.sh
```

El script:

1. Levanta `registry:2` en `localhost:${REGISTRY_PORT:-5000}` (o reusa el ya corriendo).
2. Construye y pushea `Dockerfile.v1a` como `localhost:5000/evan/base:v1`. Captura `DIGEST_A`.
3. Construye y pushea `Dockerfile.v1b` como `localhost:5000/evan/base:v1`. Captura `DIGEST_B`.
4. Verifica que `DIGEST_A != DIGEST_B` (el tag se re-apuntó).
5. Pullea `base@DIGEST_A` y `base@DIGEST_B` y confirma que son objetos distintos.
6. Reporta los dos digests y el tag actual.

Salida esperada (abreviada):

```
== dkr-09 example 02: pin by digest ==
PUSH #1 as :v1 → DIGEST_A = localhost:5000/evan/base@sha256:aaaa...
PUSH #2 as :v1 → DIGEST_B = localhost:5000/evan/base@sha256:bbbb...
tag v1 ahora apunta a: sha256:bbbb...
DIGEST_A != DIGEST_B  — el tag migro; cada digest sigue siendo inmutable.
```

## Interpretación

- **El tag es un alias mutable**. Dos `docker push ...:v1` consecutivos reescriben el mapping `v1 → <digest>`. El viejo digest *puede* seguir en el registry (hasta que un GC lo barra), pero ya no está apuntado por `:v1`.
- **El digest es inmutable**. `base@sha256:aaaa...` siempre pulleará esos mismos bytes (o 404 si fueron eliminados).
- Si un `Dockerfile` dice `FROM base:v1`, dos builds en días distintos pueden traer bases distintas → artefactos distintos. Si dice `FROM base@sha256:aaaa...`, el resultado es idéntico en bytes mientras los blobs existan.
- Esto es *exactamente* el problema de `FROM python:3-slim` sin pinnear digest: cualquier rebuild de la imagen oficial (hay varios al día) cambia el digest sin que el tag se mueva *visiblemente* para ti.

## Trade-offs del pin por digest

Pros: reproducibilidad, auditoría (sabes exactamente qué bits usaste), supply chain verificable (puedes firmar/attestar por digest).

Contras:
- Pierdes updates automáticos (incluidos parches de seguridad). Necesitas un proceso para **rotar digests** vía PR (Renovate, Dependabot).
- `FROM base@sha256:...` es ilegible; usa un comentario con la versión semver cercana para humanos.

## Errores frecuentes

- **"Mi tag `latest` cambió y no entiendo cuándo"** — alguien o algún CI pusheó. En registries con *immutable tags* activo, al menos `vX.Y.Z` no se puede reescribir; `latest` por diseño sí.
- **Pulleas por digest pero `docker inspect` muestra el ID local, no el digest** — correcto; `Id` es la config local, `RepoDigests` es lo que apuntaste en el registry.
- **El digest de la primera build desaparece sin aviso** — el registry corrió garbage collect, u otro tag/manifest ya no lo referenciaba. En producción, `vX.Y.Z` + immutable tags evita esto.

## Limpieza

```bash
docker stop dkr09-registry 2>/dev/null || true
docker rmi localhost:5000/evan/base:v1 2>/dev/null || true
```
