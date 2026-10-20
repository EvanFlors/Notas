# ANALYSIS — por qué base64 no es cifrado

Autor: alumno (ejemplo de referencia). Fecha: 2026-10-15.

## Setup

Cluster kind local y namespace de trabajo:

```
$ kind get clusters | grep -qx k8s-05 || kind create cluster --name k8s-05
$ kubectl create namespace demo-canary --dry-run=client -o yaml | kubectl apply -f -
namespace/demo-canary created
```

## Creación del Secret

Creé un Secret `Opaque` con un valor dummy canario único (`dummy-canary-XYZ789`) para poder *grep*earlo luego:

```
$ kubectl -n demo-canary create secret generic canary \
    --from-literal=password='dummy-canary-XYZ789'
secret/canary created
```

## Demostración 1 — base64 trivialmente revertible

El valor "cifrado" del Secret se obtiene con un one-liner. No hay llave, no hay desafío criptográfico:

```
$ kubectl -n demo-canary get secret canary -o jsonpath='{.data.password}'
ZHVtbXktY2FuYXJ5LVhZWjc4OQ==

$ kubectl -n demo-canary get secret canary -o jsonpath='{.data.password}' | base64 -d
dummy-canary-XYZ789
```

Esto prueba que **base64 es un encoding, no un cifrado**: no requiere ningún secreto para revertirlo; cualquier CLI estándar (`base64`, `openssl base64`, `python -m base64 -d`) lo hace. El propósito del encoding en Secrets es que valores binarios o con caracteres especiales encajen limpios en YAML — no la confidencialidad.

## Demostración 2 — grep del cleartext

El YAML entero del Secret muestra `data.password` con los mismos bytes base64 que están en etcd:

```
$ kubectl -n demo-canary get secret canary -o yaml | grep -E '^  password:'
  password: ZHVtbXktY2FuYXJ5LVhZWjc4OQ==

$ echo ZHVtbXktY2FuYXJ5LVhZWjc4OQ== | base64 -d
dummy-canary-XYZ789
```

Opcional (prueba contra etcd en kind): entrando al contenedor del nodo control-plane, con las certs del propio apiserver, `etcdctl` recupera el objeto directamente de la fuente de verdad:

```
$ docker exec -it k8s-05-control-plane sh -c '
    ETCDCTL_API=3 etcdctl \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/peer.crt \
      --key=/etc/kubernetes/pki/etcd/peer.key \
      get /registry/secrets/demo-canary/canary' | strings | grep -i canary
dummy-canary-XYZ789
```

Los bytes del password se ven en claro dentro del serializado protobuf del objeto. Un backup de etcd (`etcdctl snapshot save`) tomado en este momento *contendría estos bytes tal cual*. Quien tenga acceso al snapshot tiene acceso al Secret.

## Afirmaciones específicas

- **base64 es un encoding, no un cifrado**: revertirlo no requiere ninguna llave; es un alfabeto de 64 caracteres para representar bytes arbitrarios en ASCII imprimible.
- **Sin `EncryptionConfiguration`**, el `kube-apiserver` escribe los `data` de los Secrets en **etcd** tal cual los recibe, sin cifrarlos. Es por eso que un snapshot de etcd leaka Secrets por default.
- `EncryptionConfiguration` (archivo `apiserver.config.k8s.io/v1`) habilita cifrado at-rest con providers `aescbc`, `aesgcm`, `secretbox` o `kms`/`kms` v2. Habilita cifrado solo de los recursos listados (típicamente `secrets`) **para escrituras nuevas**: hay que `kubectl get secrets --all-namespaces -o json | kubectl replace -f -` para reescribir los existentes.
- Lo que `EncryptionConfiguration` **no** cubre: `get secret` sigue devolviendo cleartext a quien tenga RBAC; las *llaves* del provider local hay que custodiarlas aparte (ideal: `kms` v2 con KMS cloud).

## Recomendación

Mi recomendación es **adoptar External Secrets Operator (ESO)** y, en paralelo, activar `EncryptionConfiguration` en el apiserver (o la equivalencia managed: EKS KMS, GKE Application-Layer Secrets Encryption, AKS KMS). Razones:

1. **Fuente de verdad fuera del cluster**: los secretos viven en AWS Secrets Manager / Vault / GCP SM, con auditoría, versionado y rotación ya resueltos. El cluster deja de ser el eslabón débil del lifecycle.
2. **Rotación sin despliegue**: `ExternalSecret.spec.refreshInterval` resincroniza; la app no se recompila ni se redespliega para que llegue una password nueva.
3. **Reducción del blast radius humano**: nadie escribe `kubectl create secret` a mano en producción, por lo que no hay copias en shells, scripts, repos privados ni clipboard history.
4. **Multi-backend**: si cambiamos de proveedor, solo cambia el `SecretStore`, no la app.
5. **Combinable con encryption at rest**: ESO sigue materializando un `Secret` nativo en el namespace de la app; con `EncryptionConfiguration` ese Secret ya no está cleartext en etcd. Defensa en profundidad.

Alternativas evaluadas:

- **Secrets Store CSI Driver**: más estricto (no hay Secret nativo), pero requiere driver y provider per-nodo y rompe con controllers que esperan `secretKeyRef`.
- **Vault Agent Injector**: ideal si ya corremos Vault y queremos dynamic secrets con TTL. Añade sidecar por Pod — overhead no trivial.

Para el capstone, el camino de menor fricción con el mejor payoff de seguridad es **ESO + encryption at rest**.
