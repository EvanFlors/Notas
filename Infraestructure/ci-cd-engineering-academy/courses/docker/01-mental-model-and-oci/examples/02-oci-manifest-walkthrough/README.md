# Ejemplo 02 — Walkthrough de un manifest OCI real

## Concepto que demuestra

Qué contiene exactamente un manifest OCI y su image config asociado. Todo es **JSON + hashes** — no hay magia, no hay formato binario propietario.

## Contexto

En `theory/lesson.md` §4.5 vimos la *descripción* de las specs. Aquí lo tocas: un manifest y un config reales capturados en `files/`. Puedes leerlos sin Docker.

## Objetivo

Al terminar, podrás:

- Nombrar y señalar en el JSON: `schemaVersion`, `mediaType`, `config.digest`, `layers[].digest`, `layers[].size`.
- Explicar por qué el `config` también está "fuera" del manifest (apunta a él por digest).
- Leer `rootfs.diff_ids` del config y relacionarlos con `layers[]` del manifest.
- Explicar qué significa que el image config tenga `history[]`.

## Prerrequisitos

- Haber leído §4.5 de `theory/lesson.md`.
- Un editor para abrir JSON (o `python3 -m json.tool`).

## Archivos

- **`files/manifest.json`** — un manifest OCI (image-spec v1) para una app FastAPI de ejemplo.
- **`files/config.json`** — el *image config* al que apunta `manifest.json → config.digest`.

Son archivos **de ejemplo** (ligeramente simplificados). Si tienes Docker, puedes obtener uno real de cualquier imagen con:

```bash
# Requiere Docker instalado (opcional):
docker pull python:3.12-slim
docker manifest inspect python:3.12-slim
# o para el config:
docker image inspect python:3.12-slim
```

## Ejecución

1. **Abre `files/manifest.json`** y lee de arriba a abajo. No pases a 2 hasta identificar cada campo del listado de "Objetivo".

2. **Identifica el `mediaType` raíz**:

   ```
   "mediaType": "application/vnd.oci.image.manifest.v1+json"
   ```

   Esto dice: "soy un manifest de imagen OCI mono-arquitectura v1". Si fuera `application/vnd.oci.image.index.v1+json`, sería un **manifest index** multi-arch (una lista de manifests, uno por plataforma).

3. **Mira `config`**:

   ```json
   "config": {
     "mediaType": "application/vnd.oci.image.config.v1+json",
     "digest": "sha256:c5b1261d...",
     "size": 1472
   }
   ```

   El manifest NO contiene el config inline. Contiene un **puntero por digest** al blob del config. El digest es el `sha256` del contenido del config.json: si cambia **una coma** del config, el digest cambia y por tanto el manifest cambia. Content-addressable, igual que Git.

4. **Mira `layers[]`**:

   ```json
   "layers": [
     { "mediaType": ".../tar+gzip", "digest": "sha256:4abcf206...", "size": 3401967 },
     { "mediaType": ".../tar+gzip", "digest": "sha256:9f13f5a5...", "size": 1073 },
     { "mediaType": ".../tar+gzip", "digest": "sha256:3a1b8d1f...", "size": 24518 }
   ]
   ```

   Tres capas, en orden de aplicación. La primera (3.4 MB) es típicamente la base distro (`python:3.12-slim`), la segunda (1 KB) un ajuste pequeño, la tercera (24 KB) la app. El orden importa: overlayfs las aplica de abajo hacia arriba.

5. **Mira `annotations`** — metadata OCI estándar: fecha, repo fuente, revisión git, versión, licencia. No afectan la ejecución, pero son clave para supply chain / cumplimiento.

