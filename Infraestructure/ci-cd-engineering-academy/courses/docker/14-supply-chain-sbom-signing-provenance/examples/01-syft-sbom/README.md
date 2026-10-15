# Ejemplo 01 — SBOM con syft (CycloneDX + SPDX)

## Concepto que demuestra

Generar un **SBOM** (Software Bill of Materials) desde una imagen OCI local con `syft`, en los dos formatos estándar (**CycloneDX** y **SPDX**), y leer el resultado para entender qué contiene.

## Contexto

Un SBOM es un inventario firmado-firmable del contenido de la imagen: paquetes del sistema (apk/dpkg/rpm), paquetes de lenguaje (pip, npm, go, cargo), binarios ELF, licencias y hashes. `syft` lo produce aplicando catalogadores sobre las capas de la imagen (ver `theory/lesson.md` §4.1).

CycloneDX está orientado a security (consumible por Trivy, Grype, Dependency-Track, VEX). SPDX está orientado a compliance de licencias (NTIA, FOSSology). El contenido conceptual es equivalente; cambia la gramática.

## Archivos

- `Dockerfile.sample` — imagen Alpine pequeña con un par de paquetes para que el SBOM sea legible.
- `run.sh` — build + SBOM en los dos formatos; detecta herramientas faltantes y salta.

## Ejecución

```bash
bash run.sh                 # usa /tmp/dkr-14-ex01 por default
bash run.sh /tmp/mi-sbom    # directorio alterno
```

Salida esperada (si `syft` está instalado):

```
BUILD: localhost:5000/sbom-demo:v1 (si registry local corriendo) o solo local
SBOM CycloneDX: /tmp/dkr-14-ex01/sbom.cdx.json
  Components: 42
SBOM SPDX:      /tmp/dkr-14-ex01/sbom.spdx.json
  Packages:   42
```

Si `syft` no está instalado, el script imprime el comando de instalación y sale 0 (demo documental).

## Qué mirar en el output

### CycloneDX

```bash
jq '.components[0]' /tmp/dkr-14-ex01/sbom.cdx.json
jq '.components | length' /tmp/dkr-14-ex01/sbom.cdx.json
jq '[.components[] | .licenses // [] | .[]] | unique' /tmp/dkr-14-ex01/sbom.cdx.json
```

Cada componente tiene `purl` (Package URL), `name`, `version`, `hashes` y, cuando syft lo encuentra, `licenses`.

### SPDX

```bash
jq '.packages[0]' /tmp/dkr-14-ex01/sbom.spdx.json
jq '.packages | length' /tmp/dkr-14-ex01/sbom.spdx.json
```

## Lectura dirigida

1. ¿Cuántos paquetes de **sistema** (apk) hay vs paquetes de **lenguaje**? Filtra por `purl` prefix (`pkg:apk/` vs `pkg:pypi/`).
2. ¿Qué componente **no tiene licencia**? Suele ser el síntoma de un binario copiado sin metadata.
3. ¿Qué pasa si cambias `Dockerfile.sample` para añadir `pip install requests`? Rebuild y vuelve a correr. El SBOM crece con los `pkg:pypi/*`.

## Limpieza

```bash
rm -rf /tmp/dkr-14-ex01
docker image rm localhost:5000/sbom-demo:v1 2>/dev/null || true
```

## Referencias

- `theory/lesson.md` §2.2 (qué afirma un SBOM), §4.1 (qué hace syft).
- `resources/links.md` → syft, CycloneDX, SPDX.
