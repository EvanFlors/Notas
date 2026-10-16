# Starter — sec-02-01-audit-your-secrets

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-02-audit
   cd /tmp/sec-02-audit
   ```
3. Crea `INVENTORY.md` con las cuatro secciones (A: contexto, B: tabla ≥5 filas, C: top-3 riesgos, D: plan de migración a 90 días).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/02-secrets-overview-and-principles/activities/01-audit-your-secrets/tests/validate.sh /tmp/sec-02-audit
   ```
5. Compara tu documento con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** nunca metas valores de secretos reales. Si necesitas mostrar formato, usa marcadores obviamente falsos como `sk_fake_...`, `AKIAFAKE...`, `postgres://user:fake@host/db`.

> **Validador:** comprueba estructura (columnas, familias, hogares, al menos 5 filas), no semántica. La corrección conceptual la revisas tú contra la referencia.
