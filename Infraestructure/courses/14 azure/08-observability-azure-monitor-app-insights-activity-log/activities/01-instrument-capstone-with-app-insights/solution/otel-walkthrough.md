# Instrumentar `checkout` con OpenTelemetry y Azure Monitor Application Insights

> Guía reproducible para que un ingeniero sin contexto previo instrumente la app en < 15 min y vea data en el workspace.

## Prerrequisitos

- Python 3.11+ (3.12 recomendado).
- Un App Insights **workspace-based** creado (o simulado en Fase 4). La `connection string` se expone como variable de entorno `APPLICATIONINSIGHTS_CONNECTION_STRING`.
- Permisos: el workload (Managed Identity o la propia connection string) con permiso de ingesta sobre el componente.
- Un Log Analytics Workspace detrás del componente App Insights (`la-shared-prod`).

> No se requiere nada local más allá de Python y `pip`. **No se despliega nada en Azure** en esta actividad.

## Instalacion

```bash
pip install "azure-monitor-opentelemetry>=1.4.0" fastapi "uvicorn[standard]" httpx
```

El paquete `azure-monitor-opentelemetry` es el **distro oficial**: trae el SDK de OpenTelemetry preconfigurado con el exporter de Azure Monitor y las instrumentaciones autodetectadas (FastAPI, requests, httpx, sqlalchemy, redis, pymongo).

## Configuracion

En el punto de arranque de la app (`app/main.py`):

```python
import os
import random
from fastapi import FastAPI, HTTPException
import httpx
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

# Una sola llamada arranca el SDK + exporter + autoinstrumentaciones.
configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
    # sampling_ratio=0.1,  # opcional: 10% para contener coste bajo picos.
)
tracer = trace.get_tracer("checkout-api")

app = FastAPI()

@app.get("/pay/{amount}")
async def pay(amount: int):
    with tracer.start_as_current_span("pay.business"):
        if random.random() < 0.01:
            raise HTTPException(status_code=500, detail="payment-gateway-timeout")
        async with httpx.AsyncClient(timeout=2.0) as client:
            r = await client.get("https://api.example.test/rate")
        return {"amount": amount, "fx": r.status_code}
```

Clave:

- La `connection string` reemplaza al `instrumentation key` legacy. Además del ikey lleva `IngestionEndpoint`, `LiveEndpoint` y `ApplicationId`, necesarios en regiones sovereign y para Live Metrics.
- `configure_azure_monitor` arranca el OTel SDK, el exporter de Azure Monitor y detecta automáticamente FastAPI/httpx. **No** hay que decorar manualmente las rutas.
- `tracer.start_as_current_span("pay.business")` añade un span de usuario que aparecerá colgado del request en el *end-to-end transaction viewer*.

### Variables de entorno

```bash
# Nunca commitees este valor. Usa Key Vault + Managed Identity en Fase 4.
export APPLICATIONINSIGHTS_CONNECTION_STRING='InstrumentationKey=REDACTED-INSTR-KEY;IngestionEndpoint=https://REDACTED-REGION.in.applicationinsights.azure.com/;LiveEndpoint=https://REDACTED-REGION.livediagnostics.monitor.azure.com/;ApplicationId=REDACTED-APP-ID'
```

> Los valores reales de tenant/subscription/instrumentation key NO están en este repo. Reemplaza los `REDACTED-...` por los emitidos por tu componente App Insights en Fase 4.

## Verificacion

1. Arranca local: `uvicorn app.main:app --port 8080`.
2. Pega 100 requests: `for i in $(seq 1 100); do curl -s "http://localhost:8080/pay/$i" >/dev/null; done`.
3. Espera 2–3 minutos (buffer del exporter + ingesta).
4. En el portal → Log Analytics Workspace → **Logs**, ejecuta:

```kusto
AppRequests
| where TimeGenerated > ago(15m)
| summarize total = count(), failed = countif(Success == false)
        by bin(TimeGenerated, 1m)
| render timechart
```

5. Deberías ver una fila por minuto con `total ~ 10` y `failed ~ 0-1`. Si no aparece nada, verifica:
   - La connection string no está vacía ni mal copiada (el SDK no avisa al arrancar).
   - La red saliente de la máquina deja alcanzar `*.in.applicationinsights.azure.com` (NSG, Private Endpoint).
   - Pasó al menos 2 min: la primera batch sale a los ~30s pero la ingesta añade latencia.

### Otras tablas que verás pobladas

- `AppDependencies` — una fila por llamada saliente HTTP (al `api.example.test`).
- `AppExceptions` — una fila por `HTTPException` lanzada.
- `AppTraces` — logs estructurados emitidos vía `logging` estándar.
- `AppCustomEvents` — eventos custom si usas `tracker.track_event(...)` o `addEvent` de OTel.

Todas comparten `OperationId` (= traceId OTel) → `join` por esa columna correlaciona end-to-end.

## Próximos pasos (fuera de esta actividad)

- Introducir un **OpenTelemetry Collector** sidecar para batching y filtrado de PII.
- Habilitar **sampling adaptativo** cuando el throughput supere el umbral de costo.
- Reemplazar la connection string estática por **autenticación con Entra ID** (ingestion-time auth).
- Añadir **métricas custom** vía `opentelemetry.metrics` (p. ej. `payment_amount_total`).
