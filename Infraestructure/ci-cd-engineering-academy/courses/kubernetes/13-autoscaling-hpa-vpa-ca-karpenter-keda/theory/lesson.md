# Lección: Autoscaling en Kubernetes — HPA, VPA, CA, Karpenter, KEDA

> **ID:** `k8s-13-autoscaling-hpa-vpa-ca-karpenter-keda` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `k8s-09` (requests, limits, QoS, PDB).

---

## 1. Introducción intuitiva

Un servicio recibe 50 req/s por la mañana y 2 000 req/s a mediodía. ¿Qué quieres que haga el sistema? La respuesta ingenua es "que escale". Pero escalar es ambiguo: puedes añadir **réplicas** del Pod, puedes **engordar** cada réplica (más CPU/memoria), puedes añadir **nodos** al cluster para que quepan esas réplicas, o puedes dejar que el servicio **duerma en cero** y despertarlo cuando llegue el primer mensaje a la cola.

Kubernetes expone cuatro ejes independientes y confundirlos cuesta caro:

- **Horizontal de workload** (más réplicas) → `HorizontalPodAutoscaler` (**HPA**).
- **Vertical de workload** (más recursos por réplica) → `VerticalPodAutoscaler` (**VPA**).
- **Horizontal de cluster** (más nodos) → `Cluster Autoscaler` (**CA**) o **Karpenter**.
- **Event-driven de workload** (reaccionar a colas, mensajes, cron) → **KEDA**.

Elegir el eje equivocado produce una escalada que no resuelve el problema: duplicar réplicas de un workload CPU-bound que ya está throttled no ayuda si cada réplica sigue con el mismo `limits.cpu`. Duplicar nodos cuando el problema es que un Pod único no cabe por memoria tampoco. Autoscaling es una conversación entre *qué métrica estás observando*, *qué palanca estás moviendo* y *qué tan rápido reaccionas*.

---

## 2. Fundamentos: cadena métrica → decisión → acción

Todos los autoscalers de K8s comparten el mismo patrón:

```
┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐   ┌──────────┐
│ fuente de    │ → │ evaluador    │ → │ decisión (fórmula)    │ → │ actuador │
│ métrica      │   │ (controller) │   │                       │   │          │
└──────────────┘   └──────────────┘   └──────────────────────┘   └──────────┘
```

- **HPA** mira `metrics.k8s.io` (resource metrics) o `custom.metrics.k8s.io` / `external.metrics.k8s.io`, aplica una fórmula sobre `targetAverageUtilization`, y ajusta `.spec.replicas` del Deployment/StatefulSet.
- **VPA** mira el mismo *metrics API*, usa un **recommender** histórico, y modifica `requests` (y opcionalmente `limits`) de los Pods.
- **CA** observa Pods `Pending` por falta de recursos y pide más nodos al autoscaling group del cloud.
- **Karpenter** simula el *scheduling* de los Pods pendientes y provisiona el **tipo de nodo exacto** que los satisface.
- **KEDA** actúa como un **external metrics adapter** más amplio (colas, Pub/Sub, Kafka, Prometheus, cron, 60+ scalers), inyecta métricas que HPA consume y añade **scale-to-zero**.

La fórmula canónica del HPA es:

```
desiredReplicas = ceil( currentReplicas × (currentMetricValue / desiredMetricValue) )
```

Si `currentReplicas = 4`, utilización CPU observada = 80 %, target = 50 %, entonces `desired = ceil(4 × 80/50) = 7`. HPA no "intuye", sustituye.

---

## 3. Contexto histórico

