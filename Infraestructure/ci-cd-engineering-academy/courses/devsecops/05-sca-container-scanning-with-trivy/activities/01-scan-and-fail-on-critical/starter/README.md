# Starter — sec-05-01-scan-and-fail-on-critical

Esta actividad es un **guided-lab** práctico. No hay plantilla de código: construyes tú el `Dockerfile` y el `.trivyignore.yaml` siguiendo las instrucciones.

## Pasos resumidos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-05-fail-on-critical
   cd /tmp/sec-05-fail-on-critical
   ```
3. Sigue `../README.md` secciones 5.2 a 5.7:
   - crea el `Dockerfile` basado en `alpine:3.14`,
   - `docker build -t sec05-badimage:local .`,
   - primer scan sin ignore (espera `exit=1`, guárdalo en `scan1.exit`),
   - escribe `.trivyignore.yaml` con `id` + `statement` + `expired_at`,
   - segundo scan con ignore (guarda `scan2.exit`),
   - escribe `POLICY.md` con secciones A, B y C.
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/05-sca-container-scanning-with-trivy/activities/01-scan-and-fail-on-critical/tests/validate.sh /tmp/sec-05-fail-on-critical
   ```
5. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante**: si no tienes `docker` o `trivy`, el validador SKIP los checks ejecutables y evalúa solo los artefactos escritos (`Dockerfile`, `.trivyignore.yaml`, `POLICY.md`).
