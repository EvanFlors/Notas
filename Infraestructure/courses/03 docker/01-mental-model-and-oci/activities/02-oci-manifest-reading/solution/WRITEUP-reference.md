# WRITEUP (reference) — dkr-01-02

> Autoevaluación. Esta es la respuesta esperada para la **muestra provista**
> en `starter/sample-manifest.json`. Si usaste modo DOCKER con `alpine:3.19`,
> los digests concretos cambiarán, pero la estructura y las respuestas son
> análogas.

## A. Metadata

```
Manifest obtenido de: starter/sample-manifest.json (ejemplo didáctico)
Modo: OFFLINE
schemaVersion: 2
mediaType: application/vnd.oci.image.manifest.v1+json
Tipo detectado: manifest (mono-arquitectura; NO es un image index)
```

## B. Config

```
config.mediaType: application/vnd.oci.image.config.v1+json
config.digest:    sha256:4a5c3e7f9b2d1e8f6a7c8d9e0b1a2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b
config.size:      1456
```

El `config` es un blob separado en el registry. El manifest apunta a él por digest + size + mediaType. Al pullar la imagen, el cliente descarga ese blob y verifica que `sha256(contenido) == config.digest` antes de usarlo.

## C. Layers

| # | mediaType | digest | size |
|---|-----------|--------|------|
| 0 | application/vnd.oci.image.layer.v1.tar+gzip | sha256:9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b | 3401967 |
| 1 | application/vnd.oci.image.layer.v1.tar+gzip | sha256:1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c | 1073 |
| 2 | application/vnd.oci.image.layer.v1.tar+gzip | sha256:2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d | 24518 |

Total aproximado: ≈ 3.4 MB (dominado por la capa 0, típica para una base distro mínima).

## D. Reflexión

1. **¿Por qué el `config` está referenciado por digest y no inline?** Separar el config del manifest permite que varios manifests (p. ej. multi-arch) compartan configs equivalentes como blobs independientes; permite al cliente verificar su integridad por `sha256` antes de usarlo; mantiene el manifest pequeño (fácil de cachear y firmar); y encaja con la **distribution-spec**, que trata cualquier blob (config, layer, firmas) de la misma forma uniforme.

2. **`layers[].digest` vs `rootfs.diff_ids`**: `layers[].digest` es el `sha256` del **tarball COMPRIMIDO** (lo que viaja por la red y se cachea en disco local). `rootfs.diff_ids[]` (dentro del config blob) es el `sha256` del **contenido DESCOMPRIMIDO** de cada capa (lo que overlayfs monta). OCI mantiene ambos porque son dos verificaciones de integridad distintas: el runtime verifica el tar comprimido al bajarlo, y luego verifica el contenido descomprimido antes de aplicarlo. Permite detectar corrupción tanto en transporte como en storage.

3. **Si cambia un byte del último blob de capa**: cambia `sha256(blob)` → cambia `layers[2].digest` del manifest → cambia `sha256(manifest.json)` → cambia el digest del manifest. Si el config incluye `rootfs.diff_ids[2]` (del contenido descomprimido), también cambia → cambia `config.digest` → doble razón por la que el manifest cambia. Si existía un **manifest index** apuntando a este manifest, su entrada también cambia → cambia el `sha256(index.json)`. Y si había una **firma cosign** sobre el manifest o el index, queda inválida — hay que re-firmar. Encadenamiento content-addressable completo.

4. **cosign** firma sobre **el digest del manifest** (o del index, en multi-arch), no sobre el tag ni sobre layers individuales. El tag es un alias mutable (no es inmutable, no se puede firmar lo mutable con sentido); los layers por separado no identifican la imagen completa; el manifest sí es la "unidad de identidad" inmutable de la imagen. Por eso en verificaciones vemos `cosign verify ghcr.io/org/app@sha256:...` — sobre el digest.