- **2015 (K8s 1.1)** — aparece HPA v1 (solo CPU). Muy limitado pero suficiente para demos.
- **2016–2018** — HPA v2 (`autoscaling/v2beta1` → `v2`) introduce `object`, `pods` y `external` metrics. Nace el *custom metrics API* y los primeros *metrics adapters* (Prometheus Adapter, 2017).
- **2017** — **VPA** entra como add-on de SIG Autoscaling. Permanece en `autoscaling.k8s.io/v1` hasta hoy; nunca se integró al core.
- **2018** — **Cluster Autoscaler** se estabiliza en los clouds (AWS, GCP, Azure). Su diseño: pedir al ASG más nodos cuando hay Pods Pending.
- **2019 (KubeCon NA)** — Microsoft/Red Hat anuncian **KEDA**. Lleva event-driven y scale-to-zero al mainstream.
- **2021** — AWS libera **Karpenter** (open source). En lugar de delegar en ASGs, Karpenter habla directamente con la API de EC2 y provisiona el nodo que *mejor encaja* con los Pods pendientes.
- **2023** — HPA `behavior` (ventanas de estabilización y policies) GA. VPA añade *in-place resize* experimental.
- **2024** — Karpenter v1 (API estable `karpenter.sh/v1`): `NodePool` y `EC2NodeClass` sustituyen al viejo `Provisioner`. Soporte experimental fuera de AWS (Azure Karpenter Provider).
- **2024+** — KEDA 2.x estable; HPA permite métricas con `ContainerResource`; VPA 1.x soporta UpdateMode `InPlaceOrRecreate` donde el runtime lo permite.

El tema se mueve. Verifica siempre la versión de API vigente antes de copiar manifests de blog posts.

---

## 4. metrics-server y las tres APIs de métricas

HPA y VPA **no leen de Prometheus directamente**. Leen de tres APIs del aggregator:

| API | Grupo | Qué sirve | Quién lo implementa |
|-----|-------|-----------|---------------------|
| Resource Metrics | `metrics.k8s.io/v1beta1` | CPU y memoria por Pod/Node, promedio corto (~1 min) | **metrics-server** |
| Custom Metrics | `custom.metrics.k8s.io/v1beta2` | Métricas de objetos K8s (p. ej. `requests_per_second` por Pod) | Prometheus Adapter, KEDA, otros |
| External Metrics | `external.metrics.k8s.io/v1beta1` | Métricas que vienen de fuera (cola SQS, lag Kafka) | KEDA, Prometheus Adapter, cloud-specific |

**metrics-server** es un `kubectl top` servido como API; agrega samples del `kubelet` (vía Summary API) y los expone. **No es almacenamiento histórico**, es una ventana deslizante. Por eso HPA sin ventanas de estabilización reacciona *demasiado rápido*.

Instalación típica en kind:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# En kind hay que tolerar el certificado del kubelet autofirmado:
kubectl patch -n kube-system deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

Verifica:

```bash
kubectl top nodes
kubectl top pods -A
```

Si `kubectl top` no responde en ~60 s, HPA tampoco va a funcionar. **El 80 % de los "HPA no escala" son metrics-server mal instalado**.

---

## 5. HPA v2 en profundidad

### 5.1 Las cuatro familias de métricas

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource         # CPU / memoria del Pod agregadas
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Pods              # métrica custom por Pod (promedio)
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"
    - type: Object            # métrica asociada a un objeto (Ingress, Service)
      object:
        describedObject:
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          name: api
        metric:
          name: requests_per_second
        target:
          type: Value
          value: "500"
    - type: External          # métrica de fuera del cluster
      external:
        metric:
          name: sqs_queue_length
          selector:
            matchLabels:
              queue: orders
        target:
          type: AverageValue
          averageValue: "30"
```

HPA toma el **máximo** de los `desiredReplicas` calculados por cada métrica. Esto significa que basta con que *una* métrica dispare para que escale; útil para "escala si CPU alta **o** si RPS alto".

### 5.2 Utilization vs AverageValue vs Value

- `Utilization` (solo recurso): porcentaje sobre `requests`. Si pediste `cpu: 100m` y el Pod usa 60m, utilización = 60 %. **Si no pones `requests`, HPA no puede calcular `Utilization`.**
- `AverageValue`: valor absoluto por réplica (p. ej. 100 req/s por Pod).
- `Value`: valor absoluto total (típico de `Object`: "mantén el Ingress bajo 500 RPS").

### 5.3 `behavior`: evitar oscilación

Por default HPA baja replicas con una ventana de estabilización de 5 min y sube inmediatamente. Puedes afinar:

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
      - type: Percent
        value: 50
        periodSeconds: 60
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 4
        periodSeconds: 30
    selectPolicy: Max
```

