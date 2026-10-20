# Starter — az-07-02

Crea el workspace de scratch y empieza desde cero:

```bash
mkdir -p /tmp/az-07-02/{manifests,docs}
cd /tmp/az-07-02
```

Entregables (todos en `/tmp/az-07-02`):

- `manifests/sa-pod-identity-v1.yaml` (ANTES — AAD Pod Identity v1)
- `manifests/sa-wi.yaml` (DESPUÉS — Workload Identity)
- `docs/MIGRATION.md` (comparación + plan + matriz + límite + 7 preguntas)

**Placeholders obligatorios** (no uses IDs reales):

- Subscription: `00000000-0000-0000-0000-000000000000`.
- Tenant: `11111111-1111-1111-1111-111111111111`.
- `client-id` de la MI `mi-az07-app`: `33333333-3333-3333-3333-333333333333`.
- OIDC issuer URL: `https://westeurope.oic.prod-aks.azure.com/11111111-1111-1111-1111-111111111111/aaaabbbb-cccc-dddd-eeee-ffff00001111/`.
- Namespace: `apps`. ServiceAccount: `app`. → `subject = "system:serviceaccount:apps:app"`.

Sigue las instrucciones de `../README.md`. Compara al final con `../solution/REFERENCE.md`.
