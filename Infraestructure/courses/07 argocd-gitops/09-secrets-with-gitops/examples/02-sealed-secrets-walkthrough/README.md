# Ejemplo 02 — Sealed Secrets walkthrough

> Instalar el controller `sealed-secrets` y recorrer el ciclo `kubeseal` → commit → sync. Todo local, sin cloud.

## Prerrequisitos

- `kind` 0.23+, `kubectl`, `helm` 3.14+, `kubeseal` CLI (`brew install kubeseal` o descarga de releases).
- Scratch: `/tmp/argo-09-sealed`.

## 1. Cluster + controller

```bash
mkdir -p /tmp/argo-09-sealed && cd /tmp/argo-09-sealed

kind create cluster --name argo09-sealed

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system --set fullnameOverride=sealed-secrets-controller \
  --wait
```

## 2. Obtener la clave pública del controller

```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system > pub-cert.pem
```

## 3. Sellar un `Secret`

```bash
kubectl create ns demo

# produce el Secret plano SIN aplicarlo (dry-run)
kubectl -n demo create secret generic db \
  --from-literal=password='s3cr3t' \
  --dry-run=client -o yaml > db-secret.yaml

# cifrarlo con la clave pública -> SealedSecret
kubeseal --cert pub-cert.pem --format yaml < db-secret.yaml > db-sealed.yaml

# el ciphertext es seguro de commitear a Git:
grep -c "encryptedData" db-sealed.yaml   # -> 1
```

Nota el *scoping* por default: el `SealedSecret` sólo puede descifrarse si el `name` y `namespace` del objeto final coinciden. Mover a otro namespace requiere re-sellar.

## 4. Aplicar y observar

```bash
kubectl apply -f db-sealed.yaml
kubectl -n demo get sealedsecret db
kubectl -n demo get secret db -o jsonpath='{.data.password}' | base64 -d
# -> s3cr3t
```

## 5. Rotar el valor

```bash
kubectl -n demo create secret generic db \
  --from-literal=password='s3cr3t-v2' \
  --dry-run=client -o yaml > db-secret.yaml
kubeseal --cert pub-cert.pem --format yaml < db-secret.yaml > db-sealed.yaml

kubectl apply -f db-sealed.yaml
kubectl -n demo get secret db -o jsonpath='{.data.password}' | base64 -d
# -> s3cr3t-v2
```

Rotar la **clave maestra** del controller es un procedimiento separado y caro (reencrypt de todos los `SealedSecret`). Ver documentación de `sealed-secrets` sobre `rotateKeys`.

## 6. Lecturas clave

- `SealedSecret` en Git = ciphertext irreversible sin la clave privada del controller.
- La clave privada vive como `Secret` en `kube-system`. **Respáldala fuera de banda** (fuera del cluster) o pierdes todos los secretos si el cluster muere.
- Para múltiples clusters: cada uno tiene su clave; hay que re-sellar por cluster, o compartir la clave (anti-patrón para la mayoría de casos).

## Limpieza

```bash
kind delete cluster --name argo09-sealed
rm -rf /tmp/argo-09-sealed
```
