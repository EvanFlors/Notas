# Infraestructura: cómputo, GPUs y Kubernetes para sistemas de IA

## ¿Qué es?

La **infraestructura** de un sistema de IA es el conjunto de recursos de cómputo, almacenamiento y red que permiten entrenar y servir modelos a la escala y latencia requeridas. A diferencia del software tradicional, donde una instancia de CPU típicamente basta, los sistemas de IA imponen requisitos específicos: GPUs costosas, memoria enorme para pesos de modelos, networking de alta velocidad para training distribuido, y almacenamiento que soporte modelos de decenas de gigabytes.

Elegir mal la infraestructura puede significar pagar **10x más** por el mismo workload o aceptar **10x peor** rendimiento. La decisión depende de medir las características reales de tu workload: tamaño del modelo, patrón de tráfico, latencia objetivo y tolerancia al costo.

> **Idea clave:** no existe la "mejor infraestructura" universal. Existe la correcta para tu modelo, tu tráfico y tu SLO. Siempre mide antes de optimizar.

### Tipos de cómputo para IA

| Tipo | Caso de uso | Costo relativo | Latencia típica |
|---|---|---|---|
| **CPU** | Modelos clásicos (regresión, árboles), preprocesamiento, inferencia pequeña | 1x | 100-500ms |
| **GPU (T4, A10)** | Inferencia de modelos medianos, batch de pocos ejemplos | 5-10x | 5-50ms |
| **GPU (A100, H100)** | Training grande, inferencia de LLMs | 20-50x | 10-100ms |
| **TPU (Google)** | Training optimizado para TensorFlow/JAX | 15-40x | Similar a GPU |
| **AWS Inferentia / Trainium** | Inferencia/training optimizados para costo | 3-8x | Similar a GPU |
| **Apple Neural Engine / NPUs** | Inferencia en dispositivos edge | — | ms a nivel chip |

### Kubernetes: el sistema operativo de producción

**Kubernetes (K8s)** se ha convertido en el estándar de facto para orquestar workloads en producción, incluyendo IA. Para sistemas de IA necesitas extensiones específicas:

- **NVIDIA GPU Operator**: expone GPUs a los pods, gestiona drivers y runtime.
- **Kueue / Volcano**: schedulers batch para training distribuido.
- **KServe / Seldon Core**: serving de modelos con autoscaling, canary, A/B testing.
- **KEDA**: autoscaling basado en eventos (cola de requests, mensajes en Kafka).
- **Karpenter / Cluster Autoscaler**: provisioning dinámico de nodos.

## ¿Por qué importa?

El costo de infraestructura de IA es dominante en el presupuesto operativo:

- Una **GPU A100** cuesta ~$3/hora on-demand en AWS. Un entrenamiento de 72 horas sobre 8 GPUs = **$1,728**.
- Un endpoint de serving con **4 GPUs T4** 24/7 = **~$1,000/mes**.
- Un cluster de **training multi-nodo** con 32 H100s cuesta decenas de miles de dólares por semana.

Las decisiones de infraestructura mal tomadas se manifiestan como:

- **GPUs ociosas** al 5-10% de utilización facturando a precio completo.
- **Autoscaling lento**: picos de tráfico que degradan latencia porque los nodos tardan 3-5 minutos en provisionarse.
- **Training distribuido mal configurado**: comunicación entre GPUs que domina el tiempo de cómputo, haciendo que 8 GPUs rindan como 2.
- **OOM (out of memory)** en producción: el modelo cabe en una GPU en desarrollo pero no con el batching real de producción.
- **Costos de egress** (salida de datos entre regiones) que exceden el costo de cómputo.

### El trade-off clave: latencia vs throughput vs costo

```
      Latencia baja
          ▲
          │  (batch=1, muchas GPUs chicas)
          │
          │
          │                    (batch=32, GPUs grandes)
          │                                       ▶ Throughput alto
          │
          │  (CPU, cola larga)
          ▼
       Costo bajo
```

No puedes optimizar las tres dimensiones a la vez. Debes elegir dos y aceptar la tercera.

## ¿Cómo funciona?

### Memoria de GPU: la restricción dura

El tamaño de un modelo determina directamente la GPU mínima necesaria. Para un modelo con **N parámetros**:

| Precisión | Bytes por parámetro | Modelo de 7B | Modelo de 70B |
|---|---|---|---|
| FP32 (full) | 4 | 28 GB | 280 GB |
| FP16 / BF16 | 2 | 14 GB | 140 GB |
| INT8 | 1 | 7 GB | 70 GB |
| INT4 (cuantizado) | 0.5 | 3.5 GB | 35 GB |

**Durante training** se multiplica por ~4 (pesos + gradientes + optimizer states + activaciones): un modelo de 7B en FP16 requiere ~112 GB para training completo. Por eso se usan técnicas como **gradient checkpointing**, **ZeRO** y **tensor parallelism**.

### Batching: la palanca más importante en serving

