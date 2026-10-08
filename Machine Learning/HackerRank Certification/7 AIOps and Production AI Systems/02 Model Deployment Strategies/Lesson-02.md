# REST APIs versus gRPC for Model Serving

## ¿Qué es?

**Model serving** es la capa que expone un modelo entrenado como un servicio consumible por otros sistemas. Dos decisiones determinan la arquitectura:

1. **El protocolo** por el que el cliente habla con el servidor: REST (HTTP/1.1 + JSON) o gRPC (HTTP/2 + Protocol Buffers).
2. **El framework** que carga el modelo, administra batching, versionado y métricas: FastAPI, vLLM, TGI, Triton, TorchServe, TensorFlow Serving, Ray Serve, BentoML, SageMaker, Modal, Replicate.

### REST vs gRPC

| Dimensión | REST + JSON | gRPC + Protobuf |
|---|---|---|
| Transport | HTTP/1.1 | HTTP/2 (multiplex, streaming) |
| Serialización | Texto (JSON) | Binario (Protobuf) |
| Overhead típico | 2-10 KB | 200 B - 2 KB |
| Latencia relativa | 1x | 0.3-0.5x |
| Debug | curl, Postman, logs legibles | grpcurl, binario |
| Soporte browser | Nativo | gRPC-Web (proxy) |
| Multi-lenguaje | Universal | Bueno en top 10, limitado fuera |
| Streaming bidireccional | No (SSE/WebSocket workarounds) | Nativo |
| Mejor para | APIs públicas, prototipos | Internal services, alto throughput |

### Frameworks de serving

- **FastAPI:** framework web Python async. Máxima flexibilidad, mínimo overhead; ideal para custom serving. No incluye batching automático.
- **vLLM:** servidor especializado en LLMs con **PagedAttention** y continuous batching. Expone API OpenAI-compatible. Throughput 10-24x TGI vanilla para LLMs.
- **TGI (Text Generation Inference, Hugging Face):** servidor de LLMs con tensor parallelism, speculative decoding y Flash Attention. Muy maduro, menos performante que vLLM en muchos casos.
- **Triton Inference Server (NVIDIA):** multi-framework (PyTorch, TF, ONNX, TensorRT), dynamic batching, ensembles, concurrent model execution. Es el estándar enterprise.
- **Ray Serve:** serving distribuido sobre Ray. Autoscaling nativo, Python-first, grafos de deployment.
- **BentoML:** empaqueta modelo + código + deps en un "bento" portable con builds reproducibles y auto-generación de Docker + K8s manifests.
- **TorchServe / TensorFlow Serving:** servers oficiales de cada framework. Soportan model archives, versioning y batching.
- **Modal / Replicate:** PaaS serverless para modelos; sin manejar infra, pay-per-second.
- **SageMaker Endpoints (AWS):** managed serving con autoscaling, multi-model endpoints y shadow deployments integrados.

## ¿Por qué importa?

El protocolo y el framework son la **superficie de contacto** entre tu modelo y el mundo. Decisiones malas aquí tienen efecto multiplicador:

- **Protocolo lento** → cada ms de serialización x N millones de requests/día = horas de cómputo y latencia perceptible.
- **Framework sin dynamic batching** → GPU al 15% de utilización; estás pagando 7x lo necesario.
- **Sin health/readiness checks** → el load balancer envía traffic a pods aún cargando modelos → errores 500 masivos.
- **Sin circuit breakers ni rate limits** → una dependencia caída (feature store, auth) tumba todo el stack en cadena.
- **Framework incorrecto para el workload** → usar FastAPI puro para LLMs es 10-20x más lento que vLLM.

## ¿Cómo funciona?

### FastAPI básico con validación y health checks

