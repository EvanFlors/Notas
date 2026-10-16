# otel-04-02 — Add domain spans (independent)

## 1. Identificación
- **ID:** `otel-04-02-add-domain-spans`
- **Tecnología:** opentelemetry
- **Módulo:** 04-instrumenting-python-traces
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

El equipo de SRE acaba de desplegar un servicio de checkout a producción. Vieron en Tempo que **sí** hay traces (un span por request HTTP) pero no sirven para investigar incidentes: no se ve en qué paso del checkout se gasta el tiempo ni cuál falla cuando el usuario reporta "pago rechazado". El servicio ya tiene SDK OTel configurado y un middleware que emite un span SERVER por request. Falta la parte de dominio.

Tu tarea es **añadir spans manuales** que cuenten la historia de negocio.

## 3. Objetivos

- Identificar los tres pasos de dominio que faltan: `checkout.process`, `payment.charge`, `inventory.reserve`.
- Crearlos con `tracer.start_as_current_span` manteniendo la jerarquía padre/hijo (todos cuelgan del span HTTP SERVER automáticamente).
- Añadir atributos útiles: cart_id, user_id (opaco), items.count, amount_cents, payment.method.
- Cuando el pago falla, marcar `payment.charge` como ERROR con `record_exception`.
- No cambiar el middleware ni el setup del SDK.

## 4. Prerrequisitos

- Haber hecho `otel-04-01-instrument-capstone-traces`.
- Python 3.10+.
- `pip install fastapi uvicorn opentelemetry-api opentelemetry-sdk`.
- Puerto libre (default 8792).
- Coste: 0.

## 5. Instrucciones

> Actividad **independiente**: no te damos la implementación en el README. En `solution/` hay una versión de referencia **al final**.

1. Lee `starter/app.py`. Tiene:
   - `configure_tracing()` ya hecho (console exporter si no hay OTLP).
   - Un `@app.middleware("http")` que crea un span `http.server.request` con atributos HTTP → **no lo toques**.
   - Las funciones `reserve_inventory`, `charge_payment` y el handler `POST /checkout` **sin** spans manuales.
2. Añade los tres spans de dominio con los nombres **exactos**:
   - `checkout.process` (envuelve el cuerpo del handler).
   - `inventory.reserve` (envuelve `reserve_inventory`).
   - `payment.charge` (envuelve `charge_payment`).
3. Añade al menos estos atributos (nombres exactos):
   - `checkout.cart_id`, `checkout.total_cents`, `enduser.id` en `checkout.process`.
   - `inventory.cart_id`, `inventory.items.count` en `inventory.reserve`.
   - `payment.user_id`, `payment.amount_cents`, `payment.method` en `payment.charge`.
4. Cuando `charge_payment` lanza `ValueError`, antes del raise añade `span.record_exception(exc)` y `span.set_status(Status(StatusCode.ERROR, ...))`.
5. Levanta y ejercita:
   ```bash
   cd starter
   python3 -m uvicorn app:app --port 8792 &
   sleep 1
   curl -s -X POST localhost:8792/checkout -H 'content-type: application/json' \
     -d '{"cart_id":"c1","user_id":"u1","items_count":2,"total_cents":4999}'
   curl -s -X POST localhost:8792/checkout -H 'content-type: application/json' \
     -d '{"cart_id":"c2","user_id":"u2","items_count":1,"total_cents":200000}' || true
   pkill -f "uvicorn app:app --port 8792"
   ```
6. Corre el validador: `bash tests/validate.sh`.

### Pistas (no la solución)

- No reemplaces el middleware. Los spans manuales deben ser **hijos** del span del middleware (por Context) sin que tengas que pasar nada entre funciones.
- `start_as_current_span` ya adhiere al Context — no necesitas `with_context` ni `attach`.
- Los nombres son contratos: cualquier otra forma (`checkout_process`, `checkout.perform`, `process_checkout`) fallará el validador.
- No añadas spans dentro de bucles tight. Un span por operación de negocio.

## 6. Resultado esperado

- Consola imprime, por cada POST OK: 4 spans (`http.server.request` → `checkout.process` → `inventory.reserve` + `payment.charge`), todos con el mismo `trace_id`.
- El POST con `total_cents=200000` produce un `payment.charge` con `status_code=ERROR`.
- `bash tests/validate.sh` imprime `OK`.

## 7. Criterios de aceptación

- Los **tres** span names existen y aparecen al ejercitar el endpoint.
- Atributos de dominio presentes.
- Jerarquía correcta (parent/child via Context).
- Error marcado explícitamente cuando aplica.
- Sin regresiones en el middleware existente.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador:
1. SKIP si faltan dependencias.
2. Falla si `starter/app.py` no contiene los tres span names.
3. Lanza, ejercita, mata y lee el log; valida nombres, atributos y status.

## 9. Preguntas de reflexión

- ¿Por qué el `trace_id` es el mismo en los 4 spans sin que pases nada?
- ¿Qué pierdes si envuelves `reserve_inventory` **y** `charge_payment` dentro del mismo span (sin anidar)?
- ¿Qué atributos *no* deberías meter en `checkout.process` aunque los tengas a mano (email, PAN, token)?
- Si el equipo pide "quiero ver la latencia P99 de `payment.charge`", ¿cómo lo obtendrías de los traces? ¿O lo moverías a métricas con `Histogram`?

## 10. Extensiones

- Añade `kind=SpanKind.CLIENT` a un span adicional que simule llamada al PSP (`stripe.api.call`).
- Añade un evento `fraud.check.passed` en `checkout.process` con `risk.score` como atributo del evento.
- Mueve `charge_payment` a un thread con `ThreadPoolExecutor` y arregla la propagación del Context (pista: `contextvars.copy_context()`).

## 11. Limpieza

```bash
pkill -f "uvicorn app:app --port 8792" 2>/dev/null || true
rm -f /tmp/otel04-02-*
```
