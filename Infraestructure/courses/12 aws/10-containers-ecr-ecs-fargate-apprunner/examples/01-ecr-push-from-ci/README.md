# Ejemplo 01 — Build + push a un registry OCI (stand-in de ECR)

Simula el flujo que un pipeline de CI ejecuta contra ECR, **sin** AWS real: construye una imagen FastAPI minimal y la empuja a un **`registry:2` local** escuchando en `127.0.0.1:5000`. La semantica del `docker push` es identica a ECR; lo unico que cambia es que no hace falta `aws ecr get-login-password` en local.

## Requisitos

- Docker daemon corriendo.
- Puerto `5000` libre.
- `curl` y `jq`.

## Correr

```bash
cd "$(dirname "$0")"
bash run.sh
```

El script:

1. Verifica deps y hace `SKIP` limpio si faltan.
2. Levanta `registry:2` en `127.0.0.1:5000` (contenedor efimero).
3. Construye la imagen `aws10-fastapi-demo:local` desde el `Dockerfile` del directorio.
4. La re-tagea como `127.0.0.1:5000/aws10-fastapi-demo:v1` y hace `docker push`.
5. Interroga el catalogo del registry (`/v2/_catalog`) y la lista de tags.
6. Limpia: para el registry, borra el contenedor y las imagenes locales de la demo.

## Que observar

- `docker build` produce las layers; `docker push` sube cada layer una sola vez (siguientes pushes con cambios menores reusan el cache por digest).
- `curl -s 127.0.0.1:5000/v2/_catalog` lista `aws10-fastapi-demo`; el `/tags/list` lista `v1`.
- El flujo ECR real anadiria un paso previo: `aws ecr get-login-password | docker login ...`.

## Mapeo mental a ECR real

| Local | ECR |
|-------|-----|
| `127.0.0.1:5000` | `ACCOUNT.dkr.ecr.REGION.amazonaws.com` |
| sin login | `docker login` con token de 12 h |
| `/v2/_catalog` | `aws ecr describe-repositories` |
| `/v2/<repo>/tags/list` | `aws ecr list-images --repository-name <repo>` |
| scan on push (no hay) | `aws ecr describe-image-scan-findings` |

## Coste

Cero. Todo corre localmente.
