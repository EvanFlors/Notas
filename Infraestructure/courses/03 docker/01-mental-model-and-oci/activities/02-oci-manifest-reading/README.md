# Actividad 02 — Leer un manifest OCI real

## 1. Identificación

- **ID:** `dkr-01-02-oci-manifest-reading`
- **Tecnología:** `docker`
- **Módulo:** `dkr-01-mental-model-and-oci`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Un manifest OCI es solo JSON. Si no te intimida leer JSON con hashes dentro, no te intimidará nada del ecosistema contenedores.

Esta actividad te hace **inspeccionar un manifest** y escribir qué viste. Soporta dos modos:

- **Modo OFFLINE (default):** usas una muestra provista en `starter/sample-manifest.json`. No necesitas Docker ni red.
- **Modo DOCKER (opcional):** si tienes Docker instalado, obtienes un manifest real con `docker manifest inspect <image>` y trabajas sobre ese.

Ambos modos entregan el mismo `WRITEUP.md`. El validador no distingue.

## 3. Objetivos

Al terminar deberías poder:

- Identificar en un manifest OCI: `schemaVersion`, `mediaType`, `config.digest`, `config.size`, `layers[].digest`, `layers[].size`.
- Decir si el `mediaType` corresponde a un **manifest** o a un **manifest index** (multi-arch).
- Explicar la diferencia entre `layers[].digest` (tarball comprimido) y `rootfs.diff_ids` (contenido descomprimido).
- Explicar por qué un cambio de un byte en una capa cambia el digest del manifest completo.

## 4. Prerrequisitos

- Haber completado la actividad `01-draw-namespaces-and-cgroups/`.
- Haber recorrido `examples/02-oci-manifest-walkthrough/`.
- `python3` (para formatear JSON con `-m json.tool`).

**Opcional**: Docker instalado (modo DOCKER).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar directorio de trabajo

```bash
mkdir -p /tmp/dkr-01-manifest
cd /tmp/dkr-01-manifest
```

### 5.2 Obtener un manifest

#### Opción A — Modo OFFLINE (muestra provista)

```bash
cp <ruta-de-la-actividad>/starter/sample-manifest.json /tmp/dkr-01-manifest/manifest.json
```

(Reemplaza `<ruta-de-la-actividad>` por la ruta real de esta actividad en el repo.)

#### Opción B — Modo DOCKER (si tienes Docker instalado)

```bash
# Elegir una imagen pequeña. Alpine es ideal.
docker pull alpine:3.19

# Obtener el manifest. Nota: 'docker manifest inspect' puede necesitar
# 'experimental' habilitado en versiones viejas; en versiones modernas funciona directo.
docker manifest inspect alpine:3.19 > /tmp/dkr-01-manifest/manifest.json

# Si pullaste una variante multi-arch, verás un "manifest index". Entonces pide
# el manifest de UNA plataforma por su digest:
#   docker manifest inspect alpine:3.19@sha256:<digest-de-tu-arch>
```

### 5.3 Inspeccionar el manifest

```bash
cd /tmp/dkr-01-manifest
python3 -m json.tool manifest.json | less
# o:
cat manifest.json | python3 -m json.tool
```

Identifica:

- **`schemaVersion`** — ¿qué valor tiene?
- **`mediaType`** raíz — ¿es un `...manifest.v1+json` o un `...image.index.v1+json`?
- **`config.digest`, `config.size`, `config.mediaType`** — si existen (sólo en manifest, no en index).
- **`layers[]`** — cuántas capas, digest de cada una, tamaño total aproximado.
- **`manifests[]`** — si estás viendo un index: cuántas plataformas, cuáles.

### 5.4 Entregable: `WRITEUP.md`

Produce un archivo `WRITEUP.md` en `/tmp/dkr-01-manifest/` con exactamente estas **cuatro secciones**:

#### A. Metadata

```
Manifest obtenido de: <alpine:3.19 vía docker | sample provisto>
Modo: <OFFLINE | DOCKER>
schemaVersion: <N>
mediaType: <el string completo>
Tipo detectado: <manifest | manifest index>
```

