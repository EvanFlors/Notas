# Starter — aws-13-01-publish-site-with-cf-acm-route53

Esta actividad es un **mini-project de diseño sin aplicar**. No hay esqueleto Terraform que ejecutar; tú escribes los artefactos desde cero siguiendo la especificación del README padre.

## Pasos

1. Lee `../README.md` completo. Presta atención a §6.2 (los 5 artefactos obligatorios).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-13-publish
   cd /tmp/aws-13-publish
   ```
3. Crea los 5 ficheros:
   - `main.tf`
   - `distribution.json`
   - `ACM_DNS_WALKTHROUGH.md`
   - `CACHE_ORDER_ADR.md`
   - `COSTS.md`
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/13-edge-dns-cdn-acm/activities/01-publish-site-with-cf-acm-route53/tests/validate.sh /tmp/aws-13-publish
   ```
5. Compara contra `../solution/REFERENCE.md` para autoevaluarte.

## Herramientas requeridas

- `bash`
- `jq` (para que el validador parsee `distribution.json`)
- Editor de texto

**No** necesitas: credenciales AWS, cuenta AWS, `terraform` instalado (opcional). Nada se aplica.

> El validador comprueba **estructura**, no corrección semántica. La corrección la revisas tú contra la referencia.
