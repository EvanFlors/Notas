# Starter — plat-04-02-k8s-deploy-via-helm

Esta actividad es **independiente** y documental + artefacto YAML. No requiere cluster.

## Pasos

1. Lee `../README.md`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-04-helm
   cd /tmp/plat-04-helm
   ```
3. Escribe `values.yaml` con los 5 bloques requeridos (`image`, `extraEnvVars`, `ingress`, `postgresql.enabled: false`, opcional `serviceMonitor`).
4. Escribe `HELM-DEPLOY.md` con las 4 secciones A–D.
5. Verifica que ningún secreto real haya quedado. Todos los secretos se referencian via `secretKeyRef`.
6. (Opcional) Si tienes `helm` instalado:
   ```bash
   helm repo add backstage https://backstage.github.io/charts
   helm repo update
   helm template my-backstage backstage/backstage --values /tmp/plat-04-helm/values.yaml > /tmp/plat-04-helm/rendered.yaml
   ```
7. Valida:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/04-backstage-architecture-and-setup/activities/02-k8s-deploy-via-helm/tests/validate.sh /tmp/plat-04-helm
   ```
8. Compara con `../solution/`.

> El validador verifica estructura y hace SKIP limpio si `helm` o `python3-yaml` no están disponibles.
