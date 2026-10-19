# Starter — aws-11-02-migrate-irsa-to-pod-identity

Esta actividad es **independiente** y puramente de diseño/documentación. No se levanta nada en AWS.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-11-02/{manifests,docs}
   cd /tmp/aws-11-02
   ```
3. Escribe los 3 entregables:
   - `manifests/sa-irsa.yaml` (SA + Deployment con IRSA + policy IAM en comentarios).
   - `manifests/sa-pod-identity.yaml` (SA + Deployment con Pod Identity + policy IAM + association en comentarios).
   - `docs/MIGRATION.md` (comparación + plan por fases + matriz de 3 escenarios + límite).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/11-eks-in-depth/activities/02-migrate-irsa-to-pod-identity/tests/validate.sh /tmp/aws-11-02
   ```
5. Compara con `../solution/REFERENCE.md`.
6. Limpia:
   ```bash
   rm -rf /tmp/aws-11-02
   ```

> **Reglas:** account id ficticio `123456789012`, nunca uno real. Nada de keys estáticas en los YAML, ni siquiera "fake".
