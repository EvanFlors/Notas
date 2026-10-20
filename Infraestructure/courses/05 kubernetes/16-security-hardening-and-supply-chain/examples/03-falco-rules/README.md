# Ejemplo 03 — Falco: regla custom "shell in prod container"

Despliega **Falco** como DaemonSet con el driver **eBPF modern** y carga una regla custom que detecta el spawn de una shell dentro de un container del namespace `app`. Dispara la regla con `kubectl exec`.

> **SKIP posible.** Falco requiere un DaemonSet privileged con acceso al kernel. En entornos managed estrictos (EKS/GKE con node pools endurecidos, laptops ARM con kernel sin BTF, etc.) puede no desplegarse. Si el `rollout status` falla, documenta el motivo y continua: PSA y Kyverno siguen siendo las defensas obligatorias.

## Requisitos

- `kind` + `kubectl` + `helm`.
- Kernel con eBPF/BTF (Linux reciente). En macOS/arm64 kind corre sobre VM Linux, suele funcionar.

## Qué contiene

- `falco-install.sh` — instala Falco via Helm con driver `modern-bpf` y carga la regla custom via `customRules`.
- `shell_in_container_custom.yaml` — regla Falco custom (shell spawn en namespace `app`).
- `trigger-alert.sh` — crea un Pod en `app`, lanza `kubectl exec sh` dentro, imprime los logs de Falco donde debe aparecer la alerta.

## Ejecución

```bash
export WORK=/tmp/k8s-16-ex03
mkdir -p "$WORK" && cd "$WORK"
SRC="courses/kubernetes/16-security-hardening-and-supply-chain/examples/03-falco-rules"
cp "$SRC"/*.sh "$SRC"/*.yaml "$WORK"/
chmod +x *.sh

# 1) Instala Falco. Puede fallar: lee la seccion SKIP arriba.
./falco-install.sh

# 2) Dispara la alerta
./trigger-alert.sh

# 3) Observa los logs de Falco (debe aparecer "Shell spawned in prod container")
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=50 | grep -i "shell" || true
```

## Qué aprendiste

- Falco a nivel syscall + eBPF ve `execve` del container antes de que el kernel lo complete.
- Las reglas custom se cargan como ConfigMap (`customRules` en Helm) y Falco las recarga en caliente.
- Correlacionar el syscall con `k8s.ns.name` y `container.image.repository` requiere el metadata enrichment que Falco hace vía el apiserver (watch de pods).

## Limpieza

```bash
kubectl delete -f shell_in_container_custom.yaml --ignore-not-found 2>/dev/null || true
kubectl -n app delete pod shell-target --ignore-not-found
helm uninstall falco -n falco || true
kubectl delete ns falco --ignore-not-found
rm -rf "$WORK"
```
