# Ejemplo 01 — HPA sobre CPU y una métrica custom de Prometheus

> Walkthrough comentado. Los manifests están en `manifests/`.

## Qué muestra

Dos HPA sobre el mismo Deployment, para contrastar:

- `hpa-cpu.yaml` — HPA v2 clásico sobre CPU, aplicable en kind con `metrics-server`.
- `hpa-rps.yaml` — HPA v2 sobre una métrica custom `http_requests_per_second` servida por Prometheus Adapter. **No** se levanta en kind sin el stack Prometheus; se incluye como referencia para el patrón.

## El target: Deployment `web`

`manifests/deployment.yaml` crea un Deployment con `requests.cpu: 100m` (requisito indispensable para que HPA pueda calcular `Utilization`) y un Service ClusterIP:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    memory: 128Mi
```

Fíjate: **sin `requests.cpu`, el HPA por utilización no funciona**. Si quieres HPA por memoria el target debe ser `AverageValue` (no `Utilization`), porque la memoria utilization es engañosa (caches, page cache, etc.).

## HPA por CPU (lo que corre en kind)

`manifests/hpa-cpu.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

Lectura: 50 % utilización media objetivo (sobre los 100m pedidos → 50m efectivos). Al subir, puede **duplicar** réplicas cada 15 s. Al bajar, espera 2 min de estabilidad para evitar oscilaciones por ruido.

## HPA por métrica custom (referencia)

`manifests/hpa-rps.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-rps
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 30
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"
```

Lectura: cada Pod debe absorber ~100 req/s. Si hay 350 RPS totales con 2 réplicas (175 RPS/Pod), HPA calcula `desired = ceil(2 × 175/100) = 4`.

Requiere Prometheus + `prometheus-adapter` configurado para publicar `http_requests_per_second` en `custom.metrics.k8s.io/v1beta2`. El `ConfigMap` del adapter define una regla tipo:

```yaml
rules:
  - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
    resources:
      overrides:
        namespace: {resource: "namespace"}
        pod: {resource: "pod"}
    name:
      matches: "^(.*)_total$"
      as: "${1}_per_second"
    metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)'
```

Esta regla convierte el counter `http_requests_total` en una tasa, la nombra `http_requests_per_second` y la asocia a Pods — exactamente lo que HPA busca.

## Comandos para reproducir (CPU, en kind)

```bash
# 1. Cluster kind + metrics-server (ver actividad 01 para pasos completos).
# 2. Aplicar el ejemplo:
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/hpa-cpu.yaml

# 3. Observar:
kubectl get hpa web -w
kubectl top pods -l app=web

# 4. Generar carga sintética contra el Service:
kubectl run -it --rm load --image=busybox:1.36 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://web.default.svc.cluster.local/; done'

# 5. Esperar ~2 min; replicas sube de 1 a varios.
```

## Qué observar

- `kubectl describe hpa web` imprime la métrica current, el target y el `desiredReplicas` calculado.
- Los eventos del HPA (`Events:` al final del describe) muestran los saltos: `SuccessfulRescale`.
- Al cortar la carga, replicas **no** bajan inmediatamente: la ventana de 120 s amortigua.

## Qué NO hacer

- Poner `targetAverageUtilization: 90` → no deja headroom para absorber picos.
- Olvidar `requests.cpu` → `ScalingActive=False, FailedGetResourceMetric`.
- Mezclar un HPA custom (RPS) con VPA en `Auto` sobre CPU: ver §6 de la lección.
