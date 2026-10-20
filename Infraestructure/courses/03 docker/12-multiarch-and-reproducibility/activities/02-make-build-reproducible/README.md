# Actividad 02 — Hacer que dos builds consecutivos produzcan el mismo digest

## 1. Identificación

- **ID:** `dkr-12-02-make-build-reproducible`
- **Tecnología:** `docker`
- **Módulo:** `dkr-12-multiarch-and-reproducibility`
- **Dificultad:** advanced
- **Duración estimada:** 45–75 min
- **Tipo:** independent

## 2. Contexto

Te dan un `Dockerfile` que compila "bien" pero cada corrida genera un digest distinto. Tu trabajo es **diagnosticar** las fuentes de no-reproducibilidad y **arreglarlas**. La validación es dura: construye tu Dockerfile dos veces, exportando a OCI tarball con `rewrite-timestamp=true` y `SOURCE_DATE_EPOCH` fijo, y compara los `sha256sum`. Deben coincidir.

Esta actividad es *independent*: el README **no te dice** qué cambiar. Está todo en `theory/lesson.md` §9–11.

## 3. Objetivos

- Enumerar al menos tres causas de no-reproducibilidad en el Dockerfile de partida.
- Reescribirlo para eliminarlas sin cambiar la funcionalidad observable.
- Lograr `sha256sum(tarball_A) == sha256sum(tarball_B)`.

## 4. Prerrequisitos

- `docker buildx` ≥ 0.11 (soporte de `rewrite-timestamp`).
- Conexión para `pull` de la base.

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/docker/12-multiarch-and-reproducibility/activities/02-make-build-reproducible/starter/bootstrap.sh
# Crea /tmp/dkr-12-repro/app/Dockerfile (NO reproducible)
```

### 5.2 Reglas

- **No puedes cambiar** el nombre ni la ubicación del Dockerfile (`/tmp/dkr-12-repro/app/Dockerfile`).
- **Puedes agregar** archivos al mismo directorio (por ejemplo un lockfile).
- La imagen debe seguir sirviendo su propósito: `CMD` arranca y escribe algo a stdout (no tiene que ser idéntico al original, pero sí determinista).
- El validador construye con:
  ```
  docker buildx build --builder <bx> --provenance=false --sbom=false \
     --build-arg SOURCE_DATE_EPOCH \
     --output type=oci,dest=/tmp/dkr-12-repro/out-{a,b}.tar,rewrite-timestamp=true \
     /tmp/dkr-12-repro/app
  ```
  y compara los dos `sha256sum`.

### 5.3 Pistas abstractas

Lee la §9 de la lección (fuentes típicas de no-reproducibilidad). Pregúntate: *¿qué parte de este Dockerfile depende de "el momento del build" o de "la red hoy"?*

## 6. Resultado esperado

```
A: <sha256>  /tmp/dkr-12-repro/out-a.tar
B: <sha256>  /tmp/dkr-12-repro/out-b.tar
REPRODUCIBLE: sha256sum coincide.
```

## 7. Criterios de aceptación

- El Dockerfile sigue en `/tmp/dkr-12-repro/app/Dockerfile`.
- `docker buildx build` termina OK en las dos corridas.
- `sha256sum` de los dos tarballs OCI coinciden.

## 8. Validación

```bash
bash courses/docker/12-multiarch-and-reproducibility/activities/02-make-build-reproducible/tests/validate.sh
```

## 9. Preguntas de reflexión

- Enumera las causas de no-reproducibilidad del Dockerfile de partida. Para cada una, la corrección mínima.
- Si *solo* fijaras `SOURCE_DATE_EPOCH` sin tocar el Dockerfile, ¿bastaría? ¿Por qué no?
- ¿Qué perdiste al pasar `--provenance=false --sbom=false`? ¿Cómo lo recuperarías en CI real?
- Dos máquinas distintas corriendo tu solución: ¿darían el mismo digest? ¿Qué más tendrías que fijar?

## 10. Extensiones

- Añade una dep de Python con hash pin (`pip install --require-hashes -r requirements.txt`). Mantén la reproducibilidad.
- Prueba multi-arch: construye tu Dockerfile para `linux/amd64,linux/arm64` **con reproducibilidad** (dos corridas → mismo digest del índice).

## 11. Limpieza

```bash
docker buildx rm dkr12-repro 2>/dev/null || true
rm -rf /tmp/dkr-12-repro
```
