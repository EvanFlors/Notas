# Ejemplo 04 — Métricas Prometheus del application-controller

## Concepto que demuestra

Exponer `/metrics` del `argocd-application-controller`, raspar con `curl`, identificar las métricas clave y cargar un dashboard oficial de Grafana.

## Contexto

Argo CD es un sistema distribuido. "Mis apps están sanas" no implica "Argo CD está sano". Necesitas visibilidad sobre latencia de reconciliación, errores Git, backlog del worker, cardinalidad de apps.

## Objetivo

- Verificar que los puertos de métricas están abiertos.
- Leer con `curl` las métricas más relevantes.
- Entender qué significa cada una.
- Importar un dashboard oficial (Grafana ID 14584 o 19993).

## Prerrequisitos

- Argo CD operativo en `argocd` namespace.
- `kubectl` acceso al cluster.
- Opcional: Prometheus Operator + Grafana para el dashboard real.

## Exponer y leer `/metrics`

```bash
# Verificar servicios con los puertos oficiales
kubectl -n argocd get svc | grep metrics

# Puerto típico del application-controller: 8082
kubectl -n argocd port-forward svc/argocd-metrics 8082:8082 >/tmp/pf.log 2>&1 &
PF=$!
sleep 2

# Raspar
curl -s http://localhost:8082/metrics > /tmp/argocd-metrics.txt
wc -l /tmp/argocd-metrics.txt
```

Métricas clave a buscar (ejemplos reales):

```bash
# Estado de cada Application
grep '^argocd_app_info' /tmp/argocd-metrics.txt | head

# Latencia de reconciliación (histograma)
grep '^argocd_app_reconcile_bucket' /tmp/argocd-metrics.txt | head
grep '^argocd_app_reconcile_count' /tmp/argocd-metrics.txt | head

# Syncs por fase (Succeeded/Failed/Error)
grep '^argocd_app_sync_total' /tmp/argocd-metrics.txt | head

# Backlog del reconciler
grep '^workqueue_depth' /tmp/argocd-metrics.txt | head

# Clusters conectados
grep '^argocd_cluster_info' /tmp/argocd-metrics.txt | head

# Requests Git
grep '^argocd_git_request_total' /tmp/argocd-metrics.txt | head
```

Terminar port-forward:

```bash
kill $PF 2>/dev/null || true
```

## ServiceMonitor (Prometheus Operator)

Si tienes `kube-prometheus-stack` instalado:

```yaml
# /tmp/argo-12-ex04/servicemonitors.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels: { release: kube-prometheus-stack }
spec:
  selector:
    matchLabels: { app.kubernetes.io/name: argocd-metrics }
  endpoints:
    - port: metrics
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: argocd
  labels: { release: kube-prometheus-stack }
spec:
  selector:
    matchLabels: { app.kubernetes.io/name: argocd-server-metrics }
  endpoints:
    - port: metrics
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  namespace: argocd
  labels: { release: kube-prometheus-stack }
spec:
  selector:
    matchLabels: { app.kubernetes.io/name: argocd-repo-server }
  endpoints:
    - port: metrics
      interval: 30s
```

```bash
kubectl apply -f /tmp/argo-12-ex04/servicemonitors.yaml
```

## Dashboards Grafana

- **ID 14584** — "ArgoCD" (comunidad, resumen general).
- **ID 19993** — "Argo CD Operational" (denso, SRE-oriented).

En Grafana: *Dashboards → Import → ID → selecciona Prometheus datasource*.

## Alertas mínimas (PrometheusRule)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: argocd
spec:
  groups:
    - name: argocd
      rules:
        - alert: ArgoCDAppDegraded
          expr: argocd_app_info{health_status="Degraded"} == 1
          for: 10m
          labels: { severity: warning }
          annotations:
            summary: "Application {{ $labels.name }} is Degraded >10m"
        - alert: ArgoCDAppSyncFailed
          expr: increase(argocd_app_sync_total{phase="Failed"}[15m]) > 3
          for: 5m
          labels: { severity: warning }
        - alert: ArgoCDReconcileSlow
          expr: histogram_quantile(0.99, sum(rate(argocd_app_reconcile_bucket[5m])) by (le)) > 60
          for: 10m
          labels: { severity: warning }
```

## Lectura rápida de las métricas

| Métrica | Qué dice | Alerta razonable |
|---|---|---|
| `argocd_app_info{health_status}` | Estado por app | `Degraded` > 10 min |
| `argocd_app_reconcile_bucket` | Latencia de reconciliación | p99 > 60s por 10 min |
| `argocd_app_sync_total{phase="Failed"}` | Syncs que fallan | > 3 en 15 min |
| `workqueue_depth` | Backlog del worker | > 100 sostenido 10 min |
| `argocd_git_request_total{response_code=~"5.."}` | Errores Git | tasa > 0.1/s por 10 min |
| `argocd_cluster_info{server}` | Clusters conectados, caché age | caché age > 5 min |

## Limpieza

```bash
kubectl -n argocd delete servicemonitor argocd-metrics argocd-server-metrics argocd-repo-server-metrics --ignore-not-found
rm -rf /tmp/argo-12-ex04 /tmp/argocd-metrics.txt /tmp/pf.log
```

## Qué aprender

- Argo CD mismo tiene SLOs: define al menos *reconciliation freshness* y *sync success rate*.
- Dashboards oficiales ahorran semanas de trabajo; parte de ahí, no de cero.
- Si no monitoreas el `repo-server`, no verás por qué una app con `targetRevision: HEAD` tarda en reflejar un commit (polling o webhook).
- Cardinalidad: con muchas Applications, aplica `metricRelabelings` para evitar explosión de series.
