# Starter — sec-08-01

Materiales para arrancar la actividad.

## Archivos

- `provenance.template.json` — esqueleto SLSA v1.0 L1 (self-reported). Cópialo a `/tmp/sec-08-capstone/provenance.json` y rellénalo.
- `release.yml.template` — workflow GHA de referencia. Cópialo a `/tmp/sec-08-capstone/release.yml` y adapta `<org>/<repo>` a tu capstone.
- `bootstrap.sh` — script opcional que crea el scratch dir y copia los templates.

## Flujo recomendado

1. `bash starter/bootstrap.sh` (o copia a mano los templates y crea `/tmp/sec-08-capstone`).
2. Ejecuta `syft` sobre tu imagen o directorio para generar los dos SBOMs.
3. Ejecuta `grype sbom:sbom.cdx.json -o json > vulns.json`.
4. Edita `provenance.json` con tus valores reales.
5. Revisa `release.yml`.
6. `bash ../tests/validate.sh /tmp/sec-08-capstone`.
