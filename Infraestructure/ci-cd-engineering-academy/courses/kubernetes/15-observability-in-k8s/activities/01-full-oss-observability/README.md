# Actividad 01 — Stack OSS completo de observabilidad

## 1. Identificación

- **ID:** `k8s-15-01-full-oss-observability`
- **Tecnología:** `kubernetes`
- **Módulo:** `15-observability-in-k8s`
- **Dificultad:** advanced
- **Duración estimada:** 120–180 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a levantar en una sola sesión el stack OSS canónico de observabilidad para Kubernetes: **Prometheus Operator + Grafana + Loki + Tempo + OpenTelemetry Operator**. El objetivo no es memorizar comandos, sino **ver las piezas juntas**, entender qué CRs crea cada operador y cómo se integran en Grafana como panel único.

Este laboratorio sucede en un cluster **kind** local. Es un stack pesado: pedí al menos **4 GB RAM libres** para Docker. Si tu host no tiene recursos o te falta `helm`/`docker`, el validador degrada con `SKIP` y el ejercicio es parcial pero igual aprovechable (podés leer manifests y runbooks).

## 3. Objetivos

- Automatizar la secuencia completa en `starter/bootstrap.sh`:
  1. Crear cluster kind.
  2. Instalar `kube-prometheus-stack` (Prometheus + Alertmanager + Grafana + KSM + node-exporter + mixin).
  3. Instalar **Loki** + **Promtail** vía Helm.
  4. Instalar **cert-manager** + **OpenTelemetry Operator** + **Tempo** (ejemplo 03 reutilizable).
  5. Esperar `Ready` de cada stack con timeouts explícitos.
- Verificar presencia de CRs y Pods con `kubectl` desde `tests/validate.sh`.
- Soportar flag `--dry-run` que imprime los pasos sin ejecutarlos (útil para evaluar sin host).

## 4. Prerrequisitos

- `docker` corriendo con **≥ 4 GB RAM** disponibles.
- `kind` ≥ 0.22, `kubectl` ≥ 1.28, `helm` ≥ 3.14.
- Haber completado los **tres ejemplos** del módulo.

**Costos**: cero (todo local).

## 5. Instrucciones

### 5.1 Explorar `starter/bootstrap.sh`

```bash
cd courses/kubernetes/15-observability-in-k8s/activities/01-full-oss-observability
cat starter/bootstrap.sh
```

Ya trae el esqueleto con `# TODO` para cada stack. Rellenalos uno por uno.

### 5.2 Rellenar los TODOs

- **TODO 1** — `kind create cluster --name obs15 --config starter/kind.yaml`.
- **TODO 2** — `helm install kps prometheus-community/kube-prometheus-stack …`.
- **TODO 3** — `helm install loki grafana/loki --set-string "deploymentMode=SingleBinary" …` y `helm install promtail grafana/promtail …`.
- **TODO 4** — reutilizar lo del ejemplo 03: cert-manager + OTel Operator + Tempo + Collector.
- **TODO 5** — `kubectl wait --for=condition=Ready` por stack.

Cada paso debe:
- **No fallar** si la herramienta no está (echo "SKIP: helm not found", `return 0`).
- **Reportar** `PASS`/`SKIP`/`FAIL` por stack al final.

### 5.3 Correr el bootstrap

```bash
bash starter/bootstrap.sh
```

Lleva ~8-15 min según red y disco. Si todo va bien terminás con `PASS=5 FAIL=0 SKIP=0` (o algún `SKIP` si falta algún tool).

### 5.4 Validar

```bash
bash tests/validate.sh
```

El validador detecta:
- Si `kubectl` no está → `SKIP` todo.
- Si no hay cluster `obs15` → marca `missing` y permite `--allow-skip` (ya lo hace: si no hay cluster, no es FAIL duro).
- Si el cluster está, chequea namespaces (`monitoring`, `tracing`, `apps`, `cert-manager`, `opentelemetry-operator-system`), Pods `Ready`, y presencia de CRs (`Prometheus`, `Alertmanager`, `ServiceMonitor`, `OpenTelemetryCollector`, `Instrumentation`).

### 5.5 Explorar

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
# user: admin, password del secret kps-grafana
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
```

En Grafana → Explore debés ver 3 datasources: Prometheus, Loki, Tempo.

## 6. Resultado esperado

- Cluster `obs15` con 3 nodos.
- Namespaces `monitoring`, `logging`, `tracing`, `cert-manager`, `opentelemetry-operator-system` con Pods `Ready`.
- Al menos los CRs: `prometheuses.monitoring.coreos.com/kps-kube-prometheus-stack-prometheus`, `alertmanagers.monitoring.coreos.com/*`, `≥ 1 servicemonitor`, `opentelemetrycollectors.opentelemetry.io/*`, `instrumentations.opentelemetry.io/*`.
- `bash tests/validate.sh` termina con `OK` **o** con `SKIP` claro y explicado.

## 7. Criterios de aceptación

- [ ] Funcional: cada stack queda `Ready` sin intervención manual tras `bootstrap.sh`.
- [ ] Idempotente: dos corridas seguidas no rompen (uso de `|| true` donde corresponde y `helm upgrade --install`).
- [ ] Degradación: binarios ausentes → `SKIP` por paso, nunca kill del script.
- [ ] Observable: el script imprime un **resumen por stack** al final.
- [ ] Limpieza explícita: existe `starter/teardown.sh`.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador imprime `OK` / `WARN` / `FAIL` por categoría y termina con `exit 0` si todo lo verificable pasó, o `exit 1` si algo verificable falló.

## 9. Preguntas de reflexión

1. ¿Por qué el `ServiceMonitor` necesita el label `release=kps`? ¿Qué pasa si lo cambiás?
2. En kind, `kube-controller-manager` suele aparecer `DOWN` en Prometheus Targets. ¿Por qué? ¿Cómo se arregla?
3. ¿Qué rompería si Promtail no tuviera permisos para leer `/var/log/pods` en el nodo?
4. El OTel Operator exige cert-manager. ¿Por qué? ¿Qué firma qué?
5. Si quisieras llevar este stack a producción multicluster, ¿qué cambiarías primero: Prometheus local o Loki local?

## 10. Extensiones

- **E1** — Añadir **Hubble** (requiere migrar CNI a Cilium — no trivial).
- **E2** — Añadir **kubernetes-event-exporter** enviando a Loki.
- **E3** — Cargar un dashboard custom (JSON) vía ConfigMap con label `grafana_dashboard=1`.
- **E4** — Exponer todo detrás de ingress-nginx con TLS auto-firmado por cert-manager.

## 11. Limpieza

```bash
bash starter/teardown.sh
```

Que borra releases Helm, namespaces y por último el cluster kind.
