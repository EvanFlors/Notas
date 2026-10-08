# Escalamiento Horizontal y Vertical, Autoscaling y Colas

## ¿Qué es?

**Escalar un sistema de IA** significa aumentar su capacidad para manejar más tráfico, usuarios o volumen de inferencia sin degradar latencia ni calidad. Existen dos ejes complementarios:

- **Escalamiento vertical (scale up):** reemplazar una instancia por otra más poderosa. Pasar de 4 vCPU/8GB a 16 vCPU/32GB, o de una GPU T4 a una A100.
- **Escalamiento horizontal (scale out):** añadir más instancias del mismo tipo detrás de un balanceador de carga. En lugar de una A100 gigante, correr 10 A10 en paralelo.

![Vertical vs horizontal scaling approaches](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-horizontal-vertical-scaling.svg)

A estos dos ejes se suman tres patrones esenciales en producción:

- **Autoscaling:** ajuste automático del número de réplicas según métricas (CPU, GPU, QPS, profundidad de cola).
- **Batching de requests:** agrupar varias solicitudes en una sola llamada al modelo para explotar paralelismo de GPU.
- **Arquitecturas basadas en colas:** desacoplar productores y consumidores con un buffer durable (SQS, Kafka, Pub/Sub).

| Enfoque | Analogía | Límite |
|---|---|---|
| Vertical | Comprar un camión más grande | Tamaño máximo de instancia (~128 vCPU, 2TB RAM, 8 GPU) |
| Horizontal | Comprar más camiones iguales | Prácticamente ilimitado |
| Autoscaling | Contratar choferes según demanda | Cold start de minutos para LLMs |
| Batching | Llenar el camión antes de salir | Añade latencia proporcional al tiempo de espera |

## ¿Por qué importa?

Un servicio de inferencia LLM a 10,000 QPS no se construye con un servidor gigante: se construye con decenas de pods detrás de un router inteligente. Las razones son económicas y operacionales:

- **Costo por request:** una A100 cuesta ~$3/hora. Si solo procesas 1 req/s por GPU estás pagando $3 por 3,600 requests (~$0.00083/req). Con batching + horizontal scaling bajas eso 10-50×.
- **Tolerancia a fallos:** una sola instancia gigante es un *single point of failure*. Diez pequeñas sobreviven la caída de una.
- **Cold start de LLMs:** cargar Llama-3-70B en memoria toma 30-120 segundos. Si tu autoscaling es reactivo, llegaste tarde. Hay que escalar antes del pico.
- **GPU idle = dinero quemado:** una GPU al 20% de utilización cuesta lo mismo que al 95%. Batching y colas son los mecanismos para subir ese número.

Un sistema sin batching desperdicia 60-80% de la GPU. Un sistema sin autoscaling paga capacidad pico 24/7. Un sistema sin colas colapsa en el primer pico viral.

## ¿Cómo funciona?

### Escalamiento vertical

Cambias el tipo de instancia y redeployeas. Sin cambios de código, sin coordinación. Ventajas: simplicidad total, latencia predecible (no hay saltos de red entre réplicas). Desventajas: curva de costo super-lineal (una p4d.24xlarge con 8× A100 cuesta ~$32/hr, mucho más que 8 instancias con 1 A100 cada una) y techo físico.

### Escalamiento horizontal

Requiere:

1. **Load balancer** (Layer 4 TCP o Layer 7 HTTP). AWS ALB, NGINX, Envoy, Istio.
2. **Servicios stateless.** El estado va a Redis, Postgres o al cliente. Cualquier réplica debe poder atender cualquier request.
3. **Health checks.** `/healthz` que valide modelo cargado y GPU accesible.
4. **Service discovery.** Kubernetes Service, Consul.

### Autoscaling: reactivo vs predictivo vs target-tracking

| Tipo | Trigger | Pros | Contras |
|---|---|---|---|
| **Reactivo** | Umbral de métrica (CPU > 70%) | Simple | Lag entre pico y nueva capacidad (cold start) |
| **Predictivo** | Patrón histórico (todos los lunes 9am) | Preemptivo | Requiere tráfico estable |
| **Target tracking** | Mantener métrica en objetivo (GPU=60%) | Autoajustable | Oscilaciones si cooldown es corto |
| **Scheduled** | Cron fijo | Determinista | No reacciona a eventos |

Para LLMs, autoscaling **puro reactivo** es insuficiente: por el tiempo que un pod nuevo descarga pesos de S3 (10 GB) y los carga en GPU, el pico ya pasó. Soluciones:

- Pre-warming: mantener réplicas calientes esperando.
- Pre-descarga de pesos a disco local del nodo.
- Modelos cuantizados que carguen más rápido.
- Buffer de cola que absorba el pico mientras llega capacidad.

