# Starter — sec-08-02

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo. Fíjate en el *escenario del pipeline hipotético* (§5).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-08-roadmap
   cd /tmp/sec-08-roadmap
   ```
3. Crea `SLSA-ROADMAP.md` con las cinco secciones (A diagnóstico, B L2, C L3, D métricas, E afirmaciones).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/08-sbom-and-slsa-in-practice/activities/02-slsa-level-roadmap/tests/validate.sh /tmp/sec-08-roadmap
   ```
5. Compara tu documento con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.
