# Actividad 01 — Publicar `app:v1` para `linux/amd64` y `linux/arm64`

## 1. Identificación

- **ID:** `dkr-12-01-publish-amd64-arm64`
- **Tecnología:** `docker`
- **Módulo:** `dkr-12-multiarch-and-reproducibility`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a publicar una imagen `app:v1` como **manifest index** que contenga variantes `linux/amd64` y `linux/arm64`. La actividad soporta **dos modos**:

- **`MODE=local`** (default): empuja a un `registry:2` corriendo en `127.0.0.1:5050`. Útil en CI del curso o sin cuenta GHCR.
- **`MODE=live`**: empuja a `ghcr.io/<owner>/dkr-12-app:v1`. Requiere `gh auth status` OK (o `GHCR_TOKEN`) y un `GHCR_OWNER`.

Ambos modos validan **lo mismo**: que `docker buildx imagetools inspect <ref>` muestra entradas para `linux/amd64` **y** `linux/arm64` bajo un `MediaType` de image index.

## 3. Objetivos

Al terminar:

- Creas un builder `docker-container` operativo y verificas sus plataformas.
- Construyes y publicas `app:v1` para ambas plataformas en una sola invocación `buildx build --platform linux/amd64,linux/arm64 --push`.
- Verificas con `imagetools inspect`.

## 4. Prerrequisitos

- Docker Desktop reciente o Docker Engine ≥ 24 con `buildx`.
- En Linux puro: `docker run --privileged --rm tonistiigi/binfmt --install all` (Docker Desktop ya lo trae).
- Modo `live`: `gh` autenticado o `GHCR_TOKEN`; variable `GHCR_OWNER=<tu-usuario>`.
- Costo: $0 (registry local gratis; GHCR gratis para repos públicos).

## 5. Instrucciones

### 5.1 Bootstrap

```bash
# Modo local (default): levanta registry:2 en 127.0.0.1:5050 y crea /tmp/dkr-12-publish/
bash courses/docker/12-multiarch-and-reproducibility/activities/01-publish-amd64-arm64/starter/bootstrap.sh

# Modo live: igual, pero exporta tu owner
MODE=live GHCR_OWNER=<tu-user> bash .../starter/bootstrap.sh
```

El bootstrap crea `/tmp/dkr-12-publish/app/` con un `Dockerfile` **placeholder** mono-arch que aún no cumple los criterios.

### 5.2 Lo que tienes que hacer

1. Entra a `/tmp/dkr-12-publish/app/`.
2. Edita el `Dockerfile` para que la imagen sea útil y pequeña (base `alpine:3.20` o similar). No es el punto crítico — el crítico es *cómo la construyes*.
3. **Crea el builder** con driver `docker-container`. Si vas a usar el registry local
   (`MODE=local`) necesitas `--driver-opt network=host` para que BuildKit (que vive en
   un contenedor) pueda alcanzar `127.0.0.1:5050`:
   ```bash
   docker buildx create --name dkr12 --driver docker-container \
     --driver-opt network=host --use
   docker buildx inspect --bootstrap dkr12
   ```
4. **Construye y empuja** para dos plataformas:
   ```bash
   # MODE=local:
   docker buildx build --platform linux/amd64,linux/arm64 \
     -t 127.0.0.1:5050/dkr-12-app:v1 --push /tmp/dkr-12-publish/app

   # MODE=live:
   docker buildx build --platform linux/amd64,linux/arm64 \
     -t ghcr.io/<owner>/dkr-12-app:v1 --push /tmp/dkr-12-publish/app
   ```
5. Valida:
   ```bash
   bash courses/docker/12-multiarch-and-reproducibility/activities/01-publish-amd64-arm64/tests/validate.sh
   ```

## 6. Resultado esperado

- `docker buildx imagetools inspect <ref>` muestra un `MediaType: application/vnd.oci.image.index.v1+json` y bajo `Manifests:` dos entradas con `Platform: linux/amd64` y `Platform: linux/arm64`.

## 7. Criterios de aceptación

- La imagen fue empujada (el registry responde con 200 al pedirla).
- El objeto bajo el tag es un **image index** (no un manifest mono-arch).
- Ambas plataformas (`linux/amd64`, `linux/arm64`) aparecen bajo `Manifests:`.

## 8. Validación

```bash
bash .../tests/validate.sh         # MODE=local (default)
MODE=live GHCR_OWNER=<owner> bash .../tests/validate.sh
```

Salida esperada en verde:

```
== Validating dkr-12-01-publish-amd64-arm64 (local) ==
  OK   -- builder dkr12 con driver docker-container
  OK   -- registry local responde en 127.0.0.1:5050
  OK   -- tag 127.0.0.1:5050/dkr-12-app:v1 presente
  OK   -- MediaType = OCI image index
  OK   -- plataforma linux/amd64 presente
  OK   -- plataforma linux/arm64 presente

PASS (6/6)
```

## 9. Preguntas de reflexión

- ¿Por qué el driver `docker` por default no funciona para `--push` multi-arch?
- ¿Qué pasa si corres `docker pull 127.0.0.1:5050/dkr-12-app:v1` en este mismo host?
- Si tu CI tiene un runner `amd64` y uno `arm64` nativos, ¿cómo cambiarías este flujo?
- ¿Qué diferencia habría en el tiempo de build si forzaras `--platform linux/arm64` sobre un host amd64 sin QEMU disponible?

## 10. Extensiones

- Añade `linux/arm/v7` a la lista de plataformas. ¿Cuál base image deja de soportar?
- Haz dos builds separados (uno por arch, cada uno `--push`) y combina los manifests con `docker buildx imagetools create -t … <ref-amd64> <ref-arm64>`. Compara con el flujo "todo-en-uno".

## 11. Limpieza

```bash
docker rm -f dkr12-registry 2>/dev/null || true
docker buildx rm dkr12 2>/dev/null || true
rm -rf /tmp/dkr-12-publish
```
