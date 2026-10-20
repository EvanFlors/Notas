# Starter — aws-12-02-cost-trim-cw-logs

Esta actividad es **independiente**: no hay código ni plantilla ejecutable. Produces 4 ficheros en `/tmp/aws-12-cost/`:

- `RETENTION.md`
- `metric_filter.json`
- `insights.md`
- `alarm.json`

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-12-cost
   cd /tmp/aws-12-cost
   ```
3. Crea los 4 ficheros con el contenido indicado en la sección 5 del README principal.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/12-observability-cloudwatch-xray-cloudtrail/activities/02-cost-trim-cw-logs/tests/validate.sh /tmp/aws-12-cost
   ```
5. Autoevalúate con `../solution/REFERENCE.md`.
