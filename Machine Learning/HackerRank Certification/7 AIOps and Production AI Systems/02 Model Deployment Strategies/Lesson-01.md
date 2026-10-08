# Batch Prediction versus Real-Time Serving

![Batch, real-time, and streaming deployment pattern comparison](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-deployment-patterns-comparison.svg)

## ¿Qué es?

Un **patrón de deployment** define *cuándo* y *cómo* se ejecuta la inferencia de un modelo en relación con la solicitud del usuario. Los tres patrones fundamentales son:

- **Batch prediction:** las predicciones se calculan de forma masiva en un horario (nightly, hourly) y se almacenan en una base de datos o cache. El usuario consume predicciones **pre-computadas**.
- **Real-time serving:** cada solicitud dispara una inferencia **sincrónica**. El modelo responde en milisegundos y la predicción refleja el estado más reciente del sistema.
- **Streaming prediction:** eventos fluyen por una cola (Kafka, Kinesis, Pulsar) y workers consumen esos eventos **asincrónicamente**, publicando el resultado en otra cola o base de datos. Se encuentra entre batch y real-time.

### Batch prediction

Procesa miles o millones de inputs de una vez. Un job programado (Airflow, Prefect, Dagster) toma un snapshot de datos, ejecuta inferencia en lotes grandes (optimizando GPU/TPU) y guarda resultados. Cuando el usuario consulta, se sirve el valor cacheado con latencia de milisegundos.

Ejemplo típico: recomendaciones de películas que Netflix calcula de madrugada para 200M+ usuarios. El resultado del día siguiente no refleja lo que viste en la última hora, pero sirve rápido y barato.

### Real-time serving

Cada request del cliente ejecuta el modelo sincrónicamente. El servidor debe estar siempre disponible, con autoscaling, replicación y presupuesto de latencia estricto (típicamente p99 < 100 ms para fraude, < 300 ms para búsqueda, < 1 s para chat).

Ejemplo típico: detección de fraude en Stripe. Una transacción no puede esperar hasta mañana: hay que decidir **ahora** si se aprueba.

### Streaming predictions

Los eventos llegan continuamente y se procesan tan pronto como un worker esté disponible. No hay un cliente esperando respuesta sincrónica, pero tampoco se procesa "cada 24 horas". Es ideal para flujos continuos: moderación de contenido, scoring de clicks, enriquecimiento de logs.

Ejemplo típico: moderación de posts en Meta. Un usuario publica, el evento entra a Kafka, un worker lo clasifica en 2-5 segundos, y si es inapropiado se elimina.

## ¿Por qué importa?

Elegir el patrón incorrecto es uno de los errores más costosos en producción. Las consecuencias se multiplican:

- **Elegir real-time cuando batch bastaba:** desperdicias 10-50x en infraestructura. Mantener GPUs encendidas 24/7 para servir predicciones que podrían pre-calcularse en 2 horas nocturnas con spot instances es tirar dinero.
- **Elegir batch cuando se necesitaba real-time:** sirves predicciones obsoletas. En fraude, significa aprobar transacciones fraudulentas; en pricing dinámico, cobrar precios desactualizados; en chat, sentir que el bot está "muerto".
- **Elegir streaming cuando era real-time:** el usuario espera una respuesta y recibe nada, porque el evento se procesó asincrónicamente.

Además, el patrón determina el **presupuesto de ingeniería**: real-time requiere load balancers, autoscaling, circuit breakers, health checks y observabilidad profunda. Batch requiere scheduler, data lake y job retry. Streaming requiere queue management, backpressure y exactly-once semantics.

## ¿Cómo funciona?

### Arquitectura batch

```
┌─────────────────────────────────────────────────────────┐
│  Scheduler (Airflow / Prefect / Dagster / cron)         │
│      ↓ dispara job cada N horas                         │
│  Data warehouse (BigQuery / Snowflake / S3+Delta)       │
│      ↓ lee features de todos los usuarios               │
│  Compute cluster (Spark / Ray / GPU batch job)          │
│      ↓ inferencia en lotes de 10k-100k                  │
│  Prediction store (Redis / DynamoDB / Postgres)         │
│      ↓ serve con lookup <1ms                            │
│  API edge (CDN + lookup)                                │
└─────────────────────────────────────────────────────────┘
```