#### B. Config

Solo si es manifest (no index). Si es un index, salta a §C y explica por qué.

```
config.mediaType: <...>
config.digest:    <sha256:...>
config.size:      <bytes>
```

#### C. Layers (o manifests, si es index)

Si es un manifest:

| # | mediaType | digest | size |
|---|-----------|--------|------|
| 0 | ... | sha256:... | ... |
| 1 | ... | sha256:... | ... |

Si es un manifest index:

| # | platform (os/arch) | digest | size |
|---|--------------------|--------|------|
| 0 | linux/amd64 | sha256:... | ... |
| 1 | linux/arm64 | sha256:... | ... |

#### D. Reflexión

Responde en 1 párrafo cada una (nombra los campos del JSON):

1. ¿Por qué el **`config`** no está incluido inline dentro del manifest sino referenciado por digest?
2. ¿Qué diferencia hay entre `layers[].digest` (que ves en el manifest) y `rootfs.diff_ids[]` (que verías en el **config** blob)? ¿Por qué OCI mantiene dos hashes distintos para "la misma capa"?
3. Si cambiara **un byte** del último blob de capa, ¿qué otros digests cambiarían en cascada? Enumera.
4. Si `cosign` firma esta imagen, ¿sobre qué digest se calcula la firma: sobre el tag (`alpine:3.19`), sobre el manifest, sobre el config, o sobre cada layer? Justifica.

### 5.5 Validar

```bash
bash <ruta-de-la-actividad>/tests/validate.sh /tmp/dkr-01-manifest
```

Chequea que `WRITEUP.md` existe, menciona `schemaVersion`, `mediaType`, los campos clave, incluye al menos un `sha256:` y responde las 4 preguntas de §D.

## 6. Resultado esperado

- `WRITEUP.md` con las 4 secciones A/B/C/D.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/WRITEUP-reference.md`.

## 7. Criterios de aceptación

- [ ] `manifest.json` presente en `/tmp/dkr-01-manifest/`.
- [ ] `WRITEUP.md` incluye `schemaVersion` y el string completo del `mediaType`.
- [ ] Al menos un `sha256:` real citado del manifest.
- [ ] Diferencia `layers[].digest` vs `rootfs.diff_ids` explicada.
- [ ] Las 4 preguntas de §D respondidas (numeradas 1., 2., 3., 4.).

## 8. Validación

```bash
bash tests/validate.sh /tmp/dkr-01-manifest
```

Estructural. **Semántica** la calibras tú con `solution/WRITEUP-reference.md`.

## 9. Preguntas de reflexión (opcional)

1. Un registry OCI (distribution-spec) te permite pedir un manifest por **tag** o por **digest**. ¿Cuál usarías en producción y por qué?
2. ¿Qué pasa si pullas la misma imagen `alpine:3.19` desde dos máquinas distintas en dos momentos distintos? ¿Puedes garantizar que recibes los mismos bytes?
3. Si Docker Hub desapareciera mañana, ¿sería difícil mover tus imágenes a GHCR? ¿Qué piezas del formato OCI lo hacen fácil?

## 10. Extensiones (opcional)

- **E1** — Usa `curl` directo contra `registry-1.docker.io` para pullar un manifest sin Docker. Pista: necesitas un bearer token anónimo de `auth.docker.io`. Ver `theory/lesson.md` §5.
- **E2** — Si tienes Docker, descarga el config blob referenciado por `config.digest` con `docker image inspect <image>` y confirma que su hash coincide (`sha256sum` sobre el contenido canónico).
- **E3** — Compara el manifest de `alpine:3.19` con el de `alpine:latest`. ¿Son iguales? ¿Cuándo lo serían?

## 11. Limpieza

```bash
rm -rf /tmp/dkr-01-manifest
# Si pullaste la imagen con Docker y no la quieres:
# docker rmi alpine:3.19
```
