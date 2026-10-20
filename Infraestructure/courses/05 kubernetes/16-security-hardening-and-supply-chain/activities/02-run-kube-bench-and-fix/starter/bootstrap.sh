#!/usr/bin/env bash
# Bootstrap para k8s-16-02-run-kube-bench-and-fix.
set -euo pipefail

BASE="${1:-/tmp/k8s-16-02}"

if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi

WORK="$BASE/work"
mkdir -p "$WORK"

# --- kube-bench Job: ejecuta checks sobre el nodo donde corre el Pod. ---
cat > "$WORK/kube-bench-job.yaml" <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
spec:
  backoffLimit: 1
  template:
    spec:
      hostPID: true
      restartPolicy: Never
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:latest
          command: ["kube-bench", "run"]
          securityContext:
            privileged: true
          volumeMounts:
            - { name: var-lib-etcd,         mountPath: /var/lib/etcd,       readOnly: true }
            - { name: var-lib-kubelet,      mountPath: /var/lib/kubelet,    readOnly: true }
            - { name: etc-systemd,          mountPath: /etc/systemd,        readOnly: true }
            - { name: etc-kubernetes,       mountPath: /etc/kubernetes,     readOnly: true }
            - { name: usr-bin,              mountPath: /usr/local/mount-from-host/bin, readOnly: true }
      volumes:
        - { name: var-lib-etcd,    hostPath: { path: /var/lib/etcd } }
        - { name: var-lib-kubelet, hostPath: { path: /var/lib/kubelet } }
        - { name: etc-systemd,     hostPath: { path: /etc/systemd } }
        - { name: etc-kubernetes,  hostPath: { path: /etc/kubernetes } }
        - { name: usr-bin,         hostPath: { path: /usr/bin } }
EOF

# --- REMEDIATIONS.md: plantilla con placeholders ---
cat > "$WORK/REMEDIATIONS.md" <<'EOF'
# Top-3 remediaciones de kube-bench

> Reemplaza TODO: y <rellena> por prosa real. Elimina ESTAS lineas iniciales
> una vez termines, o dejalas: el validador no las usa.

## Resumen

- PASS: TODO: <N>
- FAIL: TODO: <N>
- WARN: TODO: <N>
- Fuente: `kube-bench.out` (generado por el Job).

---

### H1 — <id CIS> <titulo corto>

**Hallazgo**
<rellena 2+ lineas con el ID y descripcion exacta del benchmark>

**Mecanismo**
<rellena 2+ lineas con la primitiva de K8s/Linux involucrada>

**Impacto**
<rellena 2+ lineas con lo que un atacante puede lograr; severidad justificada>

**Remediacion**
<rellena 2+ lineas con flag/manifest/comando concreto + como verificar>

---

### H2 — <id CIS> <titulo corto>

**Hallazgo**
<rellena 2+ lineas>

**Mecanismo**
<rellena 2+ lineas>

**Impacto**
<rellena 2+ lineas>

**Remediacion**
<rellena 2+ lineas>

---

### H3 — <id CIS> <titulo corto>

**Hallazgo**
<rellena 2+ lineas>

**Mecanismo**
<rellena 2+ lineas>

**Impacto**
<rellena 2+ lineas>

**Remediacion**
<rellena 2+ lineas>
EOF

echo "Bootstrap OK en $WORK"
echo "Siguiente paso: aplicar kube-bench-job.yaml y editar REMEDIATIONS.md."