Ventajas: GPU utilization altísima (batches enormes), spot instances (70% descuento), modelos pesados viables.
Costos: freshness de horas/días, almacenamiento de predicciones, costo si el universo de usuarios es gigante.

### Arquitectura real-time

```
┌─────────────────────────────────────────────────────────┐
│  Cliente (web / mobile / microservicio)                 │
│      ↓ HTTP/gRPC                                        │
│  API Gateway (Kong / Envoy / Cloud Gateway)             │
│      ↓ auth, rate limit, routing                        │
│  Load balancer (ALB / nginx / Istio)                    │
│      ↓ round-robin / least-conn                         │
│  Model servers (N replicas con autoscaling)             │
│   - Feature store lookup (<10 ms)                       │
│   - Model inference (<50 ms)                            │
│   - Post-processing + logging                           │
│      ↓                                                  │
│  Respuesta sincrónica al cliente                        │
└─────────────────────────────────────────────────────────┘
```

Ventajas: freshness máxima, personalización per-request, decisiones críticas.
Costos: infraestructura always-on, over-provisioning para peaks, complejidad operacional, limita tamaño del modelo.

### Arquitectura streaming

```
┌─────────────────────────────────────────────────────────┐
│  Producers (apps que generan eventos)                   │
│      ↓                                                  │
│  Message broker (Kafka / Kinesis / Pulsar / Pub/Sub)    │
│      ↓ topic particionado                               │
│  Stream processor (Flink / Spark Streaming / Ray)       │
│   o Workers (consumers paralelos)                       │
│      ↓ inferencia en micro-batches                      │
│  Output topic / database / cache                        │
│      ↓                                                  │
│  Consumers downstream                                   │
└─────────────────────────────────────────────────────────┘
```

Ventajas: desacoplamiento, backpressure natural (la queue absorbe spikes), throughput muy alto, micro-batching para GPU.
Costos: complejidad de queue management, idempotencia, ordering, retries, dead-letter queues.

### Tabla comparativa

| Dimensión | Batch | Real-time | Streaming |
|---|---|---|---|
| Latencia percibida | Milisegundos (desde cache) | 10-500 ms (inferencia) | Segundos a minutos |
| Freshness de predicción | Horas o días | Segundos | Segundos a minutos |
| Costo por millón de predicciones | $0.3-3 | $10-100 | $3-30 |
| Utilización de GPU | 80-95% | 20-40% | 50-75% |
| Infra always-on | No (spot OK) | Sí (99.9%+) | Sí (brokers + workers) |
| Complejidad operacional | Baja | Alta | Media-Alta |
| Rollback | Trivial (rerun job) | Requiere canary/blue-green | Replay desde offset |
| Ejemplo | Recomendaciones Netflix | Fraude Stripe | Moderación Meta |

### Fórmulas de referencia

**Costo por predicción:**

```
costo_por_prediccion = (precio_hora_infra × horas_computo) / num_predicciones_generadas
```

Para un job batch de 2 horas en un GPU A100 ($3.67/h on-demand, $1.10/h spot) que genera 10M predicciones:

```
costo_batch_spot = (1.10 × 2) / 10_000_000 = $0.00000022 por predicción
```

Comparado con real-time (asumiendo 50 req/s por GPU, $3.67/h):

```
costo_realtime = 3.67 / (50 × 3600) = $0.0000204 por predicción  →  ~90x más caro
```

**Presupuesto de latencia (SLO budget):**

Si tu SLO dice "p99 < 200 ms", y tus componentes son:

```
latencia_total = red + feature_lookup + inferencia + post_processing
    200 ms   =  20  +      30         +     ?      +       20
    → budget_inferencia = 130 ms
```

Si la inferencia excede 130 ms, debes cuantizar, usar un modelo destilado, o cambiar hardware.

## Ejemplo con código

### Batch prediction con Airflow + Ray

