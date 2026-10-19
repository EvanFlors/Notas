# Ejemplo 03 — Karpenter: `NodePool` + `EC2NodeClass`

> Lectura y análisis. **Sin ejecución contra AWS.** Objetivo: ver manifiestos reales de Karpenter y compararlos con lo que haría Cluster Autoscaler para la misma carga.

## 1. Resumen de las piezas

Karpenter v1 (actual) usa dos CRDs:

- **`EC2NodeClass`** — plantilla de **cómo** se lanza un nodo (AMI family, subnets, security groups, user data, IAM instance profile).
- **`NodePool`** — **qué** se puede lanzar (requirements: arch, familia de instancia, zone, capacity type) y **cuánto** (limits, disruption settings).

Un `NodePool` referencia un `EC2NodeClass`. Múltiples `NodePool` pueden coexistir (p. ej. uno para batch Spot, otro para web on-demand).

## 2. `EC2NodeClass` ejemplo

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AMI family: Bottlerocket (ligera, pensada para contenedores) o AL2023.
  amiFamily: Bottlerocket

  # Qué subnets están disponibles para los nodos. Karpenter elige la mejor por AZ.
  # Discovery via tag: todas las subnets con esta tag entran al pool.
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks-demo"

  # Mismo patrón para security groups.
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks-demo"

  # Rol IAM del instance profile (los nodos lo necesitan para registrarse en EKS).
  role: KarpenterNodeRole-eks-demo

  # Metadata service: hop limit = 1 es el estándar seguro (evita SSRF).
  metadataOptions:
    httpEndpoint: enabled
    httpTokens: required
    httpPutResponseHopLimit: 1

  # Encriptación de disco root por defecto.
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
```

## 3. `NodePool` ejemplo (producción típica)

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general-purpose
spec:
  # Plantilla de lo que Karpenter puede lanzar.
  template:
    metadata:
      labels:
        role: general
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default

      # Requirements: Karpenter elige entre el set que cumpla TODAS.
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]   # mezcla a conveniencia
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]         # compute, general, memory
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]                   # c5/m5/r5 en adelante
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: ["nano", "micro"]       # evita instancias ridículas
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["us-east-1a", "us-east-1b", "us-east-1c"]

      # Expiración programada (rotación obligatoria): nodos re-nacen cada 30d.
      expireAfter: 720h

  # Límites del pool (seguro de FinOps).
  limits:
    cpu: 1000
    memory: 1000Gi

  # Consolidation: redistribuye pods a nodos más baratos cuando puede.
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

### Qué deberías notar

- **Rangos amplios, no un único tipo**. Karpenter escoge **el mejor** entre las ~40–60 instancias que cumplen los requirements. Esto es la diferencia filosófica con CAS.
- **`on-demand` + `spot` en el mismo pool**: Karpenter prioriza Spot cuando la carga tolera interrupciones. Para cargas que no, un NodePool separado solo on-demand.
- **`consolidationPolicy: WhenEmptyOrUnderutilized`**: core del FinOps de Karpenter. Si un nodo m5.xlarge tiene solo 15% de uso y los pods caben en un m5.large, Karpenter lo migra y mata el nodo grande.
- **`expireAfter: 720h`** (30 días): obliga rotación → nodos siempre con AMI reciente.

## 4. Cómo "obliga" a usar Karpenter una carga

Un `Deployment` que **pide** un recurso que no cabe en nodos actuales dispara a Karpenter:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-heavy
spec:
  replicas: 3
  selector: { matchLabels: { app: cpu-heavy } }
  template:
    metadata: { labels: { app: cpu-heavy } }
    spec:
      containers:
        - name: app
          image: public.ecr.aws/docker/library/nginx:1.25
          resources:
            requests:
              cpu: "4"
              memory: "8Gi"
```

Si el cluster está con m5.large (2 vCPU, 8 GiB), un pod con `cpu: 4` **no cabe**. Karpenter lo nota en segundos, consulta sus NodePools, elige p. ej. c6i.2xlarge (8 vCPU, 16 GiB), lo lanza, lo une al cluster, el pod se schedula. **No hay ASG intermedio**.

## 5. Comparación directa con Cluster Autoscaler

Para la misma carga, con CAS necesitarías:

1. Crear **N** managed node groups (`general-m5-large`, `general-m5-xlarge`, `cpu-c6i-large`, `cpu-c6i-2xlarge`...), cada uno un ASG distinto.
2. Taguearlos adecuadamente para que CAS entienda qué pod va a qué ASG (via `nodeSelector` o taints).
3. Pelearte con la **heurística** de CAS cuando varios ASGs podrían satisfacer un pod.

Con Karpenter: **un** NodePool con requirements amplios. Fin.

| Aspecto | CAS (3 ASGs) | Karpenter (1 NodePool) |
|---------|-------------|------------------------|
| Objetos K8s/AWS | 3 node groups + CAS Deployment + tags | 1 `EC2NodeClass` + 1 `NodePool` + Karpenter |
| Flexibilidad | Fijada en setup | Elegida por scheduler en tiempo real |
| Spot | Ajustable por ASG | Nativo, mezcla por pod |
| Rotación/upgrades | Rolling manual del MNG | `expireAfter` automatiza |
| Consolidation | No nativa (hay `balance-similar-node-groups`, limitada) | Nativa |

## 6. Lo que NO está aquí

- **Instalación de Karpenter** (helm chart + IRSA role del controller + SQS para interruption handling).
- Casos de **tenancy mixta** (p. ej. GPU nodes aislados por taints).
- Interacción fina con **Pod Disruption Budgets** durante consolidation.

Estos entran típicamente en un segundo módulo de Karpenter en profundidad.

## 7. Preguntas de autocomprobación

1. ¿Por qué `consolidateAfter: 1m` tan bajo puede ser agresivo en producción?
2. Si tienes workloads que **no pueden** correr en Spot (stateful, batch largo), ¿cómo lo expresas en Karpenter?
3. ¿Qué pasa si tu `EC2NodeClass` apunta a subnets sin la tag `karpenter.sh/discovery`?
4. Si quisieras **forzar** solo instancias Graviton (ARM), ¿qué requirement añadirías?
5. ¿Por qué `expireAfter: 720h` es equivalente conceptual a un *max node age* y no a un *upgrade* real?