Esto dice: "baja como mucho 50 % de las réplicas por minuto; sube hasta duplicar o 4 Pods, lo que sea mayor, cada 30 s". **Sin `behavior` ajustado, los HPA con métrica ruidosa oscilan**.

### 5.4 Fallo silencioso típico

```bash
kubectl describe hpa api
# Conditions:
#   AbleToScale   True
#   ScalingActive False  reason: FailedGetResourceMetric
```

Causas habituales: metrics-server caído, Pod sin `requests` en el container al que apuntas, métrica custom mal mapeada en el adapter, selectores vacíos.

---

## 6. VPA: cuándo sí, cuándo no

VPA tiene **tres componentes**:

- **Recommender** — mira históricos (vía Prometheus o el metrics-server) y recomienda `requests`/`limits`.
- **Updater** — mata Pods cuyos valores están lejos de la recomendación (si `updateMode: Auto` o `Recreate`).
- **Admission plugin** — reescribe `requests` del nuevo Pod en el momento de admisión.

Modos de `updatePolicy.updateMode`:

| Modo | Qué hace | Cuándo usarlo |
|------|----------|---------------|
| `Off` | Solo recomienda. No modifica Pods. | **Siempre** empieza aquí. Lee recomendaciones durante 1–2 semanas antes de permitirle actuar. |
| `Initial` | Aplica recomendación en admission; **no** mata Pods existentes. | Workloads cuyo tamaño óptimo cambia solo entre deploys. |
| `Recreate` | Mata Pods que estén muy fuera de rango; se recrean con nuevos requests. | Casi nunca en producción directo. Equivale a reinicios. |
| `Auto` | Alias de `Recreate` hoy; en el futuro, in-place resize cuando el runtime lo permita. | Idem. |

**Regla de oro**: VPA y HPA **no deben compartir métrica**. Si HPA escala por CPU y VPA ajusta CPU-requests, cambian el denominador del cálculo del HPA y la pareja oscila. Patrones legítimos:

- HPA por **CPU** + VPA en modo `Off` (recomendación informativa).
- HPA por **métrica custom (RPS)** + VPA ajustando memoria.
- VPA sola para batch jobs sin HPA.

---

## 7. Cluster Autoscaler y Karpenter

### 7.1 Cluster Autoscaler (CA)

Modelo mental:

1. Scheduler ve un Pod y no encuentra nodo que satisfaga sus `requests` + afinidad + taints.
2. Pod queda `Pending`.
3. CA detecta el Pending, mira sus *node groups* (ASG/MIG/VMSS), identifica cuál puede recibirlo, y pide `+1` al ASG.
4. El cloud lanza el nodo (minutos), el kubelet se registra, el scheduler coloca el Pod.
5. Para bajar, CA detecta nodos infrautilizados durante `--scale-down-unneeded-time` (10 min por default) y los drena.

Limitaciones:

- Un ASG = un *shape* de instancia (o unas pocas vía mixed instance policies). Si tus Pods necesitan combinaciones variadas, acabas con *muchos* ASGs.
- CA no tiene en cuenta *bin packing* fino: puede pedir un nodo xlarge para un Pod pequeño si el ASG apropiado es ese.
- Tiempo de scale-up medido en minutos.

### 7.2 Karpenter

Modelo mental distinto:

1. Scheduler ve un Pod `Pending`.
2. Karpenter **simula el scheduling** considerando *todas* las instance types permitidas por la `NodePool`.
3. Elige la instancia (y zona) **más barata** que acomode el Pod (o un grupo de Pods pendientes).
4. Llama directo a la API del cloud (EC2 `RunInstances`) → nodo listo en ~45 s.
5. **Consolidación**: Karpenter monitorea continuamente y, si puede *reempaquetar* los Pods en menos/más baratos nodos, drena y relanza.