Un batch de 1 ejemplo desperdicia la mayoría de los cores de una GPU. Un batch de 32-64 puede dar 10-100x throughput. **El trade-off:** batching introduce latencia (hay que esperar a formar el batch).

```
Request 1 ─┐
Request 2 ─┤
Request 3 ─┼─▶ Batch (hasta 10ms de espera) ─▶ GPU ─▶ Respuestas
Request 4 ─┤
...        ─┘
```

Servidores que implementan **dynamic batching**: Triton Inference Server, vLLM, Text Generation Inference (TGI), TorchServe.

### GPU scheduling en Kubernetes

Kubernetes por defecto no entiende de GPUs. El **NVIDIA Device Plugin** expone GPUs como recursos reclamables:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

Para training distribuido, se usan **gang scheduling** (todos los pods del job arrancan a la vez o ninguno) con Kueue o Volcano, y **topology-aware scheduling** para colocar pods en nodos con interconexión rápida (NVLink, EFA, Infiniband).

### Autoscaling basado en señales correctas

| Señal | Para qué sirve | Problema |
|---|---|---|
| CPU utilization | Autoscaling clásico HPA | Casi irrelevante en IA |
| GPU utilization | Útil pero engañoso: 100% con batch=1 ≠ saturado | Depende del batching |
| Request queue depth | **La mejor señal para serving IA** | Requiere exposición explícita |
| Latencia p95 | Reactivo, pero sólido | Solo escala cuando ya duele |
| Tokens/segundo (LLMs) | Métrica nativa de carga | Requiere instrumentación |

### Estrategias de almacenamiento

| Tipo | Herramienta | Costo | Caso de uso |
|---|---|---|---|
| Object storage | S3, GCS, Azure Blob | $0.023/GB/mes | Modelos, datasets, logs archivados |
| Distributed FS | FSx Lustre, GPFS | $0.14/GB/mes | Training data con lecturas paralelas |
| Block storage | EBS gp3, PD-SSD | $0.08/GB/mes | Caches locales en nodos |
| Database | Postgres, DynamoDB | Varía | Features estructuradas, metadata |
| In-memory | Redis, Memcached | Alto | Features hot, caches de predicción |

**Patrón típico:** modelos en S3 con cache local en los nodos de serving (bajan una vez al arrancar), features en Redis con TTL, logs en S3 con lifecycle a Glacier.

## Ejemplo con código

### Deployment de un modelo en Kubernetes con GPU

```yaml
# model-serving.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommender
  labels:
    app: recommender
    version: v2.3.1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: recommender
  template:
    metadata:
      labels:
        app: recommender
        version: v2.3.1
    spec:
      containers:
        - name: triton
          image: nvcr.io/nvidia/tritonserver:24.08-py3
          args:
            - tritonserver
            - --model-repository=s3://ml-models/recommender/
            - --strict-model-config=false
            - --allow-metrics=true
          ports:
            - containerPort: 8000  # HTTP
            - containerPort: 8001  # gRPC
            - containerPort: 8002  # Métricas Prometheus
          resources:
            requests:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
          readinessProbe:
            httpGet:
              path: /v2/health/ready
              port: 8000
            initialDelaySeconds: 30
          env:
            - name: AWS_REGION
              value: us-east-1
      nodeSelector:
        node.kubernetes.io/instance-type: g5.xlarge  # NVIDIA A10G
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
---
apiVersion: v1
kind: Service
metadata:
  name: recommender
spec:
  selector:
    app: recommender
  ports:
    - name: http
      port: 80
      targetPort: 8000
```

### Autoscaling basado en profundidad de cola (KEDA)

```yaml
# keda-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: recommender-autoscaler
spec:
  scaleTargetRef:
    name: recommender
  minReplicaCount: 2
  maxReplicaCount: 20
  pollingInterval: 15
  cooldownPeriod: 60
  triggers:
    # Escalar por profundidad de cola en Prometheus
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: inference_queue_depth
        threshold: "50"
        query: |
          sum(inference_queue_depth{app="recommender"})
    # Escalar por latencia p95
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: inference_p95
        threshold: "0.18"  # SLO: p95 < 200ms
        query: |
          histogram_quantile(0.95,
            rate(inference_duration_seconds_bucket[2m])
          )
```

### Training distribuido con PyTorch DDP

```python
# train_ddp.py
import os
import torch
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, DistributedSampler

def setup():
    dist.init_process_group(backend="nccl")
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)
    return local_rank

def train():
    local_rank = setup()
    model = build_model().to(local_rank)
    model = DDP(model, device_ids=[local_rank])

    dataset = build_dataset()
    sampler = DistributedSampler(dataset)
    loader = DataLoader(dataset, batch_size=64, sampler=sampler, num_workers=4)

    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4)

    for epoch in range(10):
        sampler.set_epoch(epoch)
        for batch in loader:
            inputs, labels = [b.to(local_rank) for b in batch]
            loss = model(inputs, labels)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

    dist.destroy_process_group()

if __name__ == "__main__":
    train()
```