### Batching: la clave de la utilización de GPU

Una GPU moderna tiene miles de cores en paralelo. Enviar un solo request es como usar un trailer para llevar una caja. La ecuación de throughput:

```
Throughput_batch = Batch_size × Throughput_single × Eficiencia_paralelismo
```

En práctica, `batch=32` suele dar 20-30× más throughput que `batch=1`, no 32× (overhead de kernels, memoria no perfectamente lineal).

**Static batching** (viejo): esperas a tener N requests y procesas N a la vez. Si llegan requests dispares (uno pide 10 tokens, otro pide 2000), el batch espera al más lento.

**Continuous batching / in-flight batching** (vLLM, TGI, TensorRT-LLM): la innovación clave. Cada paso de decodificación es un batch nuevo. Cuando un request termina, otro entra inmediatamente sin esperar al batch completo. Throughput 2-5× mayor en workloads reales.

**Dynamic batching** (TorchServe, Triton): junta requests que llegan en una ventana (ej. 20ms) hasta un máximo (ej. 32). Compromiso simple entre latencia y throughput.

### Arquitecturas basadas en colas

![Queue-based architecture](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-queue-based-architecture.svg)

```
Clientes ─► API Gateway ─► Cola (Kafka/SQS) ─► Workers (GPU pods) ─► Resultado
                                   ▲                    │
                                   └─ métrica scale ────┘
```

Beneficios:
- **Buffer de picos:** la cola absorbe ráfagas; los workers consumen a ritmo sostenible.
- **Back-pressure:** si la cola crece sin control, devuelves 503 al cliente antes de colapsar.
- **Dead-letter queue:** requests que fallan tras N retries van a una cola separada para debug manual.
- **Priority queues:** usuarios enterprise pasan al frente; batch jobs esperan.
- **Durabilidad:** mensajes persistidos a disco sobreviven caídas de worker.

### Fórmula de capacidad

Para dimensionar un servicio:

```
Instancias_necesarias = ceil( QPS_pico × Latencia_s / Concurrencia_por_instancia )
                        × (1 + headroom)              # típico 20-30%
```

Ejemplo: 1000 QPS, 200ms de latencia, 16 requests concurrentes por GPU → `(1000 × 0.2 / 16) × 1.3 = 16.25` → **17 réplicas**.

## Ejemplo con código

### Autoscaler horizontal en Kubernetes para workloads de GPU

```yaml
# hpa-llm-serving.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-inference
  minReplicas: 3            # pre-warmed para absorber picos
  maxReplicas: 50
  metrics:
    # Metrica custom: utilizacion de GPU via DCGM exporter
    - type: Pods
      pods:
        metric:
          name: DCGM_FI_DEV_GPU_UTIL
        target:
          type: AverageValue
          averageValue: "70"      # mantener GPU en 70%
    # Metrica custom: profundidad de cola Kafka
    - type: External
      external:
        metric:
          name: kafka_consumergroup_lag
          selector:
            matchLabels:
              topic: inference-requests
        target:
          type: AverageValue
          averageValue: "20"      # 20 mensajes/pod
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Percent
          value: 100              # duplicar en pico
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300   # bajar lento para evitar flapping
      policies:
        - type: Percent
          value: 20
          periodSeconds: 120
```

### Consumer con batching dinámico desde una cola

```python
import asyncio
import time
from collections import deque
from typing import Any

class DynamicBatcher:
    """
    Agrupa requests que llegan asincronamente. Procesa cuando:
    - se llena el batch (max_batch_size), o
    - pasa max_wait_ms desde el primer request pendiente.
    """
    def __init__(self, model, max_batch_size: int = 32, max_wait_ms: int = 20):
        self.model = model
        self.max_batch_size = max_batch_size
        self.max_wait_ms = max_wait_ms / 1000.0
        self.pending: deque[tuple[Any, asyncio.Future]] = deque()
        self._task = asyncio.create_task(self._loop())

    async def infer(self, payload: Any) -> Any:
        fut: asyncio.Future = asyncio.get_event_loop().create_future()
        self.pending.append((payload, fut))
        return await fut

    async def _loop(self):
        while True:
            if not self.pending:
                await asyncio.sleep(0.001)
                continue
            start = time.monotonic()
            # Esperamos a llenar o a timeout
            while (
                len(self.pending) < self.max_batch_size
                and (time.monotonic() - start) < self.max_wait_ms
            ):
                await asyncio.sleep(0.001)

            batch_size = min(len(self.pending), self.max_batch_size)
            batch = [self.pending.popleft() for _ in range(batch_size)]
            payloads, futures = zip(*batch)
            try:
                results = await self.model.batch_predict(list(payloads))
                for fut, res in zip(futures, results):
                    fut.set_result(res)
            except Exception as e:
                for fut in futures:
                    fut.set_exception(e)
```

