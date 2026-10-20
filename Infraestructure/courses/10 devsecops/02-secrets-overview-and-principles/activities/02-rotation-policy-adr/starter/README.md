# Starter — sec-02-02-rotation-policy-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-02-adr
   cd /tmp/sec-02-adr
   ```
3. Crea `ADR-rotation.md` con las secciones canónicas (`Status`, `Context`, `Decision` [+ tabla TTL + break-glass], `Consequences`, `Alternatives considered`, `References`).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/02-secrets-overview-and-principles/activities/02-rotation-policy-adr/tests/validate.sh /tmp/sec-02-adr
   ```
5. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** nunca metas valores de secretos reales. Si necesitas mostrar formato, usa marcadores obviamente falsos como `sk_fake_...`, `AKIAFAKE...`.