```python
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field
import torch, time, logging

app = FastAPI(title="Sentiment API", version="1.3.0")
log = logging.getLogger("uvicorn")

model, tokenizer = None, None
MODEL_VERSION = "sentiment-roberta-v1.3.0"

class PredictIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=10_000)

class PredictOut(BaseModel):
    label: str
    confidence: float = Field(ge=0.0, le=1.0)
    model_version: str
    latency_ms: float

@app.on_event("startup")
async def load_model():
    global model, tokenizer
    tokenizer = AutoTokenizer.from_pretrained("/models/roberta")
    model = torch.jit.load("/models/roberta_scripted.pt").cuda().eval()
    # Warmup: elimina cold start en el primer request real
    for _ in range(5):
        _ = model(tokenizer("warmup", return_tensors="pt").input_ids.cuda())
    torch.cuda.synchronize()
    log.info("Model ready: %s", MODEL_VERSION)

@app.get("/health")  # liveness
def health():
    return {"status": "healthy"}

@app.get("/ready")   # readiness
def ready():
    if model is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE)
    return {"status": "ready", "version": MODEL_VERSION}

@app.post("/predict", response_model=PredictOut)
def predict(req: PredictIn):
    if model is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE)
    t0 = time.perf_counter()
    tokens = tokenizer(req.text, return_tensors="pt", truncation=True, max_length=512)
    with torch.no_grad():
        logits = model(tokens.input_ids.cuda())
        probs = torch.softmax(logits, dim=-1)[0]
    idx = probs.argmax().item()
    return PredictOut(
        label=["negative", "neutral", "positive"][idx],
        confidence=probs[idx].item(),
        model_version=MODEL_VERSION,
        latency_ms=(time.perf_counter() - t0) * 1000,
    )
```

### vLLM OpenAI-compatible server

```bash
# Lanza un servidor compatible con el SDK oficial de OpenAI
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.1-70B-Instruct \
    --tensor-parallel-size 4 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.92 \
    --dtype bfloat16 \
    --enable-prefix-caching \
    --port 8000
```

```python
# Cliente - usa el SDK de OpenAI sin cambios
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8000/v1", api_key="not-needed")

resp = client.chat.completions.create(
    model="meta-llama/Llama-3.1-70B-Instruct",
    messages=[{"role": "user", "content": "Explica RAG en 3 líneas"}],
    max_tokens=256,
)
print(resp.choices[0].message.content)
```

### Ray Serve con autoscaling

```python
from ray import serve
from fastapi import FastAPI

api = FastAPI()

@serve.deployment(
    num_replicas="auto",
    autoscaling_config={
        "min_replicas": 2,
        "max_replicas": 20,
        "target_ongoing_requests": 5,   # escala si > 5 reqs/replica
        "upscale_delay_s": 30,
        "downscale_delay_s": 300,
    },
    ray_actor_options={"num_gpus": 1},
    max_ongoing_requests=10,
)
@serve.ingress(api)
class Classifier:
    def __init__(self):
        self.model = torch.jit.load("/models/clf.pt").cuda().eval()

    @api.post("/predict")
    async def predict(self, text: str):
        with torch.no_grad():
            return {"score": float(self.model(encode(text)).item())}

serve.run(Classifier.bind(), route_prefix="/")
```

### NVIDIA Triton: dynamic batching declarativo

```protobuf
# model_repository/sentiment/config.pbtxt
name: "sentiment"
backend: "pytorch"
max_batch_size: 32
input  [ { name: "input_ids" data_type: TYPE_INT64 dims: [ 512 ] } ]
output [ { name: "logits"    data_type: TYPE_FP32 dims: [ 3 ] } ]
dynamic_batching {
    preferred_batch_size: [ 8, 16, 32 ]
    max_queue_delay_microseconds: 50000   # 50ms max wait
}
instance_group [ { count: 2, kind: KIND_GPU } ]
```

Triton junta hasta 32 requests concurrentes esperando máx. 50 ms, los procesa en una sola llamada a la GPU, y devuelve las respuestas individualmente. Sin tocar código del modelo.

### SageMaker endpoint con boto3

```python
import boto3, json

sm = boto3.client("sagemaker")
sm.create_model(
    ModelName="sentiment-v1-3-0",
    PrimaryContainer={
        "Image": "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.3.0-gpu",
        "ModelDataUrl": "s3://my-models/sentiment-v1.3.0.tar.gz",
    },
    ExecutionRoleArn="arn:aws:iam::...:role/SageMakerRole",
)

sm.create_endpoint_config(
    EndpointConfigName="sentiment-prod-cfg",
    ProductionVariants=[{
        "VariantName": "v130", "ModelName": "sentiment-v1-3-0",
        "InitialInstanceCount": 2, "InstanceType": "ml.g5.xlarge",
        "InitialVariantWeight": 1.0,
    }],
)
sm.create_endpoint(EndpointName="sentiment-prod", EndpointConfigName="sentiment-prod-cfg")

# Invocar
runtime = boto3.client("sagemaker-runtime")
resp = runtime.invoke_endpoint(
    EndpointName="sentiment-prod",
    ContentType="application/json",
    Body=json.dumps({"text": "excellent product"}),
)
print(json.loads(resp["Body"].read()))
```