6. **Abre `files/config.json`** — este es *el blob* al que apunta `config.digest`. Contiene:

   - **`created`** — fecha de creación.
   - **`architecture`, `os`** — plataforma objetivo.
   - **`config`** — qué ejecutar al arrancar el contenedor (`User`, `Env`, `Entrypoint`, `Cmd`, `WorkingDir`, `ExposedPorts`, `Labels`, `StopSignal`). Es la "runtime recipe" por defecto; el runtime puede sobre-escribir casi todo.
   - **`rootfs.diff_ids`** — hashes de las capas **descomprimidas**. Fíjate que son **distintos** a los digests del manifest: los del manifest son del tarball **comprimido** (lo que viaja por la red); los del config son del contenido descomprimido (lo que overlayfs ve en disco). Esto permite al runtime verificar integridad en ambas etapas.
   - **`history[]`** — línea del tiempo de cómo se construyó la imagen. Cada entrada corresponde a una instrucción del Dockerfile. Se ve con `docker history <image>`.

7. **Correlaciona manifest ↔ config**:

   ```
   manifest.json
     config.digest: sha256:c5b1261d...   ─────┐
     layers[0].digest: sha256:4abcf206...     │
     layers[1].digest: sha256:9f13f5a5...     │
     layers[2].digest: sha256:3a1b8d1f...     │
                                              │
                                              ▼
                                    (apunta a este blob)
                                              │
                                              ▼
   config.json
     rootfs.diff_ids[0]: sha256:1d6a1d5f...   (descomprimido de layers[0])
     rootfs.diff_ids[1]: sha256:2e7b2e6a...   (descomprimido de layers[1])
     rootfs.diff_ids[2]: sha256:3f8c3f7b...   (descomprimido de layers[2])
     config:
       User:       10001:10001
       Entrypoint: [python, -m, uvicorn]
       Cmd:        [app.main:app, --host, 0.0.0.0, --port, 8080]
       WorkingDir: /app
   ```

## Resultado esperado

Después del walkthrough deberías poder:

- Dibujar la relación `manifest → config → layers` con flechas y hashes.
- Explicar la diferencia entre `layers[].digest` (comprimido) y `rootfs.diff_ids[]` (descomprimido).
- Explicar por qué un cambio **en una sola capa** fuerza un digest nuevo en todo lo que la apunta (manifest, index si existe).

## Interpretación

- Un manifest OCI es **la lista de ingredientes**; el runtime descarga cada blob referenciado por digest.
- Es **inmutable** por construcción: si cambia un byte, el digest cambia.
- Los **tags** (como `:latest`) no viven en el manifest — viven en el registry como *alias mutables* a un digest. Un tag puede re-apuntar a otro digest con el tiempo; un digest, no.
- **La imagen "funciona" offline** si tienes el manifest, el config y los blobs de las capas. Son todo lo que hace falta.

## Errores frecuentes

- **Confundir `manifest` con `image index`**: el index multi-arch tiene `manifests[]` (lista de manifests por plataforma); el manifest "normal" tiene `layers[]`. Mira el `mediaType`.
- **Pensar que el config vive dentro del manifest**: no. El manifest tiene un **puntero** (`digest`) al config. El config es un blob separado en el registry.
- **Pensar que `layers[].digest` y `rootfs.diff_ids[]` deben coincidir**: no coinciden; unos son del tarball comprimido, otros del contenido descomprimido. Son dos verificaciones de integridad distintas.
- **Pensar que un tag es un identificador estable**: `:latest` puede re-apuntar. En producción referenciar por `image@sha256:...` (ver `dkr-09`).

## Relación con escenarios reales

- **Firmas con cosign** se publican como artefactos OCI asociados al digest del manifest. Verificas la firma contra el digest, no contra el tag.
- **SBOM con syft** se puede empaquetar como un attestation OCI referido al digest.
- **Mirroring entre registries** (`skopeo copy`) transfiere manifest + blobs; el digest final es el mismo en origen y destino porque es solo content-addressable.
- **Un ataque de supply chain** tiene que afectar al **digest** del manifest o de alguna capa; verificarlo end-to-end (SLSA provenance) es el objetivo de `dkr-14`.

## Limpieza

Nada que limpiar — todo son archivos de lectura dentro del repo.
