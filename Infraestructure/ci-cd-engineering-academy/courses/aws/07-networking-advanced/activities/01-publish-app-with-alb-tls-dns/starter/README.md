# Starter — aws-07-01-publish-app-with-alb-tls-dns

Esta actividad es **guiada**. No se aplica nada contra AWS.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-07-alb
   cd /tmp/aws-07-alb
   ```
3. Crea `providers.tf`, `variables.tf` y `main.tf` siguiendo el patrón de `../../examples/01-alb-with-acm-and-route53/`.
4. Usa el provider stub (`skip_credentials_validation`, etc.) para poder correr `plan` offline.
5. Ejecuta:
   ```bash
   terraform init -backend=false
   terraform validate
   terraform plan -no-color > plan.txt 2>&1 || true
   ```
6. Escribe `DECISIONS.md` con las tres ADRs requeridas (ALB vs NLB, DNS validation, alias vs CNAME).
7. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/07-networking-advanced/activities/01-publish-app-with-alb-tls-dns/tests/validate.sh /tmp/aws-07-alb
   ```
8. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** nunca uses dominios ni Account IDs reales. `example.internal` y `012345678901` son los placeholders de este lab.
