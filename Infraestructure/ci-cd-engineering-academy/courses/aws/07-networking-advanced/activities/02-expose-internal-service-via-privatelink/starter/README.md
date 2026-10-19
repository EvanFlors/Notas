# Starter — aws-07-02-expose-internal-service-via-privatelink

Actividad **independiente**. Dos entregables: Terraform (productor + consumidor) y análisis de coste (CSV + MD).

## Pasos

1. Lee `../README.md` completo.
2. Prepara el árbol:
   ```bash
   mkdir -p /tmp/aws-07-privatelink/{producer,consumer}
   cd /tmp/aws-07-privatelink
   ```
3. En `producer/`, escribe `providers.tf`, `main.tf`, `outputs.tf` siguiendo `../../examples/02-nlb-with-privatelink/` (lado productor).
4. En `consumer/`, escribe `providers.tf`, `main.tf`, `variables.tf` (lado consumidor).
5. En cada carpeta:
   ```bash
   terraform init -backend=false
   terraform validate
   ```
6. Escribe `DECISIONS.md` con dos ADRs (acceptance_required, private_dns_enabled).
7. Escribe `cost-tradeoff.csv` con el encabezado exacto y 6 filas de datos (3 tramos × 2 opciones).
8. Escribe `cost-tradeoff.md` explicando fórmula, ganador por tramo y un factor no-coste.
9. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/07-networking-advanced/activities/02-expose-internal-service-via-privatelink/tests/validate.sh /tmp/aws-07-privatelink
   ```
10. Compara con `../solution/REFERENCE.md`.

> Nunca uses Account IDs reales. Usa `012345678901` como placeholder.
