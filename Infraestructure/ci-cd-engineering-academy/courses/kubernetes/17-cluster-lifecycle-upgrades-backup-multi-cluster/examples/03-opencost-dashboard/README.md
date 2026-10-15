# Ejemplo 03 — OpenCost en kind (walkthrough de FinOps cluster-side)

> Walkthrough de instalación de **OpenCost** (proyecto CNCF, OSS) sobre un cluster kind. Explica qué atribuye, qué le falta y cuándo usar **Kubecost** (producto comercial encima) en producción.

## Qué demuestra

- Instalación del chart Helm `opencost` con Prometheus mínimo.
- UI con asignación de costo por namespace / workload (en kind el costo es *pricing público ficticio*; en producción se consume de AWS CUR / GCP Billing Export).
- Patrón mental: "requests + usage × precio → USD por namespace".
- Comparación OpenCost vs Kubecost (free tier).

**Nota**: en kind los números de USD son estimativos basados en pricing público de AWS para instancias **inexistentes** (el nodo kind no es una EC2). Útil para ver la UI y el modelo de datos, no para contabilidad real.

## Prerrequisitos

- `kind`, `kubectl`, `helm` instalados.
- 3 GB RAM libre.

## Pasos

### 1. Cluster kind

```bash
export CLUSTER_NAME=k8s-17-opencost
kind create cluster --name "$CLUSTER_NAME"
```

### 2. Prometheus mínimo (dependencia de OpenCost)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace prometheus --create-namespace \
    --set alertmanager.enabled=false \
    --set pushgateway.enabled=false \
    --wait --timeout 5m
```

### 3. Instalar OpenCost

```bash
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update

helm upgrade --install opencost opencost/opencost \
    --namespace opencost --create-namespace \
    --set opencost.prometheus.internal.enabled=true \
    --set opencost.prometheus.internal.namespaceName=prometheus \
    --set opencost.prometheus.internal.serviceName=prometheus-server \
    --wait --timeout 5m

kubectl -n opencost rollout status deploy/opencost --timeout=180s
```

### 4. Workload de ejemplo para ver atribución

```bash
kubectl create namespace team-a
kubectl -n team-a create deployment hog --image=nginx:1.27 --replicas=3
kubectl -n team-a set resources deploy/hog \
    --requests=cpu=200m,memory=256Mi \
    --limits=cpu=500m,memory=512Mi

kubectl create namespace team-b
kubectl -n team-b create deployment mouse --image=nginx:1.27 --replicas=1
kubectl -n team-b set resources deploy/mouse \
    --requests=cpu=50m,memory=64Mi
```

### 5. Consultar la UI y la API

```bash
kubectl -n opencost port-forward svc/opencost 9090:9090 &
# UI:  http://localhost:9090
# API: http://localhost:9090/allocation

# API: costo últimas 24h por namespace
curl -s "http://localhost:9090/allocation?window=24h&aggregate=namespace" | jq .
```

Esperable: `team-a` consume ~4× lo de `team-b` (12 CPU-cores vs 1), reflejado en la columna `cpuCost`.

### 6. Patrones de uso en producción

- **Alertas de waste** — reportes semanales por email: "namespaces con `requests` > 3× uso real".
- **Showback** — tabla mensual por equipo, enviada al líder correspondiente. Sin consecuencias económicas, educativo.
- **Chargeback** — contabilidad real: billing interno a cada equipo según `aggregate=label[team]`. Requiere integración con billing cloud real (CUR en AWS).
- **Right-sizing recommendations** — OpenCost expone recomendaciones; Kubecost las automatiza con UI dedicada.

### 7. Integración con billing real (producción, NO en el lab)

En producción:

- **AWS**: habilitar **Cost and Usage Report (CUR)** a un bucket S3. Configurar OpenCost con `--integration.aws.athena-bucket-name=...` para que lea precios reales con descuentos de Savings Plans y Reserved Instances.
- **GCP**: habilitar **BigQuery Billing Export**. Configurar OpenCost para consultarlo.
- **Azure**: habilitar **Cost Management Export** a storage account.

Sin esta integración, OpenCost usa pricing **público** (sobreestima el costo real si tienes reservas o descuentos corporativos).

### 8. Limpieza

```bash
helm uninstall opencost -n opencost
helm uninstall prometheus -n prometheus
kubectl delete namespace team-a team-b opencost prometheus
kind delete cluster --name "$CLUSTER_NAME"
```

## OpenCost vs Kubecost

| | **OpenCost** | **Kubecost** |
|-|--------------|--------------|
| Licencia | Apache 2.0 (CNCF) | Free tier + Enterprise commercial |
| UI | Básica, enfoque API | Rica (dashboards, savings) |
| Alertas | Externas (via API + Prometheus) | Nativas |
| Multi-cluster | DIY (API + agregador propio) | Nativo (federation) |
| Right-sizing | Datos crudos | Recomendaciones automatizadas |
| Caso típico | Equipo con stack OSS, agrega a su propio data lake | Equipo que quiere valor rápido, acepta commercial |

Kubecost **ES** OpenCost en su núcleo (ambos projects comparten código). La diferencia es la capa sobre.

## Qué mirar

- La UI `/allocation` responde en ~segundos; si tarda >30 s, Prometheus no está sirviendo métricas.
- `cpuCost + ramCost + gpuCost + pvCost + networkCost = totalCost` por recurso.
- Un namespace nuevo sin requests aparece con costo basado en **uso real** si tiene uso; si no, costo 0. Para forzar atribución justa, exigir `requests` por policy (Kyverno) en namespaces de app.

## Preguntas de reflexión

1. ¿Qué parte del costo cluster no capturan OpenCost ni Kubecost? (Pista: data egress, servicios managed externos como RDS, licencias.)
2. Un namespace tiene `requests: cpu=4` pero usa `cpu=0.2`. ¿Cómo lo reporta OpenCost? ¿Qué política interna propondrías?
3. Multi-cluster: ¿cómo agregar costo de 5 clusters en un solo dashboard sin pagar Kubecost Enterprise?