Objetos clave (v1):

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["3"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
```

Diferencias prácticas con CA:

| Dimensión | Cluster Autoscaler | Karpenter |
|-----------|--------------------|-----------|
| Granularidad | Por ASG (shape fijo) | Por Pod (shape ad-hoc) |
| Tiempo de scale-up | 1–3 min (ASG) | ~45 s (EC2 directo) |
| Spot | Soportado vía ASG mixed instances | Nativo, con interrupt handling |
| Multi-AMI | Vía múltiples ASGs | Vía `EC2NodeClass` AMIFamily |
| Consolidación | No (hay add-on) | Sí, nativa |
| Clouds | Multi-cloud estable | AWS GA, Azure beta |

Karpenter no es una elección mejor "en general": es mejor en AWS para flotas heterogéneas; CA sigue siendo el default en GKE/AKS y en multi-cloud. La actividad 02 explora esta decisión con un ADR.

---

## 8. KEDA: event-driven y scale-to-zero

Problema: tu worker consume de SQS. Cuando la cola está vacía quieres **cero réplicas** (pagar nada). Cuando llegan 10 000 mensajes quieres saltar a 50 réplicas rápido. HPA sobre CPU no sirve: una cola llena no mueve CPU hasta que hay réplicas consumiendo.

KEDA resuelve esto con **`ScaledObject`** (para Deployments/StatefulSets) y **`ScaledJob`** (para Jobs). Internamente KEDA es un *external metrics adapter* más un *scaler-specific* loop que, por debajo de `minReplicaCount: 0`, mantiene el Deployment en cero y lo despierta cuando el scaler lo indica.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: orders-worker
spec:
  scaleTargetRef:
    name: orders-worker
  minReplicaCount: 0
  maxReplicaCount: 50
  pollingInterval: 15
  cooldownPeriod: 300
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123/orders
        queueLength: "30"
        awsRegion: us-east-1
      authenticationRef:
        name: keda-sqs-auth
```

Lectura: "mantén ~30 mensajes por réplica. Duerme si está vacío 5 min".

Lista corta de scalers útiles (hay 60+):

- **aws-sqs-queue**, **gcp-pubsub**, **azure-servicebus** — colas de los grandes clouds.
- **kafka** — lag por consumer group.
- **prometheus** — cualquier métrica, convierte Prometheus en fuente HPA sin instalar el adapter.
- **cron** — reglas horarias ("mínimo 10 Pods de 09:00 a 18:00 L-V") que, combinadas con otro scaler, dan un piso base.
- **predictkube** (comunidad) — predicción basada en histórico.

**Peligro conocido**: scale-to-zero destapa *cold start*. Si el Pod tarda 60 s en arrancar y los mensajes expiran en 30 s, el primer mensaje de la ventana se pierde. Combina con un **floor** (`minReplicaCount: 1` o cronScaler) para APIs user-facing.

---

## 9. Internals: cómo se compone todo

Un ejemplo completo. Supón un workload API con pico diurno:

```
tráfico
  │                                    ╭───────╮
  │                                    │       │
  │                     ╭───────────╮  │       │
  │                     │           │  │       │
  │─────────────────────┴───────────┴──┴───────┴──────────  tiempo
         00h       08h   09h    12h   17h  18h    22h
```

Diseño típico:

1. **HPA** con `targetAverageUtilization: 60` en CPU + métrica `http_requests_per_second` custom (via Prometheus Adapter), `minReplicas: 3`, `maxReplicas: 40`, `behavior.scaleDown.stabilizationWindowSeconds: 600`.
2. **PodDisruptionBudget** `minAvailable: 2` (del módulo 09).
3. **Karpenter NodePool** con `consolidationPolicy: WhenEmptyOrUnderutilized`, instancias spot preferidas, on-demand fallback, zonas múltiples.
4. **KEDA cronScaler** (opcional) para asegurar `minReplicas: 8` entre 08:50 y 09:10, evitando que el pico sorprenda al HPA en el momento más caro.
5. **VPA en `Off`** generando recomendaciones para revisar `requests` cada sprint.

Flujo de eventos durante el pico:

- 08:55 — KEDA empuja replicas a 8 (cron).
- 09:00 — tráfico sube, CPU sube, HPA calcula `desired=14`.
- 09:00 + 30 s — Karpenter ve 6 Pods Pending (no caben) → simula y pide un `m7a.large` spot.
- 09:01 — nodo listo, Pods colocados, latencia estable.
- 18:30 — tráfico cae, HPA baja replicas respetando la ventana de 10 min.
- 18:45 — Karpenter detecta nodos infrautilizados y los consolida.

Si falla cualquier eslabón (metrics-server down, Karpenter sin permisos, HPA sin `behavior`), el síntoma visible es "oscilación" o "no escala". El diagnóstico siempre empieza por **`kubectl describe hpa`**, seguido de **`kubectl get events -n karpenter --sort-by=.lastTimestamp`**.

---

## 10. Antipatrones

- **HPA sin `requests` en el container objetivo** → `FailedGetResourceMetric`, no escala.
- **HPA y VPA compitiendo por la misma métrica** → oscilación garantizada.
- **CPU limit = request** (QoS Guaranteed) con HPA agresivo → throttling antes de que escale. Hay dos escuelas: limits generosos o sin limits CPU; nunca sin requests.
- **`maxReplicas` sin pensar** → explosión de costo si una métrica se vuelve loca (p. ej. un cliente abusivo). Pon un techo honesto.
- **Scaler de KEDA sobre métrica que depende de la réplica misma** (p. ej. "CPU del Pod" como external) → bucle.
- **Scale-to-zero en API user-facing sin front-door** → cold starts visibles al usuario.
- **CA en multi-cloud con un único ASG y Pods heterogéneos** → nodos siempre a medio llenar.
- **Karpenter sin `expireAfter`** → nodos spot largos que acumulan drift de AMI y de parches.
- **No usar PDB** → scale-down y upgrades matan todas las réplicas a la vez.

---

## 11. Observabilidad del propio autoscaler

Métricas que vale la pena vigilar:

- `kube_horizontalpodautoscaler_status_current_replicas` y `..._desired_replicas` (kube-state-metrics).
- `kube_horizontalpodautoscaler_status_condition{condition="ScalingActive",status="false"}` → alerta.
- Eventos: `kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler`.
- Karpenter: `karpenter_nodes_created_total`, `karpenter_nodes_terminated_total`, `karpenter_pods_startup_time_seconds`.
- KEDA: `keda_scaler_metrics_value`, `keda_scaled_object_errors`.
- VPA: `vpa_recommender_*` + `vpa_updater_*`.

Alertas útiles:

- `ScalingActive == 0` por más de 5 min.
- `desired_replicas == maxReplicas` sostenido (señal de techo mal puesto).
- Karpenter `pods_startup_time_seconds` p99 > 90 s.

---

## 12. Preguntas de evaluación

Responde sin consultar:

1. ¿Qué devuelve `metrics.k8s.io/v1beta1` y qué devuelve `custom.metrics.k8s.io/v1beta2`? ¿Quién implementa cada uno?
2. Dado `currentReplicas=5`, utilización CPU observada = 72 %, target = 60 %, ¿cuánto fija HPA como `desiredReplicas`? Muestra la fórmula.
3. Un workload tiene HPA por CPU y además VPA en modo `Auto` que ajusta CPU-requests. Describe el patrón de oscilación resultante paso a paso.
4. ¿Por qué CA tarda más que Karpenter en el scale-up? Cita dos razones estructurales.
5. ¿Qué pasa si pones `minReplicaCount: 0` en un `ScaledObject` para una API HTTP user-facing con tiempo de arranque de 40 s? Mitigaciones posibles.
6. Diseña autoscaling (métrica, min/max, behavior, nodos) para un servicio que atiende el pico diurno descrito en §9, justificando *por qué* elegiste cada parámetro y qué métrica dispararía en qué momento.
