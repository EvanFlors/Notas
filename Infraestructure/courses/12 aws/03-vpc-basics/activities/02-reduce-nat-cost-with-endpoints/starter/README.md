# Starter — aws-03-02-reduce-nat-cost-with-endpoints

Esta actividad es **independiente** y conceptual: no hay Terraform ni infraestructura. Tu entregable es un análisis de costos en Markdown.

## Pasos

1. Lee `../README.md` completo (en particular la tabla de tráfico en §2).
2. Prepara el workspace:
   ```bash
   mkdir -p /tmp/aws-03-nat-endpoints
   cd /tmp/aws-03-nat-endpoints
   ```
3. Escribe `COST-ANALYSIS.md` con las secciones A (clasificación), B (cálculo), C (diagrama antes/después), D (5 recomendaciones).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/03-vpc-basics/activities/02-reduce-nat-cost-with-endpoints/tests/validate.sh /tmp/aws-03-nat-endpoints
   ```
5. Compara con `../solution/REFERENCE.md` para autoevaluarte.
