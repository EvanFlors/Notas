# Ejemplo 01 — Falco en un cluster `kind`

> Demostración de instalación. **No** es una actividad evaluable; sirve de referencia para la actividad `01-trigger-and-detect-shell-in-pod`.

## Objetivo

Dejar listo en tu máquina (o entender, si estás en macOS puro) el patrón de despliegue:

1. `kind` cluster.
2. Falco DaemonSet con driver `modern_ebpf`.
3. Verificar que el pod de Falco está arriba y leyendo eventos.
4. Provocar un evento conocido y verlo en los logs.

## Nota de plataforma

Falco requiere kernel Linux con BTF (típicamente ≥ 5.8) para `modern_ebpf`. En **macOS con Docker Desktop** la VM subyacente usualmente cumple, pero puede fallar: si tu `kind` no soporta el driver, el ejemplo degrada a lectura del JSON pre-generado en `sample-events.json`.

## 1. Prerrequisitos

```bash
kind version        # >= 0.20
kubectl version --client
helm version        # >= 3.14
```

Si falta alguno, el script `setup.sh` falla con un mensaje claro.

## 2. Script de setup (referencia)

```bash
# examples/01-falco-in-cluster/setup.sh
#
# Idempotente: puedes correrlo múltiples veces.
set -eu

CLUSTER=sec-12-demo

if ! command -v kind >/dev/null 2>&1; then
  echo "SKIP: kind no instalado; este ejemplo requiere kind."
  exit 0
fi

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null
helm repo update >/dev/null

helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set falcosidekick.enabled=false
```

(El script real vive al lado de este README; léelo antes de ejecutarlo.)

## 3. Verificación

```bash
kubectl -n falco get pods
kubectl -n falco logs ds/falco --tail=50
```

Debes ver líneas tipo:

```
Falco version: 0.37.1
Loaded event sources: syscall
Enabled event sources: syscall
```

## 4. Provocar un evento

```bash
kubectl run attacker --image=alpine --restart=Never -- sleep 3600
kubectl exec -it attacker -- sh
# dentro: cat /etc/shadow  (NO sensitive data, es alpine demo)
exit
```

En los logs de Falco:

```
Notice A shell was spawned in a container with an attached terminal
  (user=root user_loginuid=-1 container_id=... image=alpine:latest
   shell=sh parent=runc cmdline=sh terminal=34816) ...
```

## 5. Ejemplo de evento JSON

Ver `sample-events.json` en este directorio: dos eventos reales (uno de `Terminal shell in container`, uno de `Read sensitive file untrusted`) para que la actividad 01 pueda ejercitarse **sin cluster**.

## 6. Limpieza

```bash
helm uninstall -n falco falco || true
kind delete cluster --name sec-12-demo || true
```

## Lo que NO cubre este ejemplo

- Falcosidekick (output a Slack/SIEM). Se trata conceptualmente en la lección §8.
- Reglas custom (ver ejemplo 02).
- Enforcement (Falco no enforce; ver ejemplo 03 con Tetragon).
