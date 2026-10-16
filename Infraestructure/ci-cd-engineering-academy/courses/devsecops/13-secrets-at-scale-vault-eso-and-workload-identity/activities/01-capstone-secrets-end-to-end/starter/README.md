# Starter — sec-13-01-capstone-secrets-end-to-end

Scripts para levantar el entorno + manifests con TODOs que debes completar.

## Scripts (ejecutar en orden)

| Script | Qué hace |
|--------|----------|
| `01-start-vault.sh`     | Arranca `hashicorp/vault:1.15` en modo dev (`token=root`, in-memory). |
| `02-create-cluster.sh`  | Crea el cluster `kind` `sec-13-capstone` y conecta Vault a su red. |
| `03-install-eso.sh`     | Instala ESO en el namespace `external-secrets` vía Helm. |
| `04-bootstrap-vault.sh` | Habilita `kv-v2` y `kubernetes` auth; crea role `eso-payments` + policy; siembra `kv/payments/stripe`. Imprime la URL de Vault visible desde dentro del cluster — úsala en `manifests/secret-store.yaml`. |
| `cleanup.sh`            | Borra cluster `kind`, contenedor `sec-13-vault` y `/tmp/sec-13-capstone`. |

## Manifests a completar

| Archivo | TODOs |
|---------|-------|
| `manifests/secret-store.yaml`    | `vault.server`, `vault.auth.kubernetes.role` |
| `manifests/external-secret.yaml` | `secretStoreRef.name`, `target.name`, `data[0].remoteRef.{key,property}` |
| `manifests/consumer.yaml`        | `env.STRIPE_API_KEY.valueFrom.secretKeyRef` |

**Prohibido** meter el valor del secreto (`sk_test_...`) en los YAML. El validador lo comprueba con `grep`.

## Verificación rápida

```bash
./01-start-vault.sh
./02-create-cluster.sh
./03-install-eso.sh
./04-bootstrap-vault.sh
# Edita manifests/*.yaml
kubectl --context kind-sec-13-capstone apply -f manifests/
bash ../tests/validate.sh
```
