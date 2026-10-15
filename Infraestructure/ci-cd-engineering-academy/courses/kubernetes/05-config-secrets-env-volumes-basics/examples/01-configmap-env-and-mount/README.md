# Ejemplo 01 — ConfigMap como env y como volume

## Concepto que demuestra

Las dos formas de consumir un `ConfigMap`:

1. **Como env vars** (`envFrom`) — rápido, inmutable para el proceso una vez arrancado.
2. **Como archivos** (`volumeMounts`) — se actualiza en vivo cuando cambia el ConfigMap (sync period del kubelet).

Se contrasta ambos lado a lado en el mismo Pod para que la diferencia sea observable.

## Contexto

Partimos de la premisa del módulo: la misma imagen debe servir para dev/staging/prod cambiando solo el ConfigMap. Al final verás que el env se congela en el `exec` original y el archivo se refresca sin reiniciar el Pod.

## Objetivo

Al terminar sabrás:

- Crear ConfigMaps con `--from-literal` y `--from-env-file`.
- Montar un ConfigMap de las dos maneras simultáneamente.
- Observar que un `kubectl edit configmap` **sí** actualiza el archivo pero **no** la env var.
- Leer el symlink `..data` que mantiene el kubelet.

## Prerrequisitos

- `kind` y `kubectl` instalados (`kind version`, `kubectl version --client`).
- Un cluster local kind arriba (si no, lo creamos en el paso 0). Sin costo.

## Ejecución

Copia-pega bloque a bloque. Lee la salida antes del siguiente.

```bash
# 0. Cluster kind (si no tienes uno).
kind get clusters | grep -qx k8s-05 || kind create cluster --name k8s-05
kubectl cluster-info --context kind-k8s-05

# 1. Namespace de trabajo.
kubectl create namespace demo-cm --dry-run=client -o yaml | kubectl apply -f -

# 2. ConfigMap desde literales.
kubectl -n demo-cm create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-literal=GREETING="hola k8s-05" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n demo-cm get configmap app-config -o yaml
#   Ves data.LOG_LEVEL y data.GREETING en claro (no es Secret, es cleartext legítimo).
```

Aplicamos un Pod que consume el ConfigMap de las dos maneras:

```bash
cat <<'EOF' | kubectl -n demo-cm apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cfg-demo
  labels: { app: cfg-demo }
spec:
  restartPolicy: Never
  containers:
    - name: box
      image: busybox:1.36
      command: ["sh","-c"]
      args:
        - |
          echo "---- env de arranque ----"
          env | sort | grep -E '^(LOG_LEVEL|GREETING)='
          echo "---- archivos montados ----"
          ls -la /etc/app
          echo "---- contenido de los archivos ----"
          for f in /etc/app/*; do echo "== $f =="; cat "$f"; echo; done
          echo "---- symlink ..data que gestiona el kubelet ----"
          ls -la /etc/app/..data
          echo "---- dormir para que puedas inspeccionar ----"
          sleep 3600
      envFrom:
        - configMapRef:
            name: app-config
      volumeMounts:
        - name: cfg
          mountPath: /etc/app
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: app-config
EOF

kubectl -n demo-cm wait --for=condition=Ready pod/cfg-demo --timeout=60s
kubectl -n demo-cm logs cfg-demo
```

Deberías ver `LOG_LEVEL=info`, `GREETING=hola k8s-05`, los dos archivos listados, y un symlink `..data -> ..YYYY_MM_DD_HH_MM_SS.<ULID>`.

Ahora **cambiamos el ConfigMap** y observamos qué pasa:

```bash
kubectl -n demo-cm patch configmap app-config \
  --type merge -p '{"data":{"LOG_LEVEL":"debug","GREETING":"hola otra vez"}}'

# Esperar al sync del kubelet (hasta ~60 s).
sleep 70

# El archivo SÍ cambió:
kubectl -n demo-cm exec cfg-demo -- sh -c 'echo "LOG_LEVEL file: $(cat /etc/app/LOG_LEVEL)"; echo "GREETING file: $(cat /etc/app/GREETING)"'

# El env NO cambió (el proceso original aún tiene los valores viejos):
kubectl -n demo-cm exec cfg-demo -- sh -c 'env | grep -E "^(LOG_LEVEL|GREETING)="'
```

Primer bloque imprime `debug` y `hola otra vez`. Segundo bloque sigue imprimiendo `info` y `hola k8s-05`. **Esa es la lección clave.**

### Equivalente con `--from-env-file`

```bash
cat > /tmp/app.env <<'EOF'
LOG_LEVEL=info
HTTP_PORT=8080
FEATURE_X=on
EOF

kubectl -n demo-cm create configmap app-config2 --from-env-file=/tmp/app.env \
  --dry-run=client -o yaml

# Observa que data tiene 3 claves (LOG_LEVEL, HTTP_PORT, FEATURE_X).
```

## Lo que acabas de ver, resumido

- `envFrom` captura el estado del ConfigMap *en el momento del arranque* del contenedor. Si cambia, el proceso ya corriendo no se entera.
- `volumeMounts` del mismo ConfigMap entrega archivos cuyo contenido se refresca eventualmente (default ~60 s).
- El symlink `..data -> ..YYYY_MM_DD_HH_MM_SS.ULID/` es el truco del kubelet para rotar el contenido atómicamente: hace `rename(2)` del symlink, no reescribe los archivos.

## Limpieza

```bash
kubectl delete namespace demo-cm --wait=false
# Si creaste el cluster para esto y no lo necesitas más:
# kind delete cluster --name k8s-05
```
