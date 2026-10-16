# otel-12-01 — Stack OTel completo vía Operator

## 1. Identificación
- **ID:** `otel-12-01-full-otel-stack-via-operator`
- **Tecnología:** opentelemetry
- **Módulo:** `12-otel-operator-in-k8s`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir, declarativamente, el stack que se usa en producción para operar OTel en Kubernetes:

- Un **DaemonSet agent** por nodo que recibe OTLP de las apps locales, enriquece con `k8sattributes` y reenvía al gateway.
- Un **Deployment gateway** central con `batch` + exporter `debug` (en una instalación real sería `otlphttp/tempo`, `prometheusremotewrite/mimir`, etc.).
- Un **Instrumentation** CR que auto-inyecta el SDK de Python en cualquier Pod anotado con `instrumentation.opentelemetry.io/inject-python=true`.
- Una app Python de ejemplo que recibe tráfico y emite spans **sin tocar su imagen**.

El objetivo es *operar* OTel con el camino declarativo, verificar la correlación `app ↔ k8s.*` que da el agent y entender por qué el Operator sustituye a Helm en entornos con muchas instancias.

## 3. Objetivos

Al finalizar debes poder:

- Instalar **cert-manager** y el **OTel Operator** y entender por qué los dos van juntos.
- Diferenciar `mode: deployment` vs `mode: daemonset` en el CR `OpenTelemetryCollector`.
- Explicar qué hace el **mutating webhook** del Operator cuando ve una annotation `inject-python`.
- Observar atributos `k8s.*` adjuntados a spans sin que la app los setee.
- Rodear end-to-end: generar tráfico, ver spans en el gateway.

## 4. Prerrequisitos

- **Conocimientos:** `otel-09` (deployment patterns del Collector) y `k8s-14` (qué es un operador).
- **Software:** `kind` ≥ 0.22, `kubectl` ≥ 1.29, `curl`. Internet para descargar manifests y pull de imágenes.
- **Permisos:** Docker/Podman local. Sin cloud.
- **Costos:** cero.

Comprueba:

```bash
kind version
kubectl version --client
```

Si falta `kind` o `kubectl` → la actividad **no puede ejecutarse en modo real**. El validador detecta esto y reporta `SKIP:` (código 0 — no bloquea el curso).

## 5. Instrucciones

### Setup (una sola vez)

```bash
cd starter/
bash setup.sh
```

Esto crea el cluster `otel-12-lab`, instala cert-manager y el Operator, crea namespaces `observability` y `demo`, y copia los manifests a `/tmp/otel-12-lab/`.

### Paso 1 — Gateway

Lee `starter/manifests/01-gateway.yaml`. Es un `OpenTelemetryCollector` `mode: deployment`. Aplícalo:

```bash
kubectl apply -f /tmp/otel-12-lab/01-gateway.yaml
kubectl -n observability rollout status deploy/gateway-collector --timeout=120s
```

Observa qué objetos creó el Operator:

```bash
kubectl -n observability get otelcol,cm,deploy,svc,sa
```

### Paso 2 — Agent (DaemonSet) con `k8sattributes`

Lee `starter/manifests/02-agent.yaml`. Es un `mode: daemonset` con `k8sattributes` que exporta al gateway. Aplícalo:

```bash
kubectl apply -f /tmp/otel-12-lab/02-agent.yaml
kubectl -n observability rollout status daemonset/agent-collector --timeout=120s
```

Observa el ClusterRole que el Operator generó para `k8sattributes`:

```bash
kubectl get clusterrole -l app.kubernetes.io/managed-by=opentelemetry-operator
```

### Paso 3 — `Instrumentation` CR

Lee `starter/manifests/03-instrumentation.yaml`. Apunta al **agent** (no al gateway), porque es ahí donde está `k8sattributes` y necesita ver la IP source correcta.

```bash
kubectl apply -f /tmp/otel-12-lab/03-instrumentation.yaml
```

### Paso 4 — App Python anotada

```bash
kubectl apply -f /tmp/otel-12-lab/04-pyapp.yaml
kubectl -n demo rollout status deploy/pyapp --timeout=120s
```

Verifica la mutación:

```bash
pod=$(kubectl -n demo get pod -l app=pyapp -o jsonpath='{.items[0].metadata.name}')
kubectl -n demo get pod "$pod" -o jsonpath='{range .spec.initContainers[*]}{.name}{"\n"}{end}'
# Debe listar: opentelemetry-auto-instrumentation-python
```

### Paso 5 — Generar tráfico

```bash
kubectl -n demo port-forward svc/pyapp 18080:8080 >/dev/null 2>&1 &
sleep 2
for i in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:18080/"; done
kill %1
```

### Paso 6 — Observar

Logs del gateway (donde está el `debug` exporter):

```bash
kubectl -n observability logs deploy/gateway-collector --tail=120
```

Deberías ver spans con atributos `k8s.pod.name`, `k8s.namespace.name`, `k8s.node.name`.

### Paso 7 — Validar

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- `OpenTelemetryCollector/gateway` en `observability` en estado Available.
- `OpenTelemetryCollector/agent` en `observability` como DaemonSet (1 pod por nodo).
- `Instrumentation/default-instr` en `demo`.
- `Deployment/pyapp` en `demo` con initContainer `opentelemetry-auto-instrumentation-python`.
- Logs del gateway contienen al menos un span con `k8s.pod.name` = `pyapp-*`.

## 7. Criterios de aceptación

- **Declarativo**: todo se desplegó via CRs; no hubo `kubectl patch` ni edits manuales.
- **Inyección verificada**: initContainer presente, env vars `OTEL_*` presentes en el container de la app.
- **k8sattributes efectivo**: spans en el gateway muestran atributos `k8s.*` que la app no setea.
- **Reproducibilidad**: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

Salida esperada:

```
RESULT: OK
```

o, si falta kind/kubectl:

```
SKIP: ...
```

## 9. Preguntas de reflexión

1. ¿Por qué el `Instrumentation` apunta al agent (DaemonSet) y no al gateway?
2. Si pones `k8sattributes` en el gateway en vez del agent, ¿qué puede fallar? (pista: NAT entre Pod y gateway)
3. ¿Qué pasa si borras `kubectl delete deploy/gateway-collector`? ¿Y si borras el CR?
4. ¿Qué cambios dispararían un rollout del gateway sin tocar el workload (sólo el CR)?
5. ¿En qué momento preferirías Helm en vez del Operator para este mismo stack?

## 10. Extensiones

- Añadir `targetAllocator.enabled: true` a un tercer Collector `mode: statefulset` y migrar un `ServiceMonitor` existente a él.
- Añadir el receiver `k8sobjects` capturando `Events` del cluster y exportarlos como logs al gateway.
- Habilitar `otlphttp` exporter al gateway apuntando a un `tempo` real (compose externo).
- Reemplazar el agent `DaemonSet` por `sidecar` injection y comparar overhead/visibilidad.

## 11. Limpieza

```bash
bash starter/teardown.sh
# o manualmente:
kind delete cluster --name otel-12-lab
rm -rf /tmp/otel-12-lab
```
