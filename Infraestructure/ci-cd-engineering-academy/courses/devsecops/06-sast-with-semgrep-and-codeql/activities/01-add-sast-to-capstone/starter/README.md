# Starter — sec-06-01-add-sast-to-capstone

Esta actividad produce archivos a mano. No hay plantilla ejecutable — solo pasos.

## Pasos

1. Lee `../README.md`.
2. Prepara el scratch dir:
   ```bash
   rm -rf /tmp/sec-06-01-capstone
   mkdir -p /tmp/sec-06-01-capstone/src /tmp/sec-06-01-capstone/.github/workflows
   cd /tmp/sec-06-01-capstone
   ```
3. Crea `src/app.py` con 3 vulnerabilidades plantadas (ver sección 5.2).
4. (Opcional) Corre `semgrep scan --config auto src/` y `bandit -r src/`.
5. Escribe `.github/workflows/semgrep.yml` y `.github/workflows/codeql.yml`.
6. Escribe `TRIAGE.md` con 10 findings clasificados.
7. Valida:
   ```bash
   bash <ruta-repo>/courses/devsecops/06-sast-with-semgrep-and-codeql/activities/01-add-sast-to-capstone/tests/validate.sh /tmp/sec-06-01-capstone
   ```
8. Compara con `../solution/REFERENCE.md`.
9. Limpia: `rm -rf /tmp/sec-06-01-capstone`.

> **Importante:** el validador comprueba estructura y presencia; la calidad del triage la revisas tú contra la referencia.
