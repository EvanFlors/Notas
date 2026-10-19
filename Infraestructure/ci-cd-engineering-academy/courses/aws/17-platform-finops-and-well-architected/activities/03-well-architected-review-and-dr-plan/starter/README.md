# Starter — aws-17-03-well-architected-review-and-dr-plan

Actividad **scenario / capstone**: no hay código ni plantilla ejecutable. Tus entregables son tres documentos Markdown escritos por ti.

## Pasos

1. Lee `../README.md` entero (es largo; léelo despacio).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-17-war
   cd /tmp/aws-17-war
   ```
3. Produce los tres archivos:
   - `WELL-ARCHITECTED-REVIEW.md` — review de los 6 pilares + plan de mejora.
   - `DR-PLAN.md` — clasificación de workloads, patrones, factura relativa, runbook.
   - `COST-EXPLORER-WALKTHROUGH.md` — pasos textuales (sin acceso real).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/17-platform-finops-and-well-architected/activities/03-well-architected-review-and-dr-plan/tests/validate.sh /tmp/aws-17-war
   ```
5. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** no uses account IDs reales, no inventes servicios AWS inexistentes, no incluyas secretos. Todo es ficticio y escrito.
