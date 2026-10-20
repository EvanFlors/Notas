# Ejemplo 01 — Instrumentar FastAPI con OpenTelemetry → Application Insights

> Lectura y análisis. Sin ejecución. Objetivo: ver **de un vistazo** cómo una app Python moderna se instrumenta con Application Insights usando el **distro oficial de Azure Monitor para OpenTelemetry**, qué llega al workspace y cómo lo lees en KQL.

## 1. Entorno conceptual

- `app/` — FastAPI mínima: 1 ruta `/pay/{amount}` que llama a una dependencia HTTP y, con 1% de probabilidad, tira una excepción.
- `requirements.txt` — `fastapi`, `uvicorn`, `httpx`, `azure-monitor-opentelemetry`.
- Variable de entorno `APPLICATIONINSIGHTS_CONNECTION_STRING` apuntando a un App Insights **workspace-based** (es decir, cuya tabla destino vive en un Log Analytics Workspace).

## 2. Código mínimo (lectura)

```python
# app/main.py
import os
import random
from fastapi import FastAPI, HTTPException
import httpx
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

# Una sola llamada arranca OTel + exporter a Azure Monitor.
# Autoinstruments: fastapi, requests, httpx, sqlalchemy, redis, pymongo...
configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
    # Opcional: sampling adaptativo del 10% para contener costo en picos.
    # sampling_ratio=0.1,
)
tracer = trace.get_tracer("checkout-api")

app = FastAPI()

@app.get("/pay/{amount}")
async def pay(amount: int):
    with tracer.start_as_current_span("pay.business"):
        if random.random() < 0.01:
            raise HTTPException(status_code=500, detail="payment-gateway-timeout")
        async with httpx.AsyncClient(timeout=2.0) as client:
            # Esta llamada aparece en la tabla AppDependencies como "HTTP"
            # con target == "api.example.test".
            r = await client.get("https://api.example.test/rate")
        return {"amount": amount, "fx": r.status_code}
```

### Lectura clave

- **`configure_azure_monitor` reemplaza** la combinación clásica `OpenCensus + Azure Monitor Exporter`. No se usa `instrumentation_key` suelta.
- **Autocollect** convierte en spans el request entrante (`AppRequests`), la llamada saliente (`AppDependencies`) y la excepción (`AppExceptions`).
- `tracer.start_as_current_span("pay.business")` crea un span de usuario — se verá como *custom span* bajo el request, visible en el *end-to-end transaction viewer* del portal.

## 3. Qué llega al workspace

Tras arrancar la app y pegar 100 requests, aparecen filas en estas tablas:

| Tabla | Qué contiene (resumen) |
|-------|------------------------|
| `AppRequests` | Una fila por request HTTP entrante: `Url`, `ResultCode`, `DurationMs`, `OperationId`, `Success`, `AppRoleName`. |
| `AppDependencies` | Una fila por llamada saliente (HTTP, SQL, etc.): `Target`, `Data`, `Type`, `DurationMs`. |
| `AppExceptions` | Una fila por excepción: `ExceptionType`, `Method`, `OuterMessage`, `OperationId`. |
| `AppTraces` | Logs estructurados emitidos vía `logging` estándar de Python (si el SDK está en modo *loggerprovider*). |
| `AppCustomEvents` | `tracker.track_event(...)` en el SDK (o `OpenTelemetry` `addEvent`). |

Todos los registros comparten `OperationId` (= `traceId` de OTel) → permiten correlacionar end-to-end.

## 4. KQL de inspección (ejemplos)

```kql
// Tasa de errores por minuto en la última hora
AppRequests
| where TimeGenerated > ago(1h)
| summarize total = count(), failed = countif(Success == false)
        by bin(TimeGenerated, 1m)
| extend error_rate = round(100.0 * failed / total, 2)
| render timechart
```

```kql
// Latencia p95 y p99 del endpoint /pay/*
AppRequests
| where Url matches regex @"/pay/\d+"
| summarize p95 = percentile(DurationMs, 95),
            p99 = percentile(DurationMs, 99)
        by bin(TimeGenerated, 1m)
| render timechart
```

```kql
// Top 10 dependencies por latencia media
AppDependencies
| where TimeGenerated > ago(1h)
| summarize avg_ms = avg(DurationMs), calls = count() by Target
| top 10 by avg_ms desc
```

```kql
// Correlación: por cada excepcion, su request padre.
AppExceptions
| where TimeGenerated > ago(15m)
| join kind=inner (AppRequests) on OperationId
| project TimeGenerated, ExceptionType, Url, ResultCode, OperationId
```

## 5. Notas de producción

- **Sampling adaptativo**: el SDK puede descartar spans por heuristic si el throughput sube — reduce coste. Importante: *fixed-rate* vs *adaptive* difieren en consistencia por trace.
- **Live Metrics**: endpoint separado (`LiveEndpoint` en la connection string) que muestra métricas 1s sin pasar por el workspace. Útil para debugging en caliente.
- **Collector pattern** en producción: la app exporta a un **OTel Collector** local (sidecar o DaemonSet) y el collector reexporta a Azure Monitor. Pros: batching, filter rules, tail sampling, transforms de PII.
- **Managed Identity**: en Azure moderno, se puede autenticar la ingesta con **Entra ID** (en vez de la connection string con ikey) para flujos de pipeline/CI, aunque la mayoría de workloads aún usan la connection string.

## 6. Lo que NO hace este ejemplo

- No instrumenta métricas custom (`metric.CreateCounter`); se podría añadir fácilmente con `opentelemetry.metrics`.
- No usa Collector — es *direct exporter*.
- No usa Entra ID para la ingestion — usa `APPLICATIONINSIGHTS_CONNECTION_STRING` que incluye un `InstrumentationKey` (sigue siendo lo normal hoy).