Lanzado con `torchrun --nproc_per_node=8 --nnodes=4 train_ddp.py` para 32 GPUs en 4 nodos.

### Job de training en Kubernetes con Volcano

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: recommender-training
spec:
  minAvailable: 4           # gang scheduling: todos o ninguno
  schedulerName: volcano
  tasks:
    - replicas: 4
      name: pytorch
      template:
        spec:
          containers:
            - name: trainer
              image: myregistry/trainer:v1.2
              command: ["torchrun", "--nproc_per_node=8",
                        "--nnodes=4", "train_ddp.py"]
              resources:
                requests:
                  nvidia.com/gpu: 8
                  cpu: "32"
                  memory: "256Gi"
                limits:
                  nvidia.com/gpu: 8
          restartPolicy: OnFailure
```

### Cuantización para reducir memoria

```python
# Convertir un modelo HF de FP16 a INT4 con bitsandbytes
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype="bfloat16",
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B",
    quantization_config=bnb_config,
    device_map="auto",
)
# De ~16GB a ~5GB de VRAM, con mínima pérdida de calidad
```

## Errores comunes

- **GPUs ociosas sin autoscaling.** Una A100 a $3/hora cuesta $2,160/mes aunque esté al 5% de utilización. Usa autoscaling basado en queue depth y pon `minReplicas` bajo.
- **Autoscaling basado solo en CPU.** En GPU workloads, CPU no refleja la carga real. Usa queue depth o latencia p95.
- **Scaling demasiado tardío.** Si tu cold start de un pod GPU es 3-5 minutos (bajar imagen de 10GB + modelo de 5GB), un pico de tráfico ya pasó cuando los nodos están listos. Usa warm pools o keep-alive de nodos.
- **No usar batching en serving.** Procesar requests uno a uno en una GPU grande desperdicia 90% del hardware. Usa Triton/vLLM/TGI con dynamic batching.
- **Modelo que no cabe en producción.** Entrenaste en una H100 de 80GB; serving corre en T4 de 16GB. Cuantiza (INT8/INT4), destila o cambia de infra.
- **Egress inter-región.** Mover 10TB/mes entre regiones de AWS cuesta ~$900. Mantén datos y cómputo co-ubicados.
- **Imágenes Docker gigantescas.** Imágenes de 20GB tardan en bajar y disparan cold start. Divide capas, usa `multi-stage builds`, excluye datasets.
- **Modelos recargándose en cada request.** Carga el modelo UNA vez al startup del pod, nunca por request.
- **Training distribuido sin topology awareness.** Si tus 8 GPUs están en nodos distintos sin NVLink/EFA, la comunicación domina. Usa topology hints en el scheduler.
- **No reservar capacidad para picos previsibles.** Black Friday, lanzamientos, campañas: reserva capacidad con *reservations* o *savings plans* en lugar de pagar on-demand con 3x markup.

## Contexto y referencias

- **Kubernetes docs** (kubernetes.io): fundamentos de orquestación.
- **NVIDIA GPU Operator** (github.com/NVIDIA/gpu-operator): exposición de GPUs en K8s.
- **KServe** (kserve.github.io): plataforma de serving ML sobre K8s.
- **vLLM** (vllm.ai): serving optimizado de LLMs con paged attention.
- **Triton Inference Server** (github.com/triton-inference-server): serving multi-framework de NVIDIA.
- **AWS Deep Learning Containers y GCP Vertex AI**: entornos pre-configurados.

## Resumen

- La infraestructura de IA se mide en **memoria de GPU**, **throughput de inferencia**, **ancho de banda inter-GPU** y **costo por request**.
- Un modelo de **N parámetros** requiere `N × bytes_por_parámetro` de VRAM; cuantizar (FP16 → INT8 → INT4) reduce drásticamente los requisitos.
- **Batching** es la palanca más importante en serving: puede dar 10-100x throughput, al costo de latencia extra.
- **Kubernetes** es el estándar de facto; para IA agrega NVIDIA GPU Operator, KServe/Seldon/Triton y schedulers batch (Kueue, Volcano).
- **Autoscaling** debe basarse en **queue depth** o **latencia**, no en CPU, que es irrelevante en workloads GPU.
- **Cold starts** de pods GPU pueden ser 3-5 minutos: compensa con warm pools, keep-alive y provisioning anticipado.
- **Training distribuido** (DDP, FSDP, DeepSpeed) requiere networking de alta velocidad (NVLink, EFA, Infiniband) y gang scheduling.
- **Almacenamiento** jerárquico: S3 para modelos y datasets, Lustre/FSx para training, Redis para features hot, cache local para serving.
- **Costos ocultos**: egress inter-región, imágenes Docker gigantes, GPUs ociosas y training distribuido mal configurado.
- No existe la infraestructura "mejor" universal; **mide tu workload y optimiza para él**.