```python
# dags/daily_recommendations.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import ray

@ray.remote(num_gpus=1)
def predict_batch(user_ids: list[int]) -> dict:
    """Inferencia GPU-eficiente sobre un lote grande."""
    import torch
    model = torch.load("/models/recsys_v3.pt").cuda().eval()
    features = load_features_from_feast(user_ids)  # feature store
    with torch.no_grad():
        logits = model(features.cuda())
        scores = torch.softmax(logits, dim=-1).cpu().numpy()
    return dict(zip(user_ids, scores.tolist()))

def run_batch_job(**context):
    ray.init(address="auto")
    all_users = fetch_active_users_from_warehouse()  # 50M usuarios
    chunks = [all_users[i:i+10_000] for i in range(0, len(all_users), 10_000)]

    # Paraleliza en el cluster Ray (p. ej. 20 GPUs)
    futures = [predict_batch.remote(chunk) for chunk in chunks]
    results = ray.get(futures)

    # Flush a Redis con TTL de 24h
    pipe = redis_client.pipeline()
    for batch in results:
        for uid, scores in batch.items():
            pipe.setex(f"recs:{uid}", 86400, serialize(scores))
    pipe.execute()

with DAG(
    "daily_recommendations",
    schedule_interval="0 3 * * *",   # 3am diario
    start_date=datetime(2026, 1, 1),
    retries=2, retry_delay=timedelta(minutes=15),
) as dag:
    PythonOperator(task_id="batch_predict", python_callable=run_batch_job)
```

### Real-time serving con FastAPI

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import torch, time

app = FastAPI()
model = None  # Se carga en startup

class FraudRequest(BaseModel):
    amount: float = Field(gt=0)
    merchant_id: str
    user_id: str
    device_fingerprint: str

class FraudResponse(BaseModel):
    score: float
    decision: str
    latency_ms: float

@app.on_event("startup")
async def warmup():
    """Carga el modelo y hace una inferencia dummy (cold-start kill)."""
    global model
    model = torch.jit.load("/models/fraud_v7.pt").cuda().eval()
    dummy = torch.randn(1, 128).cuda()
    for _ in range(10):
        _ = model(dummy)
    torch.cuda.synchronize()

@app.get("/health")
def health():
    return {"status": "ok" if model is not None else "loading"}

@app.post("/predict", response_model=FraudResponse)
async def predict(req: FraudRequest):
    t0 = time.perf_counter()
    features = await fetch_features_realtime(req.user_id, req.merchant_id)
    with torch.no_grad():
        score = model(features.cuda()).item()
    decision = "block" if score > 0.85 else ("review" if score > 0.5 else "allow")
    return FraudResponse(
        score=score, decision=decision,
        latency_ms=(time.perf_counter() - t0) * 1000,
    )
```

### Streaming prediction con Kafka

```python
from confluent_kafka import Consumer, Producer
import json, torch

consumer = Consumer({
    "bootstrap.servers": "kafka:9092",
    "group.id": "moderation-workers",
    "auto.offset.reset": "latest",
    "enable.auto.commit": False,   # commit manual tras éxito
    "max.poll.interval.ms": 300000,
})
producer = Producer({"bootstrap.servers": "kafka:9092", "linger.ms": 20})
consumer.subscribe(["posts.created"])

model = torch.jit.load("/models/moderation_v4.pt").cuda().eval()
BATCH_SIZE, FLUSH_MS = 32, 100

def process_micro_batch(messages):
    texts = [json.loads(m.value())["text"] for m in messages]
    tensors = tokenize_and_pad(texts).cuda()
    with torch.no_grad():
        scores = torch.sigmoid(model(tensors)).cpu().tolist()

    for msg, score in zip(messages, scores):
        payload = json.loads(msg.value())
        payload["moderation_score"] = score
        payload["action"] = "remove" if score > 0.9 else "flag" if score > 0.6 else "ok"
        producer.produce("posts.moderated", json.dumps(payload).encode())
    producer.flush()
    consumer.commit(asynchronous=False)   # exactly-once best-effort

buffer, last_flush = [], time.time()
while True:
    msg = consumer.poll(timeout=0.05)
    if msg and not msg.error():
        buffer.append(msg)
    now = time.time()
    if len(buffer) >= BATCH_SIZE or (buffer and (now - last_flush) * 1000 > FLUSH_MS):
        process_micro_batch(buffer)
        buffer, last_flush = [], now
