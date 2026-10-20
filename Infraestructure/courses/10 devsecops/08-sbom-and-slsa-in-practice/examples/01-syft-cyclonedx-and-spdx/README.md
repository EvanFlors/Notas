# Ejemplo 01 — Syft: CycloneDX, SPDX y consumo con Grype

> **Runnable** si tienes `syft` y `grype` instalados. Hace **skip graceful** si faltan. Opcional: `docker` para probar también sobre una imagen.

## Objetivo

Ver con tus manos las dos salidas de `syft` (CycloneDX JSON y SPDX JSON) sobre un mismo input y luego consumir el SBOM con `grype` para generar un reporte de vulnerabilidades.

## Qué hace el script

`run.sh`:

1. Verifica que `syft` y `grype` estén en PATH; si no, imprime instrucciones y sale 0 (skip).
2. Crea un scratch dir `/tmp/sec-08-syft-demo` y una mini-app Python con `requirements.txt` que pin'ea versiones **viejas** a propósito (para que Grype encuentre CVEs reales conocidos).
3. Genera **source SBOM** en CycloneDX JSON y en SPDX JSON desde el directorio.
4. (Si hay `docker`) construye una imagen Alpine mínima y genera **build SBOM** de esa imagen.
5. Compara (`diff`-friendly) los conteos de componentes entre ambos formatos.
6. Pasa el SBOM CycloneDX a `grype` y produce `vulns.json`.
7. Limpia (trap) al salir.

## Cómo ejecutar

```bash
bash run.sh
```

Salida esperada (resumen):

```
== sec-08 example 01: syft CycloneDX & SPDX ==
[OK] syft found (vX.Y.Z)
[OK] grype found (vX.Y.Z)
[INFO] scratch: /tmp/sec-08-syft-demo
[INFO] generating source SBOM (CycloneDX)...
[OK] sbom-source.cdx.json written (N components)
[INFO] generating source SBOM (SPDX)...
[OK] sbom-source.spdx.json written (N components)
[INFO] scanning SBOM with grype...
[OK] vulns.json written (M findings total, K critical/high)
[DONE] cleaning up /tmp/sec-08-syft-demo
```

Si falta tooling:

```
[SKIP] syft not found. Install: https://github.com/anchore/syft#installation
[SKIP] example cannot run; exiting 0.
```

## Puntos a observar

- Ambos archivos (`*.cdx.json` y `*.spdx.json`) listan **los mismos componentes** con **nombres de campos distintos**. CycloneDX usa `components[].purl`; SPDX usa `packages[].externalRefs[].referenceLocator`.
- Grype funciona igual de bien escaneando la imagen o el SBOM — pero el SBOM es **reproducible**: si guardas el SBOM, puedes volver a escanearlo mañana contra una DB actualizada y comparar la **delta** de nuevos CVEs.
- Pinnear versiones viejas de `requests` o `urllib3` casi siempre produce findings. Es intencional: ilustra el ciclo *inventory → scan → remediate*.

## Siguiente paso

Ver `examples/02-attest-build-provenance-ghactions/` para la publicación como attestation adjunta a la imagen.