### vLLM con continuous batching y PagedAttention

```python
# pip install vllm
from vllm import LLM, SamplingParams

# PagedAttention gestiona el KV-cache como paginas de memoria virtual,
# evitando fragmentacion y permitiendo compartir prefijos entre requests.
llm = LLM(
    model="meta-llama/Meta-Llama-3-8B-Instruct",
    tensor_parallel_size=2,            # 2 GPUs en paralelo
    gpu_memory_utilization=0.9,        # usar 90% de VRAM
    max_num_seqs=256,                  # hasta 256 secuencias concurrentes
    max_model_len=8192,
    enable_prefix_caching=True,        # reusar KV-cache de prompts repetidos
)
sampling = SamplingParams(temperature=0.7, max_tokens=512)

prompts = [f"Resume en 3 bullets: documento {i}" for i in range(1000)]
# vLLM aplica continuous batching internamente: ingesta todos los prompts
# y los procesa de forma intercalada, maximizando ocupacion de GPU.
outputs = llm.generate(prompts, sampling)
```

### Load balancer round-robin + health checks (minimalista)

```python
import httpx, itertools, time

class LoadBalancer:
    def __init__(self, backends: list[str], health_path: str = "/healthz"):
        self.backends = backends
        self.health_path = health_path
        self.healthy = set(backends)
        self._cycle = itertools.cycle(backends)

    async def health_loop(self, interval: int = 5):
        async with httpx.AsyncClient(timeout=2.0) as client:
            while True:
                for b in self.backends:
                    try:
                        r = await client.get(b + self.health_path)
                        if r.status_code == 200:
                            self.healthy.add(b)
                        else:
                            self.healthy.discard(b)
                    except Exception:
                        self.healthy.discard(b)
                await asyncio.sleep(interval)

    def next_backend(self) -> str:
        for _ in range(len(self.backends)):
            b = next(self._cycle)
            if b in self.healthy:
                return b
        raise RuntimeError("No hay backends saludables")
```

## Errores comunes

- **No usar batching.** Un modelo que podria servir 2000 req/s con batch=32 solo sirve 80 req/s con batch=1. Desperdicias 95% de la GPU.
- **Autoscaling demasiado lento para LLMs.** Un cold start de 60-120s significa que para cuando llega capacidad el pico ya pasó. Mantén `minReplicas` arriba de cero y pre-warmed.
- **Estado en memoria del pod.** Guardar sesiones de usuario en RAM del servidor rompe horizontal scaling: el request siguiente del mismo usuario cae en otro pod. Usa Redis.
- **Oscilaciones (flapping).** `scaleUp` y `scaleDown` con cooldowns iguales crea rebote: subes, baja la carga, bajas, vuelve a subir. Mantén `scaleDown` 5-10× más lento que `scaleUp`.
- **Health check que no valida GPU.** Un pod puede responder 200 OK en `/healthz` pero tener el modelo roto. Health check debe hacer una inferencia dummy.
- **Olvidar back-pressure.** Sin límite de cola, un pico te lleva a OOM. Pon un max-queue-size y responde 503 cuando se excede.
- **Instancias gigantes como "más simples".** Una p4d.24xlarge ($32/hr) tiene menos tolerancia a fallos que ocho p4d.3xlarge; y si el request es ligero, pagas por GPU idle.
- **No colocar servicios en la misma zona.** Un load balancer en us-east-1a sirviendo pods en us-east-1b suma 2-3ms de red por hop y egress inter-AZ en la factura.

## Resumen

- **Vertical** = instancia más grande (simple pero finito). **Horizontal** = más instancias iguales (ilimitado, tolerante a fallos). En producción se combinan.
- **Autoscaling** reactivo, predictivo y target-tracking automatizan capacidad. Para LLMs, el cold start obliga a pre-warming y a usar colas como buffer.
- **Batching** (static, dynamic, continuous) es la palanca #1 de utilización de GPU; `vLLM`, `TGI`, `Triton` y `TensorRT-LLM` lo implementan.
- **Colas** (SQS, Kafka, Pub/Sub) desacoplan y permiten back-pressure, prioridades y dead-letter.
- Fórmula clave: `Instancias = ceil(QPS × Latencia / Concurrencia) × (1 + headroom)`.
- Patrón recomendado: instancias "sweet spot" (ej. 2 GPUs) × horizontal × HPA basado en GPU util o profundidad de cola × colas Kafka con DLQ.
- Herramientas de referencia: Kubernetes HPA, KEDA, Istio/Envoy, Kafka, Redis, Prometheus + DCGM exporter.
