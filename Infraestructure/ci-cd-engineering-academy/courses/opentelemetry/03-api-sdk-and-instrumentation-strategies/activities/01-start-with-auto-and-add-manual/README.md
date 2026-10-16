# otel-03-01 — Guided lab: auto + manual sobre FastAPI

## 1. Identificación
- **ID:** `otel-03-01-start-with-auto-and-add-manual`
- **Tecnología:** opentelemetry
- **Módulo:** 03-api-sdk-and-instrumentation-strategies
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto
Es tu primer contacto operativo con OTel. Vas a tomar una app FastAPI mínima, correrla bajo `opentelemetry-instrument` para obtener spans automáticos y luego **enriquecerla con 2 spans manuales** sobre operaciones de dominio. Al final tendrás una comprensión práctica de qué es "auto" y qué solo cubre "manual".

El patrón se repite en el resto del curso: todas las apps del capstone arrancan así.

## 3. Objetivos
- Instalar los paquetes mínimos (`opentelemetry-api`, `opentelemetry-sdk`, `opentelemetry-instrumentation-fastapi`, `opentelemetry-distro`, `fastapi`, `uvicorn`).
- Correr la app con `opentelemetry-instrument --traces_exporter=console uvicorn app:app` y comprobar un span SERVER por request.
- Modificar `app.py` para añadir **dos** spans manuales llamados `apply_coupon` y `reserve_inventory`, con al menos un `set_attribute` en cada uno.
- Capturar la salida en `/tmp/otel-03-01/spans.log` para que `tests/validate.sh` verifique estructura.

## 4. Prerrequisitos
- Python 3.10+ y `pip` disponibles.
- Puerto 8765/tcp libre.
- `curl` instalado.
- Sin costos (todo local, sin red externa salvo PyPI).

> La actividad **se degrada con elegancia** si no puedes instalar paquetes: el script `tests/validate.sh` seguirá valorando la estructura del `app.py` final que entregues y del log capturado, aunque no haya corrido realmente.

## 5. Instrucciones

### Paso 0 — Preparar scratch
```bash
rm -rf /tmp/otel-03-01
mkdir -p /tmp/otel-03-01
cp starter/app.py /tmp/otel-03-01/app.py
cd /tmp/otel-03-01
```

### Paso 1 — Entorno virtual e instalación
```bash
python3 -m venv .venv
. .venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet \
  'opentelemetry-api' 'opentelemetry-sdk' 'opentelemetry-distro' \
  'opentelemetry-instrumentation-fastapi' \
  'fastapi' 'uvicorn'
```

Si tu red/entorno bloquea PyPI, SKIP este paso y procede al Paso 3 editando `app.py` localmente — `tests/validate.sh` tiene un modo "offline" que valida solo el código escrito.

### Paso 2 — Primer run: solo auto
```bash
# En background, enviando spans por consola a un log
opentelemetry-instrument \
  --traces_exporter=console \
  --service_name=lab-otel-03 \
  uvicorn app:app --host 127.0.0.1 --port 8765 > spans.log 2>&1 &
APP_PID=$!

sleep 3                                   # dar tiempo a arrancar
curl -s 'http://127.0.0.1:8765/checkout?code=WELCOME' > /dev/null
curl -s 'http://127.0.0.1:8765/checkout?code=NOPE'    > /dev/null
sleep 2                                   # dar tiempo al batch processor a flushear

kill "$APP_PID" 2>/dev/null
wait "$APP_PID" 2>/dev/null
```

Inspecciona `spans.log` — debes ver objetos JSON con `"name": "GET /checkout"`.

### Paso 3 — Añade spans manuales a `app.py`

Edita `/tmp/otel-03-01/app.py` para que contenga `apply_coupon` y `reserve_inventory` como funciones con **spans manuales** usando el patrón visto en la lección (sección 2):

```python
from opentelemetry import trace
tracer = trace.get_tracer("checkout.domain")

def apply_coupon(code: str) -> int:
    with tracer.start_as_current_span("apply_coupon") as span:
        span.set_attribute("coupon.code", code)
        ...
```

Pistas:
- Llama a `apply_coupon(code)` y a `reserve_inventory(sku)` desde `GET /checkout`.
- Añade al menos un `set_attribute` por span (`coupon.code`, `inventory.sku`).

### Paso 4 — Segundo run: auto + manual
Repite el Paso 2 pero añadiendo `?sku=ABC-1` al curl. Sobrescribe `spans.log`.

Debes ver tanto `"name": "GET /checkout"` como `"name": "apply_coupon"` y `"name": "reserve_inventory"` en el log.

### Paso 5 — Validar
```bash
cd $OLDPWD   # vuelve al repo del curso
bash courses/opentelemetry/03-api-sdk-and-instrumentation-strategies/activities/01-start-with-auto-and-add-manual/tests/validate.sh /tmp/otel-03-01
```

## 6. Resultado esperado
- `/tmp/otel-03-01/app.py` contiene `start_as_current_span("apply_coupon")` y `start_as_current_span("reserve_inventory")`.
- `/tmp/otel-03-01/spans.log` existe y, si Python+OTel estaban disponibles, contiene al menos un span con `"name": "apply_coupon"`.

## 7. Criterios de aceptación
- `app.py` importa `opentelemetry.trace` y usa `start_as_current_span` al menos dos veces.
- Hay `set_attribute` al menos dos veces.
- El script `tests/validate.sh` termina con exit 0.
- No hay credenciales, secretos ni hosts externos en el código.

## 8. Validación
`bash tests/validate.sh /tmp/otel-03-01` imprime un reporte y exit 0 si todo cuadra.

## 9. Preguntas de reflexión
- ¿Qué pasa si quitas `opentelemetry-sdk` del venv y vuelves a correr con `opentelemetry-instrument`?
- ¿Por qué ves `GET /checkout` como span aunque tú no lo abriste?
- ¿Qué pasaría si en lugar de `start_as_current_span` usaras `start_span`?
- ¿Qué atributo *no* añadirías aquí por riesgo de cardinalidad?

## 10. Extensiones
- Añade un tercer span `charge_card` que simule un error y márcalo con `span.set_status(Status(StatusCode.ERROR))`.
- Reemplaza el exporter de consola por OTLP contra un `otel/opentelemetry-collector` local en Docker.
- Repite la actividad usando sólo instrumentación manual sin `opentelemetry-instrument` — compara qué pierdes.

## 11. Limpieza
```bash
kill "$APP_PID" 2>/dev/null || true
deactivate 2>/dev/null || true
rm -rf /tmp/otel-03-01
```
