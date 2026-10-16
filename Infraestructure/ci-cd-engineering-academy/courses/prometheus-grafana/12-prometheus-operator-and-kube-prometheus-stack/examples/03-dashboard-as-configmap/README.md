# Example 03 — Dashboard de Grafana como ConfigMap

El sidecar `k8s-sidecar` que corre dentro del Pod de Grafana vigila ConfigMaps con una label (por default `grafana_dashboard=1`) y las carga como dashboards sin reiniciar.

Esto permite tratar los dashboards como código: viven en un repo Git, Argo CD los aplica, Grafana los recoge solo.

## Paso 1 — Un dashboard JSON mínimo

Un dashboard con un panel que grafica `rate(http_requests_total[1m])` desde el ejemplo 02.

```bash
cat >/tmp/fastapi-dashboard.json <<'EOF'
{
  "annotations": {"list": []},
  "editable": true,
  "panels": [
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "type": "timeseries",
      "title": "FastAPI RPS",
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0},
      "id": 1,
      "targets": [
        {
          "expr": "sum by (job) (rate(http_requests_total[1m]))",
          "refId": "A"
        }
      ]
    }
  ],
  "schemaVersion": 39,
  "style": "dark",
  "tags": ["fastapi", "demo"],
  "templating": {"list": []},
  "time": {"from": "now-15m", "to": "now"},
  "timezone": "",
  "title": "FastAPI Demo",
  "uid": "fastapi-demo",
  "version": 1
}
EOF
```

## Paso 2 — Crear la ConfigMap con la label

**La label `grafana_dashboard=1` es lo que activa el sidecar.** Sin ella el ConfigMap existe pero Grafana lo ignora.

```bash
kubectl -n monitoring create configmap fastapi-dashboard \
  --from-file=fastapi-dashboard.json=/tmp/fastapi-dashboard.json

kubectl -n monitoring label configmap fastapi-dashboard grafana_dashboard=1
```

Verificar:

```bash
kubectl -n monitoring get cm fastapi-dashboard --show-labels
```

## Paso 3 — Ver que Grafana lo cargó

Los logs del sidecar lo deben mencionar:

```bash
kubectl -n monitoring logs deploy/kps-grafana -c grafana-sc-dashboard --tail=50 \
  | grep fastapi-dashboard
```

En la UI:

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
# http://localhost:3000  (admin/admin) → Dashboards → busca "FastAPI Demo"
```

## Patrón GitOps

El equivalente declarativo es un fichero YAML versionado:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fastapi-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  fastapi-dashboard.json: |
    { ... JSON ... }
```

Con Argo CD, el repo contiene `.json` y un `kustomization.yaml` que los convierte en ConfigMap:

```yaml
# kustomization.yaml
configMapGenerator:
  - name: fastapi-dashboard
    files:
      - fastapi-dashboard.json
    options:
      labels:
        grafana_dashboard: "1"
```

## Limpieza

```bash
pkill -f "port-forward svc/kps-grafana" 2>/dev/null || true
kubectl -n monitoring delete configmap fastapi-dashboard
rm -f /tmp/fastapi-dashboard.json
```
