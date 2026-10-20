# Starter — gcp-09-02-write-org-policy-baseline-and-validate

Esta actividad es **independiente**: no hay plantilla de código que ejecutar. Tu entregable son 5 YAMLs y 1 README escritos por ti.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-org-policy-anatomy/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-09-org-policy
   cd /tmp/gcp-09-org-policy
   ```
3. Instala `pyyaml` si no está:
   ```bash
   python3 -c "import yaml" 2>/dev/null || pip install --user pyyaml
   ```
4. Crea los 5 YAMLs y el README-INTENT.md con los nombres **exactos** que exige el validador.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/09-multi-project-org-cloud-identity/activities/02-write-org-policy-baseline-and-validate/tests/validate.sh /tmp/gcp-09-org-policy
   ```
6. Compara tus archivos con `../solution/` para autoevaluarte.

## Plantillas sugeridas (opcionales)

### `org-policy-disable-sa-key-creation.yaml`

```yaml
name: organizations/<ORG-NUMBER-PLACEHOLDER>/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: true
  inheritFromParent: false
  reset: false
```

### `org-policy-vm-external-ip.yaml`

```yaml
name: organizations/<ORG-NUMBER-PLACEHOLDER>/policies/compute.vmExternalIpAccess
spec:
  rules:
    - denyAll: true
  inheritFromParent: false
```

### `vpc-sc-perimeter.yaml`

```yaml
name: accessPolicies/<ACCESS-POLICY-ID-PLACEHOLDER>/servicePerimeters/prod_data_perimeter
title: prod_data_perimeter
status:
  resources:
    - projects/<project-number-of-checkout-prod>
    - projects/<project-number-of-analytics-prod>
  restrictedServices:
    - storage.googleapis.com
    - bigquery.googleapis.com
    - cloudkms.googleapis.com
  accessLevels:
    - accessPolicies/<ACCESS-POLICY-ID-PLACEHOLDER>/accessLevels/corp_network
  vpcAccessibleServices:
    enableRestriction: true
    allowedServices:
      - RESTRICTED-SERVICES
```

Rellena las otras dos Org Policies y el README-INTENT.md con la misma lógica. Recuerda: **nunca** uses números reales de org, folder o project.
