# Example 02 — External Secrets Operator sincronizando desde Vault

> Objetivo: instalar ESO en el cluster `kind`, declarar un `ClusterSecretStore` que apunte al Vault dev del ejemplo anterior, y un `ExternalSecret` que materialice un `Secret` K8s desde `kv/payments/stripe`.

## 1. Qué vas a construir

```
   Vault (dev, Docker)                   kind cluster
   ─────────────────                 ──────────────────────────────
                                     ns: external-secrets
                                       └── Deployment: external-secrets
                                            │
                                            │ (watch CRDs)
                                            ▼
                                     ns: payments
                                       ├── ClusterSecretStore: vault-dev
                                       └── ExternalSecret: payments-stripe
                                            │
                                            │ (refresh cada 30s)
                                            ▼
                                       Secret K8s: payments-stripe
                                       data:
                                         STRIPE_API_KEY: sk_test_abc123
   kv/payments/stripe   ────────────────────▲
     api_key=sk_test_abc123
```

**Pre-requisito:** haber corrido `example-01` **hasta el final del paso 3.5** y **no haber hecho la limpieza**. Reutilizamos el mismo `sec-13-vault` (Docker), el mismo cluster `kind` `sec-13-ex01` y el mismo role `payments` en Vault.

Si vienes de limpio: ejecuta los pasos 3.1 a 3.5 del `example-01` antes de seguir.

## 2. Instalar ESO vía Helm

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set installCRDs=true \
  --wait --timeout=5m

kubectl -n external-secrets get pods
# Deberías ver external-secrets, external-secrets-webhook y external-secrets-cert-controller en Running.
```

## 3. Permitir que ESO se autentique contra Vault

ESO necesita un SA en su namespace para que Vault lo reconozca. Añadimos un segundo role en Vault:

```bash
# Policy ya existe desde example-01 (payments-read). Si no, créala.
vault policy write payments-read - <<'EOF'
path "kv/data/payments/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/eso-payments \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=payments-read \
  ttl=1h
```

## 4. Declarar el `ClusterSecretStore`

```bash
# IP del contenedor Vault vista desde dentro de la red kind
VAULT_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' sec-13-vault | awk 'NF{print; exit}')"

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-dev
spec:
  provider:
    vault:
      server: "http://${VAULT_IP}:8200"
      path: "kv"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "eso-payments"
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
EOF

kubectl get clustersecretstore vault-dev
# STATUS = Valid
```

Si `STATUS != Valid`, revisa `kubectl describe clustersecretstore vault-dev` y `kubectl -n external-secrets logs -l app.kubernetes.io/name=external-secrets`.

## 5. Declarar el `ExternalSecret`

```bash
kubectl create namespace payments 2>/dev/null || true

cat <<'EOF' | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payments-stripe
  namespace: payments
spec:
  refreshInterval: "30s"
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-dev
  target:
    name: payments-stripe
    creationPolicy: Owner
  data:
    - secretKey: STRIPE_API_KEY
      remoteRef:
        key: payments/stripe
        property: api_key
EOF

# Espera hasta ~30s a la primera sincronización
sleep 10
kubectl -n payments get externalsecret payments-stripe
# STATUS = SecretSynced
kubectl -n payments get secret payments-stripe -o jsonpath='{.data.STRIPE_API_KEY}' | base64 -d; echo
# → sk_test_abc123
```

## 6. Rotación observada en vivo

Cambia el valor en Vault y espera un `refreshInterval`:

```bash
vault kv put kv/payments/stripe api_key=sk_test_ROTADO
sleep 35
kubectl -n payments get secret payments-stripe -o jsonpath='{.data.STRIPE_API_KEY}' | base64 -d; echo
# → sk_test_ROTADO
```

Observa: el `Secret` K8s se actualizó solo. Para que el **proceso** vea el nuevo valor, el Pod que lo consume debe reiniciarse o montar como fichero + reload. Esa decisión queda del lado de la app (ver §5.1 de la lección).

## 7. Lo que acabas de demostrar

- **ESO + Vault + Kubernetes auth** = tubería declarativa. En Git vive **qué** secreto necesitas y **de dónde**, nunca el valor.
- `refreshInterval` convierte una rotación en el backend en una actualización automática del `Secret` K8s.
- `creationPolicy: Owner` significa: ESO crea el `Secret`, ESO lo borra si borras el `ExternalSecret`. GitOps-friendly.

## 8. Limpieza

Si vas a continuar con `example-03`, mantén el cluster. Si no:

```bash
helm uninstall external-secrets -n external-secrets
kind delete cluster --name sec-13-ex01
docker rm -f sec-13-vault
```

## 9. Para profundizar

- Añade un segundo `ExternalSecret` que lea `kv/payments/stripe` pero **todas** las propiedades (usa `dataFrom:` en vez de `data:`).
- Prueba `creationPolicy: Merge` sobre un `Secret` creado por Helm; comprueba que ESO solo añade claves nuevas.
- Instala el chart `stakater/reloader` y anota el Deployment consumidor con `secret.reloader.stakater.com/reload: payments-stripe`. Comprueba el rolling restart al cambiar el valor en Vault.