```

## Errores comunes

- **Elegir real-time por defecto "por si acaso".** Es el patrón más caro y complejo. Antes de montarlo, pregúntate: ¿el usuario *realmente* espera la respuesta? Si no, batch o streaming ahorran órdenes de magnitud.
- **Olvidar el cold start.** Un modelo de 10GB tarda 30-120 segundos en cargar a GPU. Sin un `warmup()` en `startup` y sin readiness probes correctas, el load balancer envía traffic antes de que el modelo esté listo → errores 500 masivos durante autoscaling.
- **No considerar peak capacity.** Si tu promedio es 100 req/s pero Black Friday llega a 2000 req/s, no puedes autoscalar en 10 minutos cuando los pods tardan 2 min en cargar modelo. Pre-escala o usa standby warm.
- **Streaming sin backpressure.** Si tus workers no consumen al mismo ritmo que llegan eventos, la queue crece sin límite y colapsa el broker. Monitorea `consumer_lag` y define alertas antes de 100k mensajes atrasados.
- **Batch sin idempotencia.** Si el job falla a mitad y se reintenta, generas predicciones duplicadas o inconsistentes. Usa transacciones, upsert, o escribe a staging + swap atómico.
- **Confundir freshness con calidad.** Una predicción batch de ayer puede ser *mejor* que una real-time con un modelo peor. La freshness solo importa si el fenómeno cambia rápido.
- **Mezclar predicción con feature engineering pesada en real-time.** Si tus features requieren leer 20 tablas y calcular agregaciones, mueves esa carga al momento del request. Mejor pre-computar features en un **feature store** (Feast, Tecton, Vertex Feature Store) y leer con <10 ms.
- **No implementar graceful degradation.** Si el modelo falla, ¿sirves un fallback (modelo más simple, regla heurística) o devuelves 500? Las empresas serias siempre tienen fallback.

## Contexto industrial

- **Netflix:** 95% de recomendaciones son batch (nightly), re-rankeadas en real-time con contexto (dispositivo, hora, items ya vistos).
- **Stripe Radar:** fraude 100% real-time con presupuesto de 100 ms end-to-end incluyendo red.
- **Meta:** moderación de contenido es streaming (Kafka + Flink), con 10B+ eventos diarios.
- **Spotify:** Discover Weekly es batch (semanal), pero el autoplay next-track es real-time.
- **Uber:** ETA es real-time, surge pricing es streaming (ventanas de 1-5 min), demand forecasting es batch (hourly).
- **OpenAI / Anthropic:** chat completions son real-time; evaluaciones y safety sweeps son batch.

Herramientas de referencia: **Airflow**, **Prefect**, **Dagster** (schedulers batch); **Kafka**, **Kinesis**, **Pulsar**, **Pub/Sub** (streaming); **Flink**, **Spark Streaming**, **Ray** (stream processors); **vLLM**, **Triton**, **TGI**, **Ray Serve**, **BentoML**, **SageMaker** (real-time serving).

## Resumen

- Existen **tres patrones** de deployment: batch, real-time y streaming. Cada uno optimiza un eje distinto (costo, latencia, throughput).
- **Batch** pre-computa en horario y sirve desde cache: 10-50x más barato pero predicciones stale.
- **Real-time** calcula on-demand: máxima freshness, infraestructura always-on, latencia estricta.
- **Streaming** procesa eventos continuamente: desacopla productor y consumidor, absorbe spikes con backpressure.
- Elige con base en **requerimiento de latencia**, **tasa de cambio del fenómeno**, **volumen de requests** y **presupuesto**.
- Los patrones **híbridos** (batch pre-compute + real-time rerank, o batch + streaming features) suelen dar el mejor balance.
- Siempre mide: **costo por predicción**, **p99 latency**, **utilización GPU**, **consumer lag** (streaming), **job success rate** (batch).
- Herramientas industriales clave: Airflow/Prefect, Kafka/Flink, vLLM/Triton/Ray Serve. Todo corre sobre Kubernetes con observabilidad en Prometheus/Grafana.