### Cliente gRPC

```python
# Después de compilar protobufs: python -m grpc_tools.protoc ...
import grpc, inference_pb2, inference_pb2_grpc

channel = grpc.insecure_channel("model-server:50051", options=[
    ("grpc.max_send_message_length", 100 * 1024 * 1024),
    ("grpc.keepalive_time_ms", 30_000),
])
stub = inference_pb2_grpc.PredictorStub(channel)
resp = stub.Predict(inference_pb2.PredictRequest(text="great movie"), timeout=1.0)
print(resp.label, resp.confidence)
```

### Patrones de robustez

- **Dynamic batching:** `max_batch_size=32`, `max_queue_delay=50ms`. Balance latencia/throughput.
- **Connection pooling cliente:** reusa HTTP/gRPC channels, evita handshakes TCP+TLS por request.
- **Timeouts cliente y servidor:** típico 1-5 s para inferencia, 100 ms para feature lookup.
- **Rate limiting:** por API key, token bucket o sliding window con Redis.
- **Circuit breaker:** abre al 50% error rate con mín. 20 requests; cerrado tras 30 s con probes.
- **Graceful shutdown:** SIGTERM → stop accepting → drena in-flight → exit (K8s terminationGracePeriodSeconds=60).

### Tabla comparativa de frameworks

| Framework | Workload ideal | Autoscaling | Dyn. batching | OpenAI API | Multi-model | GPU utilization típica |
|---|---|---|---|---|---|---|
| FastAPI puro | Prototipos, custom | Manual | No | No | Manual | 20-40% |
| vLLM | LLMs | Externo (K8s) | Continuous | Sí | No | 70-90% |
| TGI | LLMs | Externo | Sí | Parcial | No | 60-80% |
| Triton | Multi-framework prod | Externo | Sí (configurable) | No | Sí | 70-90% |
| Ray Serve | Grafos, Python-first | Nativo | Sí | No | Sí | 50-80% |
| BentoML | DevEx, portabilidad | Externo | Sí | No | Sí | 50-75% |
| TorchServe | PyTorch estándar | Externo | Sí | No | Sí | 50-70% |
| TF Serving | TensorFlow estándar | Externo | Sí | No | Sí | 50-70% |
| Modal | Serverless rápido | Nativo | Limitado | No | Sí | Variable |
| Replicate | Demos públicas | Nativo | Limitado | No | Sí | Variable |
| SageMaker | Managed AWS | Nativo | Sí | No | Sí (MME) | 50-75% |

### Fórmulas útiles

**Throughput de LLM:**

```
tokens_por_segundo = batch_size × promedio_tokens_por_request / tiempo_batch_s
```

**Utilización de GPU:**

```
GPU_util = tiempo_activo_inferencia / tiempo_total_wallclock
# Objetivo: >70% para no desperdiciar. Si <40%, aumenta concurrencia o batch.
```

**Replicas necesarias:**

```
replicas = ceil( (peak_rps × latencia_promedio_s) / max_concurrent_por_replica × safety_factor )
# safety_factor típico: 1.3 - 1.5
```

## Ejemplo con código

Un stack completo real-time con FastAPI + circuit breaker + rate limit + Prometheus:

```python
from fastapi import FastAPI, Request, HTTPException
from prometheus_client import Counter, Histogram, make_asgi_app
import pybreaker, redis.asyncio as redis, time

app = FastAPI()
app.mount("/metrics", make_asgi_app())

REQS = Counter("requests_total", "", ["endpoint", "status"])
LAT = Histogram("latency_seconds", "", ["endpoint"],
                buckets=[0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5])

breaker = pybreaker.CircuitBreaker(fail_max=5, reset_timeout=30)
rds = redis.Redis(host="redis", decode_responses=True)

async def check_rate_limit(api_key: str, limit: int = 1000, window: int = 60):
    key = f"rl:{api_key}:{int(time.time() // window)}"
    count = await rds.incr(key)
    if count == 1:
        await rds.expire(key, window)
    if count > limit:
        raise HTTPException(429, "Rate limit exceeded")

@app.middleware("http")
async def observability(request: Request, call_next):
    t0 = time.perf_counter()
    response = await call_next(request)
    LAT.labels(request.url.path).observe(time.perf_counter() - t0)
    REQS.labels(request.url.path, response.status_code).inc()
    return response

@breaker
async def call_feature_store(user_id: str):
    """Protegido por circuit breaker: si feature store cae, falla rápido."""
    ...

@app.post("/predict")
async def predict(req: dict, request: Request):
    await check_rate_limit(request.headers.get("x-api-key", "anon"))
    try:
        features = await call_feature_store(req["user_id"])
    except pybreaker.CircuitBreakerError:
        # Graceful degradation: usa features default + modelo fallback
        return {"score": 0.5, "degraded": True}
    return {"score": run_inference(features)}
```

