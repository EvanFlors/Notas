# Ejemplo 02 — Secret como env vs como archivo (y base64 ≠ encrypted)

## Concepto que demuestra

Tres cosas a la vez:

1. Cómo consumir un `Secret` **como env var** y **como archivo montado** en el mismo Pod.
2. Que un Secret **no está cifrado**: `kubectl get secret -o jsonpath` + `base64 -d` lo revela en una línea.
3. Que un Secret como env var es **trivialmente filtrable**: `kubectl exec env`, `/proc/<pid>/environ`, child processes.

## Contexto

Este ejemplo materializa el núcleo del módulo. Si solo haces uno, haz este. Repítelo hasta que el "base64 ≠ encryption" se te quede.

**Importante**: los valores son *dummies*. Nunca uses credenciales reales en ejemplos educativos.

## Objetivo

Al terminar sabrás:

- Crear un `Secret` tipo `Opaque` y leer sus valores decodificados.
- Montarlo como env var y como archivo a la vez.
- Demostrar en vivo que `base64` no es cifrado.
- Enumerar al menos tres rutas de leak de un env Secret.

## Prerrequisitos

- `kind` + `kubectl` + `base64`.
- Cluster kind arriba (creamos uno si no existe).

## Ejecución

```bash
# 0. Cluster y namespace.
kind get clusters | grep -qx k8s-05 || kind create cluster --name k8s-05
kubectl create namespace demo-sec --dry-run=client -o yaml | kubectl apply -f -
```

### Paso 1 — crear el Secret

```bash
kubectl -n demo-sec create secret generic db \
  --from-literal=username=app \
  --from-literal=password='dummy-not-real-ABC123' \
  --dry-run=client -o yaml | tee /tmp/db-secret.yaml

#   Mira el YAML: data.username y data.password están en BASE64, no cifrados.
#   stringData hubiera convertido automáticamente; data lo quiere ya codificado.

kubectl -n demo-sec apply -f /tmp/db-secret.yaml
```

### Paso 2 — "descifrar" el Secret en una línea

```bash
# Vía kubectl + base64 -d:
kubectl -n demo-sec get secret db -o jsonpath='{.data.password}' | base64 -d; echo
#   Imprime "dummy-not-real-ABC123" en claro.

# Vía kubectl get -o yaml y ojo humano:
kubectl -n demo-sec get secret db -o yaml
#   Verás data.password: ZHVtbXktbm90LXJlYWwtQUJDMTIz   (base64)
echo ZHVtbXktbm90LXJlYWwtQUJDMTIz | base64 -d; echo
```

Punto crucial: cualquier `ServiceAccount` con `get secrets` en este namespace ve esto. Y en un backup de etcd *sin* `EncryptionConfiguration`, estos bytes están igual.

### Paso 3 — Pod que lo consume de las dos maneras

```bash
cat <<'EOF' | kubectl -n demo-sec apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sec-demo
spec:
  restartPolicy: Never
  containers:
    - name: box
      image: busybox:1.36
      command: ["sh","-c","sleep 3600"]
      env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef: { name: db, key: username }
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef: { name: db, key: password }
      volumeMounts:
        - name: db-cred
          mountPath: /etc/app/secret
          readOnly: true
  volumes:
    - name: db-cred
      secret:
        secretName: db
        defaultMode: 0400
EOF

kubectl -n demo-sec wait --for=condition=Ready pod/sec-demo --timeout=60s
```

### Paso 4 — demostrar la fuga por env

```bash
# El contenedor imprime su propio env (ruta de leak #1):
kubectl -n demo-sec exec sec-demo -- env | grep ^DB_
#   DB_USERNAME=app
#   DB_PASSWORD=dummy-not-real-ABC123   <-- en claro, dentro del Pod

# kubectl describe pod revela los REFS (ruta de leak #2):
kubectl -n demo-sec describe pod sec-demo | sed -n '/Environment:/,/^[A-Z]/p' | head -20
#   No muestra el valor directo, pero sí "DB_PASSWORD: <set to the key 'password' in secret 'db'>".
#   Con RBAC a `get secrets` el valor es público en un comando más.

# /proc/<pid>/environ del PID 1 (ruta de leak #3):
kubectl -n demo-sec exec sec-demo -- sh -c 'cat /proc/1/environ | tr "\0" "\n" | grep ^DB_'

# Child process hereda el env (ruta de leak #4):
kubectl -n demo-sec exec sec-demo -- sh -c 'sh -c env | grep ^DB_'
```

### Paso 5 — contrastar con el archivo

```bash
# El archivo existe solo en tmpfs del Pod, con mode 0400:
kubectl -n demo-sec exec sec-demo -- ls -la /etc/app/secret
kubectl -n demo-sec exec sec-demo -- cat /etc/app/secret/password; echo

# Pero NO está en el env de ningún proceso:
kubectl -n demo-sec exec sec-demo -- sh -c 'env | grep -c dummy || echo "0 (archivo nunca llegó al env)"'
#   Debe decir "0 (archivo nunca llegó al env)" si el único leak era por env.
#   (Nota: en este Pod SÍ tienes DB_PASSWORD como env además — ese es el leak.)
```

### Paso 6 — mostrar `..data` y el symlink

```bash
kubectl -n demo-sec exec sec-demo -- ls -la /etc/app/secret
#   Verás algo como:
#     ..data -> ..2026_10_15_12_34_56.AbCdEf...
#     password -> ..data/password
#     username -> ..data/username
```

## Lo que acabas de ver, resumido

- Un `Secret` **no cifra nada por default**: base64 es *encoding*, no *encryption*.
- Un Secret como env var se filtra por al menos 4 rutas verificadas acá.
- Un Secret como archivo montado minimiza esos vectores (nunca entra al `environ` del proceso).
- Para cifrado real en etcd, hace falta `EncryptionConfiguration` (sección 9 de la lección) o delegar a un **secret manager externo** (ejemplo 03).

## Limpieza

```bash
kubectl delete namespace demo-sec --wait=false
rm -f /tmp/db-secret.yaml
# kind delete cluster --name k8s-05   # opcional
```
