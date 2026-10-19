# Starter — aws-13-02-add-waf-and-geo-restriction

Esta actividad es **independiente** y **puramente escrita**. No hay código ni Terraform; tu entregable es un Markdown.

## Pasos

1. Lee `../README.md` completo. Fíjate en las 4 secciones obligatorias.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-13-waf
   cd /tmp/aws-13-waf
   ```
3. Crea `WAF_DESIGN.md` con:
   - Sección 1 — Reglas (al menos 3).
   - Sección 2 — Decisión Geo (CloudFront vs WAF, con trade-offs).
   - Sección 3 — Costos (USD/mes, con 5 y 0.60).
   - Sección 4 — Limitaciones (al menos 5 numeradas).
4. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/13-edge-dns-cdn-acm/activities/02-add-waf-and-geo-restriction/tests/validate.sh /tmp/aws-13-waf
   ```
5. Compara contra `../solution/REFERENCE.md`.

> El validador comprueba **estructura**. La calidad conceptual la revisas tú.
