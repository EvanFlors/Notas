# Ejemplo 01 — ESO contra un *fake provider* (equivalente conceptual a AWS Secrets Manager)

> Objetivo: ver `ExternalSecret` → `Secret` nativo materializado por ESO, con rotación observable, **sin cuentas cloud**. Se usa el `Fake` provider que trae ESO para tests. La forma de los manifiestos es idéntica a la de un provider real (sólo cambia el `SecretStore`).

## Prerrequisitos

- `kind` 0.23+, `kubectl`, `helm` 3.14+.
- Internet para descargar el chart `external-secrets`.
- Scratch dir: `/tmp/argo-09-eso`.

## 1. Cluster y namespace

```bash
mkdir -p /tmp/argo-09-eso && cd /tmp/argo-09-eso

kind create cluster --name argo09-eso
kubectl create ns external-secrets
kubectl create ns demo
```

## 2. Instalar External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --set installCRDs=true \
  --wait
```

Verifica:

```bash
kubectl get pods -n external-secrets
kubectl api-resources | grep external-secrets.io
```

## 3. Fake provider: un `ClusterSecretStore` que lee de un `data:` embebido

El provider `Fake` sirve valores que *tú* declaras en el propio `SecretStore` — perfecto para demos/pruebas sin cloud. La estructura es la misma que para AWS SM; sólo cambiarías `spec.provider.aws` por `spec.provider.fake`.

```yaml
# cluster-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: fake-store
spec:
  provider:
    fake:
      data:
        - key: "prod/db"
          value: '{"username":"capstone","password":"s3cr3t-v1"}'
        - key: "prod/api"
          value: "api-token-v1"
```

```bash
kubectl apply -f cluster-secret-store.yaml
```

## 4. `ExternalSecret` que produce el `Secret` nativo

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db
  namespace: demo
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: fake-store
    kind: ClusterSecretStore
  target:
    name: db
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: prod/db
        property: username
    - secretKey: password
      remoteRef:
        key: prod/db
        property: password
```

```bash
kubectl apply -f external-secret.yaml
kubectl -n demo get externalsecret db -w   # Ctrl-C cuando status=SecretSynced
kubectl -n demo get secret db -o jsonpath='{.data.password}' | base64 -d
# -> s3cr3t-v1
```

## 5. Rotación observable

Edita el `ClusterSecretStore` cambiando `s3cr3t-v1` → `s3cr3t-v2`, reaplica, y espera 30s:

```bash
sed -i.bak 's/s3cr3t-v1/s3cr3t-v2/' cluster-secret-store.yaml
kubectl apply -f cluster-secret-store.yaml

sleep 35
kubectl -n demo get secret db -o jsonpath='{.data.password}' | base64 -d
# -> s3cr3t-v2
```

## 6. Lectura clave

- En Git sólo viven el `ClusterSecretStore` (que en real **no llevaría valores**, sólo `region`, `role`, etc.) y el `ExternalSecret` (sólo refs).
- El `Secret` nativo aparece en el namespace sin que ningún ingeniero lo tocara.
- Rotar es cambiar el valor en el provider; GitOps sigue siendo la fuente de verdad de *qué* se necesita.

## Limpieza

```bash
kind delete cluster --name argo09-eso
rm -rf /tmp/argo-09-eso
```
