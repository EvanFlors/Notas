# Ejemplo 03 — KEDA `ScaledObject` desde una cola SQS (walkthrough)

> Walkthrough de lectura. Requiere KEDA instalado y un broker/cola real (AWS SQS en este ejemplo). No se levanta en kind.
> Manifests en `manifests/`.

## Qué muestra

- Un Deployment `orders-worker` que consume mensajes.
- Un `TriggerAuthentication` + `Secret` para que KEDA llame a SQS con un IAM role o credenciales.
- Un `ScaledObject` con `minReplicaCount: 0` (scale-to-zero) que escala según el largo visible de la cola.

## Patrón mental

Sin KEDA, un worker típico mantiene siempre `minReplicas: 1` "por si llegan mensajes". Si tienes 40 workers así, pagas 40 Pods inactivos.

KEDA sustituye ese piso por un *scaler* que consulta el broker:

```
cola vacía 5 min   →   KEDA pone replicas = 0
mensajes llegan    →   KEDA pone replicas = 1 (activación)
cola > 30 msg      →   HPA interno de KEDA sube según la fórmula
cola vacía otra vez→   cooldown de 300 s, replicas = 0
```

Por debajo KEDA crea un **HPA v2** gestionado + registra un **external metrics adapter** (`external.metrics.k8s.io`). HPA no sabe de SQS; KEDA le traduce.

## `ScaledObject`

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
  pollingInterval: 15     # cada 15 s KEDA consulta SQS
  cooldownPeriod: 300     # 5 min sin actividad antes de bajar a 0
  idleReplicaCount: 0
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 120
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123456789012/orders
        queueLength: "30"
        awsRegion: us-east-1
      authenticationRef:
        name: keda-sqs-auth
```

Lectura:

- `queueLength: "30"` → KEDA le dice al HPA interno "objetivo = 30 msg/Pod". Con 300 msg visibles, HPA calcula `desired = ceil(300/30) = 10`.
- `minReplicaCount: 0` + `cooldownPeriod: 300` → scale-to-zero habilitado.
- `pollingInterval: 15` → latencia de reacción. Para colas burst-y, 15–30 s es razonable.

## Autenticación

El `TriggerAuthentication` + referencia a un `Secret` (o IRSA en EKS) permite a KEDA llamar a SQS sin que el worker reciba las credenciales. **No pongas credenciales en el `metadata` del scaler.**

## Patrones típicos

- **Floor con cron scaler** para APIs user-facing que no toleran cold start:
  ```yaml
  triggers:
    - type: cron
      metadata:
        timezone: Europe/Madrid
        start: "0 8 * * 1-5"
        end: "0 20 * * 1-5"
        desiredReplicas: "4"
    - type: aws-sqs-queue
      ...
  ```
- **Scale-to-zero solo en nocturno** combinando cron (día = `minReplicas 2`) con SQS (ratio).
- **Prometheus scaler** para traer cualquier métrica (RPS, p99 latencia) sin instalar `prometheus-adapter`.

## Peligros

- **Cold start visible**: si tu Pod tarda 60 s y los mensajes expiran en 30 s, pierdes el primero. Mitiga con `minReplicaCount: 1` o cron scaler durante horario de servicio.
- **IAM mal configurado**: KEDA no escala pero no "falla" ruidosamente; mira logs de `keda-operator` y métricas `keda_scaler_errors_total`.
- **Varios scalers sobre el mismo target**: KEDA toma el máximo (igual que HPA). Diseñado así, pero si combinas cron de 20 y SQS que devuelve 3, el pico queda cubierto por 20.
- **Scale-to-zero + sidecars que no toleran kill**: comprueba que el sidecar propaga `SIGTERM` y respeta `terminationGracePeriodSeconds`.
