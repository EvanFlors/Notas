# Ejemplo 01 — Manual vs Auto (lado a lado)

Mismo endpoint FastAPI mostrado en dos variantes para visualizar la diferencia entre:

1. **Auto-instrumentation sola** (CLI + `opentelemetry-instrumentation-fastapi`).
2. **Auto + manual** (lo anterior + un `start_as_current_span` para la lógica de dominio).

El ejemplo no se corre como test formal — es material de lectura y, opcionalmente, para ejecutar a mano.

## Archivo `app_auto_only.py`

```python
# Instrumentar con: opentelemetry-instrument --traces_exporter=console \
#                   --service_name=demo-auto uvicorn app_auto_only:app --port 8001
#
# Spans que verás por request GET /checkout:
#   - 1 span SERVER "GET /checkout" (lo abre fastapi instrumentor)
#   - atributos: http.request.method, http.route, http.response.status_code
# NO verás ningún span adicional, aunque internamente `apply_coupon` sea el 90% del tiempo.
from fastapi import FastAPI

app = FastAPI()

def apply_coupon(code: str) -> int:
    # imagina I/O a DB, cálculo, llamadas externas...
    return 1500 if code == "WELCOME" else 0

@app.get("/checkout")
def checkout(code: str = "WELCOME"):
    discount = apply_coupon(code)
    return {"discount_cents": discount}
```

## Archivo `app_auto_plus_manual.py`

```python
# Mismo arranque:
#   opentelemetry-instrument --traces_exporter=console \
#     --service_name=demo-manual uvicorn app_auto_plus_manual:app --port 8002
#
# Spans que verás por request GET /checkout:
#   - 1 span SERVER "GET /checkout"       (del fastapi instrumentor)
#     - 1 span INTERNAL "apply_coupon"    (nuestro span manual, hijo del anterior)
#       - attributes: coupon.code, coupon.discount_cents
from fastapi import FastAPI
from opentelemetry import trace

tracer = trace.get_tracer("checkout.domain")  # Solo API: si no hay SDK → no-op.

app = FastAPI()

def apply_coupon(code: str) -> int:
    with tracer.start_as_current_span("apply_coupon") as span:
        span.set_attribute("coupon.code", code)
        discount = 1500 if code == "WELCOME" else 0
        span.set_attribute("coupon.discount_cents", discount)
        return discount

@app.get("/checkout")
def checkout(code: str = "WELCOME"):
    return {"discount_cents": apply_coupon(code)}
```

## Diferencia observable

| Aspecto | Solo auto | Auto + manual |
|---------|-----------|----------------|
| ¿Aparece la operación de dominio en el trace? | No | Sí, `apply_coupon` como span hijo |
| ¿Vemos el código del cupón aplicado? | No | Sí, `coupon.code` como attribute |
| ¿Vemos si el descuento fue 0? | No (hay que mirar el response body) | Sí, `coupon.discount_cents=0` filtra directo |
| Esfuerzo de código | 0 líneas añadidas | 4 líneas en la función de negocio |

## Cómo correrlo tú mismo (opcional)

Requiere Python 3.10+ y pip:

```bash
pip install \
  'opentelemetry-api' 'opentelemetry-sdk' \
  'opentelemetry-instrumentation-fastapi' \
  'opentelemetry-distro' \
  'fastapi' 'uvicorn'

# Variante solo-auto
opentelemetry-instrument --traces_exporter=console --service_name=demo-auto \
  uvicorn app_auto_only:app --port 8001 &

curl -s 'http://127.0.0.1:8001/checkout?code=WELCOME'
# Observa la salida JSON del span SERVER en el log.
```

Para la variante manual, repite con `app_auto_plus_manual:app` en el puerto 8002.

> **Si no quieres instalar nada**, el valor del ejemplo está en entender la **tabla de diferencias** y memorizar las 4 líneas que convierten auto en "auto + manual".