## Errores comunes

- **Elegir gRPC "porque es rápido" sin medir.** Para payloads pequeños y 100 req/s, REST+JSON cuesta ~1 ms extra: insignificante. Solo justifica gRPC si pasa de 1000 req/s o payloads multi-MB.
- **FastAPI puro para LLMs.** Sin continuous batching, un LLM-7B rinde ~5-15 req/s; con vLLM el mismo hardware da 100-300 req/s.
- **No warmup del modelo.** La primera inferencia JIT-compila kernels CUDA y tarda 5-30 s. Los primeros 100 requests dan timeouts.
- **No health y readiness checks separados.** K8s manda traffic con liveness OK pero modelo aún cargando → 503s en cadena.
- **GPU OOM sin graceful degradation.** Un input muy grande revienta memoria y mata el pod. Mitiga con `torch.cuda.empty_cache()`, límites de tokens y batching defensivo.
- **Sin circuit breaker a dependencias.** Si feature store cae, cada request espera 30 s de timeout, el pool se agota, cascada total.
- **Rate limit en memoria sin Redis compartido.** Con N replicas, cada una tiene su propio contador → N × limit permitido en realidad.
- **Logging sincrónico pesado.** `logger.info(json.dumps(huge_payload))` en cada request mata la latencia. Logea asíncrono y muestreado.
- **No versionar en path (/v1/predict).** Un breaking change rompe todos los clientes. Siempre versionar.
- **No implementar graceful shutdown.** Deployment rolling mata pods a mitad de inferencia → requests perdidos. Captura SIGTERM y drena in-flight.

## Contexto industrial

- **OpenAI y Anthropic** sirven sus APIs con stacks propietarios inspirados en Triton + vLLM. La API es REST, pero internamente usan gRPC entre servicios.
- **Hugging Face Inference Endpoints** usan TGI por default; permiten elegir vLLM para throughput extremo.
- **Together AI, Anyscale, Fireworks** operan vLLM a escala con continuous batching + speculative decoding.
- **Google** usa TensorFlow Serving + Triton para producción interna; Vertex AI expone endpoints managed.
- **Meta** opera stacks propios (fbgemm, AITemplate) con gRPC entre servicios internos.
- **Netflix** usa Metaflow + custom serving para batch; TensorFlow Serving para real-time.
- **Pinterest y Lyft** son usuarios heavy de Envoy + gRPC entre microservicios.

## Resumen

- **REST** gana en accesibilidad y debug; **gRPC** gana en throughput y payloads grandes. Hybrid (REST externo, gRPC interno) es común en producción.
- Los **frameworks especializados** (vLLM, TGI, Triton, Ray Serve) resuelven batching, versionado, autoscaling y métricas que escribir a mano cuesta meses.
- **vLLM** es el estándar actual para LLMs open-source; **Triton** para multi-framework enterprise.
- **Dynamic batching** y **continuous batching** son la diferencia entre 20% y 90% de utilización GPU.
- Toda API de producción necesita: validación (Pydantic), health/readiness checks, timeouts, rate limiting, circuit breakers, graceful shutdown, métricas Prometheus y logging estructurado.
- **Warmup del modelo** en startup elimina el cold start y evita 503s durante autoscaling.
- Mide siempre: **p50/p95/p99 latencia**, **throughput**, **GPU utilization**, **error rate**, **circuit breaker state**.
- La elección final depende de: tamaño del modelo (LLM → vLLM), ecosistema (AWS → SageMaker), control deseado (K8s → Triton/Ray) y DevEx (BentoML, Modal).
