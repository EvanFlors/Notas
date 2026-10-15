# Actividad 01 — ¿Por qué está mi Pod en `Pending`?

## 1. Identificación

- **ID:** `k8s-11-01-why-is-pod-pending`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-11-control-plane-internals`
- **Dificultad:** advanced
- **Duración estimada:** 30–45 min
- **Tipo:** independent (debug)

## 2. Contexto

Un Pod lleva varios minutos `Pending`. No hay logs del container (nunca arrancó). El `describe` tiene información concreta — pero hay que **leerla** y seguir la cadena hasta el componente del control plane responsable.

Esta actividad es **independiente**: no leas la solución hasta terminar. El validator decide si tu `ANALYSIS.md` cubre la cadena de causa raíz.

## 3. Objetivos

- Reproducir el síntoma: Pod en `Pending` indefinido.
- Usar `kubectl describe pod` + `kubectl events` + `kubectl -n kube-system logs -l component=kube-scheduler` para localizar la causa raíz.
- Mapear el mensaje de error a un **plugin del scheduling framework**.
- Escribir un `ANALYSIS.md` corto (3–6 bullets) con la cadena: síntoma → componente → plugin → regla concreta del YAML → fix.

## 4. Prerrequisitos

- `kubectl` ≥ 1.28.
- `kind` + `docker` para cluster local (o cualquier otro cluster manejable).
- Opcional: `jq`.
- Costos: ninguno.

## 5. Instrucciones

### 5.1 Reproducir el bug

Desde la raíz de la actividad:

```bash
bash starter/create-pending-pod.sh
```

Esto:

- Crea (si no existe) un cluster `kind` llamado `k8s11-pending`.
- Aplica un Pod `pending-mystery` con un `nodeSelector` imposible de cumplir.
- No te dice **cuál** es el campo problemático. Tú lo averiguas.

Verifica el síntoma:

```bash
kubectl get pod pending-mystery
# NAME              READY   STATUS    RESTARTS   AGE
# pending-mystery   0/1     Pending   0          30s
```

### 5.2 Investigar

Preguntas que tu `ANALYSIS.md` debe responder:

1. ¿Qué dice la última línea del `kubectl describe pod pending-mystery`?
2. ¿Qué **plugin del scheduler** emite ese mensaje? (pista: tabla del `examples/03`).
3. ¿Qué campo del `spec` del Pod está causando el problema?
4. ¿Cuál es la cadena del control plane que lleva de "escribo el YAML" a "el scheduler no bindea"? (apiserver → persistencia → scheduler watch → filter fail → event).
5. ¿Qué fix mínimo lo resolvería *sin* modificar el workload? (pista: etiquetar un nodo).
6. (Opcional) ¿Qué fix sería preferible a largo plazo? (modificar el workload, usar affinity con `preferredDuringScheduling`, etc.).

### 5.3 Entregar

Crea el archivo `/tmp/kube-pending/ANALYSIS.md` con tus hallazgos. **Debe contener** estas frases (el validator las busca):

- `Pending`
- `FailedScheduling`
- `nodeSelector` (o `node affinity/selector` tal como aparece en el event)
- `NodeAffinity` (nombre del plugin)
- `kube-scheduler`

También dumpea evidencia:

```bash
mkdir -p /tmp/kube-pending
kubectl describe pod pending-mystery > /tmp/kube-pending/describe.txt
kubectl get events --field-selector involvedObject.name=pending-mystery \
  -o wide > /tmp/kube-pending/events.txt
```

Luego valida:

```bash
bash tests/validate.sh
```

### 5.4 Pistas (ordenadas de menor a mayor)

<details><summary>Pista 1 — por dónde empezar</summary>

```bash
kubectl describe pod pending-mystery | tail -20
```

Mira la sección **Events** al final. El scheduler emite `Warning  FailedScheduling` con el motivo.

</details>

<details><summary>Pista 2 — qué plugin</summary>

El mensaje `node(s) didn't match Pod's node affinity/selector` lo emite el plugin **`NodeAffinity`** del scheduling framework. Ver `examples/03-scheduler-plugin-skeleton/README.md`.

</details>

<details><summary>Pista 3 — qué campo del Pod</summary>

```bash
kubectl get pod pending-mystery -o yaml | grep -A3 nodeSelector
```

El `nodeSelector` pide una label `disktype=unobtanium-xyz` que ningún nodo del cluster tiene.

</details>

<details><summary>Pista 4 — fix sin tocar el workload</summary>

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl label node "$NODE" disktype=unobtanium-xyz
```

En segundos el scheduler re-evalúa y el Pod pasa a `Running`.

</details>

## 6. Resultado esperado

- `pending-mystery` existe y está `Pending` por `nodeSelector` imposible.
- `/tmp/kube-pending/describe.txt` y `events.txt` capturados.
- `/tmp/kube-pending/ANALYSIS.md` contiene las 5 frases clave y describe la cadena de causa raíz.
- `bash tests/validate.sh` termina en `OK`.

## 7. Criterios de aceptación

- [ ] El Pod sigue en `Pending` cuando corres el validator (no "lo arreglaste" antes de documentar).
- [ ] `ANALYSIS.md` menciona el plugin `NodeAffinity`, el componente `kube-scheduler`, el verbo `FailedScheduling` y el campo `nodeSelector`.
- [ ] `ANALYSIS.md` propone al menos un fix (etiquetar nodo *o* cambiar el workload).

## 8. Validación

```bash
bash tests/validate.sh
```

En entornos sin `kubectl`/`kind`/cluster, el validator imprime `SKIP` y exit 0.

## 9. Preguntas de reflexión

1. ¿Por qué el scheduler no reintenta "infinitas" veces de inmediato? ¿Cómo se re-encola el Pod? (pista: `backoff`, `informer resync`, cambios en Node).
2. ¿Qué cambia si usas `requiredDuringSchedulingIgnoredDuringExecution` vs un `nodeSelector` plano?
3. Si el filtro falla por `Insufficient cpu`, ¿qué plugin es? ¿Cómo lo diagnosticas sin adivinar?
4. ¿Qué pasaría si tu Pod tiene una **PriorityClass** alta: podría forzar `preemption`? ¿Qué plugin la implementa?
5. ¿Cómo pedirías al `kube-scheduler` que logee en `-v=4` para ver cada ciclo? (pista: en `kind`, editar el static Pod manifest en `/etc/kubernetes/manifests/kube-scheduler.yaml` dentro del contenedor del nodo).

## 10. Extensiones (opcional)

- **E1** — Añade un segundo nodo (`kind create cluster` con `--config` de 2 nodos) y comprueba que el scheduler lo re-evalúa automáticamente al etiquetarlo.
- **E2** — Reproduce `FailedScheduling` por `Insufficient memory`: pide un Pod con `requests.memory: 10Gi` en un cluster de 2Gi. Observa el nuevo mensaje y mapéalo a `NodeResourcesFit`.
- **E3** — Añade un **taint** al nodo (`kubectl taint node <n> dedicated=batch:NoSchedule`) y aplica un Pod sin toleration. Mapea al plugin `TaintToleration`.

## 11. Limpieza

```bash
kubectl delete pod pending-mystery --ignore-not-found
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$NODE" ]; then
  kubectl label node "$NODE" disktype- 2>/dev/null || true
fi
rm -rf /tmp/kube-pending
# opcional: kind delete cluster --name k8s11-pending
```
