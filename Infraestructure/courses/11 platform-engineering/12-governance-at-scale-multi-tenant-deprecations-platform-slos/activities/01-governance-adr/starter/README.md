# Starter — plat-12-01-governance-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti con formato ADR.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-12-governance
   cd /tmp/plat-12-governance
   ```
3. Crea `GOVERNANCE-ADR.md` con las **9 secciones** requeridas:
   1. Contexto
   2. Decisión: multi-tenancy (4 planos)
   3. Decisión: deprecation policy
   4. Decisión: platform SLOs
   5. Decisión: release cadence
   6. Decisión: versionado de contratos
   7. Decisión: inner-source
   8. Consecuencias
   9. Alternativas consideradas
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/12-governance-at-scale-multi-tenant-deprecations-platform-slos/activities/01-governance-adr/tests/validate.sh /tmp/plat-12-governance
   ```
5. Compara tu documento con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.
