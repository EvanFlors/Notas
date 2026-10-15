# k8s-09-02 — Proteger un rollout crítico con PDB y anti-afinidad

## 1. Identificación

- **ID:** `k8s-09-02-protect-rollout-with-pdb`
- **Tecnología:** kubernetes
- **Módulo:** `09-scheduling-resources-affinity-taints-pdb`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Un servicio "critical" corre con 3 réplicas en un cluster de 3 workers. Un operador necesita hacer mantenimiento del nodo (parchear kernel, upgrade de kubelet). Si no proteges el servicio, un `kubectl drain` puede quedarse con 1 sola réplica Ready durante minutos — ventana de riesgo inaceptable.

Tu tarea: añadir **anti-afinidad por hostname** (una réplica por nodo) y un **PodDisruptionBudget** que garantice ≥ 2 réplicas durante disrupciones voluntarias. Después debes **demostrar** que un `drain` del nodo donde está una réplica deja al menos 2 Pods Ready en todo momento.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar anti-afinidad `required` por `kubernetes.io/hostname`.
- Escribir un PDB con `minAvailable: 2` para un Deployment de 3 réplicas.
- Verificar `status.disruptionsAllowed: 1` del PDB antes de drenar.
- Ejecutar `kubectl drain` y leer la secuencia de eviction en los eventos.
- Escribir un `NOTES.md` que justifique **por qué** elegiste `minAvailable: 2` y no `maxUnavailable: 1`.

## 4. Prerrequisitos

- `kind` ≥ 0.23 y `docker`.
- `kubectl` ≥ 1.28.
- Puertos del host libres para el apiserver del nuevo cluster.
- Sin costo.

## 5. Instrucciones

> **Independent lab:** el `starter/` contiene TODOs. El `solution/` existe para que el instructor valide; **no la mires** antes de intentarlo.

### Paso 1 — scratch dir y cluster

```bash
rm -rf /tmp/k8s-09-02
mkdir -p /tmp/k8s-09-02
cp -r starter/* /tmp/k8s-09-02/
cd /tmp/k8s-09-02

# Crea un cluster kind de 3 workers (si no existe).
if ! kind get clusters | grep -qx k8s09-act2; then
  kind create cluster --name k8s09-act2 --config kind-3-workers.yaml
fi
kubectl config use-context kind-k8s09-act2
```

### Paso 2 — completa los manifests

Edita `deployment.yaml` para añadir `podAntiAffinity` *required* con `topologyKey: kubernetes.io/hostname`. Edita `pdb.yaml` para crear el `PodDisruptionBudget` según las reglas del comentario interno.

### Paso 3 — aplica

```bash
kubectl create namespace k8s-09-02 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n k8s-09-02 apply -f deployment.yaml
kubectl -n k8s-09-02 apply -f pdb.yaml
kubectl -n k8s-09-02 rollout status deployment/critical --timeout=120s
```

### Paso 4 — verifica estado inicial

```bash
# Las 3 réplicas deben estar en 3 nodos distintos.
kubectl -n k8s-09-02 get pod -l app=critical -o wide

# El PDB debe permitir 1 disrupción.
kubectl -n k8s-09-02 get pdb critical-pdb
```

### Paso 5 — drena un worker y confirma que el PDB se respeta

```bash
NODE=$(kubectl -n k8s-09-02 get pod -l app=critical \
  -o jsonpath='{.items[0].spec.nodeName}')
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s

# Durante el drain, en otra terminal:
# watch kubectl -n k8s-09-02 get pod -l app=critical

# Al terminar: siguen >=2 Pods Ready.
kubectl -n k8s-09-02 get pod -l app=critical
kubectl uncordon "$NODE"
```

### Paso 6 — escribe `/tmp/k8s-09-02/NOTES.md`

Mínimo 5 líneas explicando:

- Por qué `minAvailable: 2` (vs `maxUnavailable: 1`) en este caso.
- Qué pasaría si el Deployment tuviera 2 réplicas en vez de 3.
- Un ejemplo de disrupción **involuntaria** que el PDB *no* protege.

### Paso 7 — valida

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- Deployment `critical` con 3 réplicas Ready, en 3 nodos distintos.
- PDB `critical-pdb` con `minAvailable: 2` y `disruptionsAllowed: 1`.
- Spec del Pod tiene `podAntiAffinity.required... topologyKey: kubernetes.io/hostname`.
- `kubectl drain` del nodo elegido completa sin dejar < 2 réplicas Ready.
- Validador `PASS` con exit 0.

## 7. Criterios de aceptación

- Anti-afinidad **required** por hostname (no preferred).
- `minAvailable: 2` exacto.
- Selector del PDB coincide con el label `app=critical`.
- Durante el drain, `availableReplicas` nunca cae por debajo de 2 (verificable por el validador).

## 8. Validación

```bash
bash tests/validate.sh
# También puedes pasar un namespace alterno:
NS=mi-ns bash tests/validate.sh
```

El validador:

1. Comprueba precondiciones (`kubectl`, cluster).
2. Verifica anti-afinidad y PDB como declarados.
3. Lee los nodeNames: deben ser 3 distintos.
4. Verifica `disruptionsAllowed == 1`.
5. Hace un `kubectl drain` controlado de uno de los nodos y afirma que `availableReplicas` sigue siendo ≥ 2 todo el tiempo.
6. Hace `uncordon` al terminar.

## 9. Preguntas de reflexión

1. Si cambiaras `required` por `preferred` en la anti-afinidad, ¿qué podría pasar en un `drain` con poca capacidad libre?
2. Un operador novato pone `minAvailable: 100%` sobre 3 réplicas. ¿Qué consecuencia tiene para los drains? ¿Para los upgrades automáticos de EKS/GKE?
3. ¿Por qué un PDB no te protege de un OOMKill masivo? ¿Qué sí lo haría?
4. ¿Cuándo preferirías `topologySpreadConstraints` sobre `podAntiAffinity` para esta misma app?

## 10. Extensiones

- Reemplaza `podAntiAffinity` por `topologySpreadConstraints` con `maxSkew: 1`. Verifica que el drain sigue respetando el PDB.
- Añade un `PriorityClass` `critical-online` con `value: 1000000` y asígnalo. Observa el `preempt` creando otro Pod de baja prioridad que no quepa.
- Combina con probes correctas (preview `k8s-10`) y `preStop sleep 10` para que el drain sea *sin downtime*.

## 11. Limpieza

```bash
kubectl delete namespace k8s-09-02 --ignore-not-found
rm -rf /tmp/k8s-09-02
# Opcional:
# kind delete cluster --name k8s09-act2
```
