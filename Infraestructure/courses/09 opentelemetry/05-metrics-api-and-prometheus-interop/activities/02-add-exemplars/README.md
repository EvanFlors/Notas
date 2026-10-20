# otel-05-02 — Añadir exemplars a un histograma OTel

## 1. Identificación
- **ID:** `otel-05-02-add-exemplars`
- **Tecnología:** opentelemetry
- **Módulo:** `05-metrics-api-and-prometheus-interop`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Después de migrar las métricas a OTel (otel-05-01), el siguiente paso para habilitar observabilidad de alta señal es conectar cada muestra de latencia con el **trace** que la produjo. Esa es la función de los **exemplars**: puntos individuales adjuntos a los buckets de un histograma, con `trace_id` y `span_id`, que Grafana puede dibujar sobre la gráfica y usar como **click-through** al trace completo.

OTel adjunta exemplars automáticamente **si** el `record()` del histograma ocurre dentro de un span activo. Esta actividad verifica que la pieza faltante — el `TracerProvider` configurado y el `start_as_current_span` envolviendo el trabajo — está en su sitio.

## 3. Objetivos

- Partir del `starter/app.py` (histograma OTel sin tracing).
- Configurar un `TracerProvider` con `ConsoleSpanExporter`.
- Envolver la generación de valores con `tracer.start_as_current_span(...)`.
- Verificar en el output del `ConsoleMetricExporter` que los `data_points` tienen `exemplars` con `trace_id` y `span_id` no vacíos.
- No se da la solución guiada paso a paso; usa el `examples/03-exemplars-trace-link` del módulo como referencia conceptual.

## 4. Prerrequisitos

- Python 3.10+.
- `opentelemetry-api`, `opentelemetry-sdk`.
- `bash`, no se requiere red ni infra.

## 5. Instrucciones

1. Lee `starter/app.py`. Tiene un `Histogram` que graba valores en un bucle, pero **sin** span activo → los exemplars vendrán vacíos.
2. Añade el setup de tracing (`TracerProvider` + `ConsoleSpanExporter` + `BatchSpanProcessor`).
3. Obtén un tracer y envuelve el `record()` del histograma dentro de un `start_as_current_span(...)`.
4. Corre `python3 starter/app.py` y verifica a ojo que ves `trace_id` dentro de `exemplars`.
5. Corre `bash tests/validate.sh` — debe terminar en `OK`.
6. No subas la solución a `solution/` hasta estar seguro; la hay como referencia después para comparar.

## 6. Resultado esperado

Al correr `python3 starter/app.py` (ya con tus cambios) el stdout contiene bloques como:

```json
"exemplars": [
  {
    "filtered_attributes": {},
    "value": 0.0507,
    "time_unix_nano": ...,
    "span_id": "aa...",
    "trace_id": "bb..."
  }
]
```

## 7. Criterios de aceptación

- `tests/validate.sh` termina en `OK` (o `SKIP` si faltan deps).
- Los `trace_id` que aparecen en los exemplars coinciden con los que exporta `ConsoleSpanExporter` (sanity check manual).
- No añades el `prometheus_client` ni expones `/metrics` — esta actividad es solo sobre exemplars en el pipeline OTel.

## 8. Validación

```bash
bash tests/validate.sh
```

El script corre `starter/app.py` y verifica que la salida contiene `exemplars` no vacíos con `trace_id` y `span_id`.

## 9. Preguntas de reflexión

1. ¿Qué pasa si el `record()` ocurre fuera de cualquier span? ¿Está vacío el exemplar o simplemente no se adjunta?
2. ¿Por qué los exemplars se adjuntan solo a histogramas y no (hoy) a contadores?
3. ¿Qué flag necesita Prometheus para almacenar exemplars y por qué está deshabilitado por default?
4. ¿Cómo configurarías Grafana para que al clicar un exemplar abra el trace en Tempo?
5. Si el muestreo (sampling) descarta el 90% de los traces, ¿qué fracción de exemplars será "resoluble" al abrir el trace completo?

## 10. Extensiones

- Añade un `Counter` en el mismo span y comprueba que los contadores también pueden tener exemplars (en versiones recientes del SDK).
- Reemplaza `ConsoleMetricExporter` por `OTLPMetricExporter` apuntando a un Collector local; configura `prometheusremotewrite` con `send_exemplars: true` y verifica el exemplar en Prometheus.
- Añade `Baggage` con un `tenant_id` en el span y observa cómo (no) se refleja en el exemplar (los exemplars no copian baggage por default).

## 11. Limpieza

- `/tmp/otel05-02*` se auto-limpia (el script usa `trap`).
- Nada queda corriendo entre ejecuciones: la app termina sola tras ~2 s.
