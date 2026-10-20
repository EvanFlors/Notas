# Ejemplo 03 — Tetragon `TracingPolicy` con enforcement

> Demostración. Igual que el ejemplo 01, requiere kernel Linux real (eBPF/BTF). En macOS puede fallar según la VM de Docker; en ese caso lee el ejemplo como walkthrough.

## Objetivo

Mostrar cómo una `TracingPolicy` de Tetragon:

1. Observa un evento (`openat` sobre `/etc/shadow`).
2. **Mata** el proceso con `Sigkill` — enforcement real, no sólo alerta.

Y por contraste con Falco (ejemplo 02): Falco **genera un evento**; Tetragon **actúa**.

## 1. Prerrequisitos

```bash
kind version
kubectl version --client
helm version
```

Si tienes el `kind` del ejemplo 01, reutilízalo.

## 2. Instalar Tetragon (referencia)

```bash
helm repo add cilium https://helm.cilium.io
helm repo update

helm upgrade --install tetragon cilium/tetragon \
  --namespace kube-system
```

Verifica:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=tetragon
```

## 3. Aplicar la policy

Ver `tracingpolicy.yaml` en este directorio. Resumen:

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-shadow-read
spec:
  kprobes:
    - call: "security_file_permission"
      syscall: false
      args:
        - index: 0
          type: "file"
        - index: 1
          type: "int"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Equal"
              values:
                - "/etc/shadow"
            - index: 1
              operator: "Mask"
              values:
                - "4"
          matchActions:
            - action: Sigkill
```

Clave:

- `kprobes` sobre `security_file_permission` (hook LSM): capturamos **antes** de que el acceso ocurra.
- `matchArgs` filtra: solo `/etc/shadow` con intento de lectura (`MAY_READ = 4`).
- `matchActions: Sigkill` → el proceso que intente leerlo muere.

## 4. Aplicar y probar

```bash
kubectl apply -f tracingpolicy.yaml

kubectl run victim --image=alpine --restart=Never -- sleep 3600
kubectl exec -it victim -- cat /etc/shadow
# Esperado: el shell muere; el pod sigue vivo pero el proceso no.
```

Logs de Tetragon:

```bash
kubectl -n kube-system exec ds/tetragon -c tetragon -- \
  tetra getevents -o compact | grep shadow
```

## 5. Revertir

```bash
kubectl delete tracingpolicy block-shadow-read
```

Ese es el modelo de rollback: una `TracingPolicy` es un CRD; borrarlo deshace el enforcement **sin reiniciar nada**.

## 6. Decisión: ¿detectar o bloquear?

| Caso | Elección |
|------|----------|
| Lectura de `/etc/shadow` desde cualquier Pod de app | **Bloquear** (Tetragon). Nunca hay caso legítimo. |
| `exec` de un shell en un Pod de app | **Alertar** (Falco). Puede ser debug legítimo. |
| Carga de módulo kernel desde Pod | **Bloquear**. |
| `connect` a IP no en allowlist | **Alertar** primero; bloquear sólo si el allowlist es estable. |

La regla general del módulo: **nunca** empezar en modo enforce global. Pasa pieza a pieza.

## 7. Limpieza

```bash
kubectl delete tracingpolicy block-shadow-read || true
helm uninstall -n kube-system tetragon || true
```
