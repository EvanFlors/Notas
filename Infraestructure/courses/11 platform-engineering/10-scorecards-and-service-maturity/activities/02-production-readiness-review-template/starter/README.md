# Starter — plat-10-02-production-readiness-review-template

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-10-prr
   cd /tmp/plat-10-prr
   ```
3. Crea `PRR-TEMPLATE.md` con las 7 secciones mínimas (Resumen+scorecard, Dependencias, Modos de fallo, Capacidad, Rollback+DR, Ownership on-call, Archivo+revisión).
4. Crea `NOTES.md` con las tres secciones (A: qué mide la PRR que el scorecard no puede; B: qué mide el scorecard que la PRR no debe repetir; C: flujo propuesto).
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/10-scorecards-and-service-maturity/activities/02-production-readiness-review-template/tests/validate.sh /tmp/plat-10-prr
   ```
6. Compara tu plantilla con `../solution/TEMPLATE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la plantilla modelo.
