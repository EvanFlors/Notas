# Ejemplo 01 — SBOM con syft / anchore/sbom-action

## Concepto que demuestra

Un workflow que construye una imagen Docker, genera un **SBOM** (Software Bill of Materials) en **CycloneDX** y **SPDX**, y lo publica como artifact del run. Es la pieza base de supply chain: sin SBOM no hay nada que atestar ni comparar.

## Contexto

Ver `theory/lesson.md` secciones 2.1 y 4.4 para la diferencia entre formatos y cuándo usar cada uno.

El SBOM responde a: *¿qué paquetes, versiones, licencias y hashes contiene esta imagen?* Lo genera `syft` (de Anchore), que soporta imágenes OCI, directorios, archivos individuales, y una lista larga de ecosistemas (apk, deb, rpm, npm, pip, maven, go.mod, cargo…).

## Archivos

- `workflow.yml` — a copiar en `.github/workflows/sbom.yml`.
- `Dockerfile.sample` — imagen de ejemplo pequeña para que el SBOM sea legible.

## Permisos requeridos

```yaml
permissions:
  contents: read      # checkout
  # Para solo generar SBOM y subirlo como artifact NO necesitas id-token ni attestations.
  # Esos permisos aparecen en el ejemplo 02 cuando añadimos attestation.
```

## Dos formas de generar el SBOM

**A) `anchore/sbom-action`** — wrapper oficial, upload automático como artifact:

```yaml
- uses: anchore/sbom-action@f325610c9f50a54015d37c8d16cb3b0e2c8f4de0  # v0.18.0
  with:
    image: localhost:5000/app:latest
    format: cyclonedx-json
    output-file: sbom.cdx.json
    upload-artifact: true
```

**B) `syft` directo** — más control, útil cuando quieres múltiples formatos:

```yaml
- uses: anchore/sbom-action/download-syft@f325610c9f50a54015d37c8d16cb3b0e2c8f4de0  # v0.18.0
- run: |
    syft -o cyclonedx-json=sbom.cdx.json -o spdx-json=sbom.spdx.json \
      localhost:5000/app:latest
- uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
  with:
    name: sboms
    path: sbom.*.json
```

## SBOM del directorio vs SBOM de la imagen

```bash
# SBOM del source tree (lo que escribiste tú)
syft dir:. -o cyclonedx-json=sbom-source.cdx.json

# SBOM de la imagen (lo que de verdad vas a correr; incluye deps del base image)
syft registry:ghcr.io/owner/app:v1.2.3 -o cyclonedx-json=sbom-image.cdx.json
```

**En CI casi siempre quieres el segundo.** El primero omite el runtime, la libc, el base image y todo lo que `apt-get install` metió en la imagen.

## Verificación local (sin GHA)

```bash
# Instala syft (macOS)
brew install syft

# Genera SBOM de una imagen pública
syft registry:alpine:3.19 -o cyclonedx-json | jq '.components | length'
# → algo como 15 paquetes

# Diff entre dos imágenes
syft registry:alpine:3.18 -o cyclonedx-json > sbom-18.json
syft registry:alpine:3.19 -o cyclonedx-json > sbom-19.json
diff <(jq -r '.components[] | "\(.name)@\(.version)"' sbom-18.json | sort) \
     <(jq -r '.components[] | "\(.name)@\(.version)"' sbom-19.json | sort)
```

## Interpretación

- **CycloneDX** → `components[]` con `name`, `version`, `purl`, `hashes[]`, `licenses[]`.
- **SPDX** → `packages[]` con `name`, `versionInfo`, `SPDXID`, `downloadLocation`, `licenseConcluded`.
- Ambos admiten `relationships[]` para expresar "A depende de B".

## Buenas prácticas

- Generar **ambos formatos** (CycloneDX + SPDX) si el consumidor downstream no está definido todavía.
- Guardar el SBOM como artifact del release además de attestarlo (`actions/attest-sbom`, ver ejemplo 02).
- Correr `syft` **sobre el digest** de la imagen, no sobre un tag mutable.

## Errores frecuentes

- `syft dir:.` cuando se quería la imagen → SBOM incompleto (sin runtime libs).
- Falta de red para pullear el base image → `syft` falla silenciosamente con lista parcial. Loguear `syft --verbose`.
- Subir SBOM a un repo público sin pensar: expone estructura interna de dependencias. En proyectos privados es trade-off razonable; evalúa.

## Referencia

- <https://github.com/anchore/syft>
- <https://github.com/anchore/sbom-action>
- <https://cyclonedx.org/>
- <https://spdx.dev/>
