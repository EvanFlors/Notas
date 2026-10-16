# Actividad 02 — Click-through trace→logs en Grafana

## 1. Identificación

- **ID:** `otel-06-02-click-through-trace-to-logs`
- **Tecnología:** opentelemetry
- **Módulo:** `06-logs-api-and-bridges`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Hasta aquí los logs correlacionados con `trace_id` han salido por stdout. En producción, lo valioso es poder **saltar de un trace a sus logs** con un click en Grafana. Esta actividad te pide levantar el stack completo (Tempo + Loki + Grafana + Collector), instrumentar una app que emita un trace multi-span **y** logs OTel, y configurar el datasource de Tempo con `TraceToLogs` apuntando a Loki.

Es **independent**: no se te da la solución. Hay pistas pero debes diseñarla.

## 3. Objetivos

- Levantar un stack `docker compose` con `tempo`, `loki`, `grafana`, `otel-collector`.
- Configurar el Collector con dos pipelines: `traces → tempo` y `logs → loki`.
- Instrumentar una app Python que ejecute una operación con **al menos 3 spans anidados** y emita **al menos 1 log por span**.
- En Grafana, abrir un trace de esa operación en Tempo y usar **TraceToLogs** para saltar al log correlacionado en Loki.
- Capturar evidencia (`screenshot.png` opcional + `trace-id.txt` con el trace_id elegido + `evidence.md` describiendo el camino).

## 4. Prerrequisitos

- `docker` + `docker compose`.
- `python3` 3.10+.
- Puertos libres: `3000` (Grafana), `3100` (Loki), `3200` (Tempo), `4317`/`4318` (Collector).
- Costos: cero (todo local).

## 5. Instrucciones

### Paso 0 — Preparar

```bash
export WORK="/tmp/otel-06-02"
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"
cp -R <ruta-al-starter>/* .
```

El `starter/` tiene un `docker-compose.yml` *parcialmente* configurado. Faltan piezas:

- El `collector-config.yaml` solo tiene pipeline de `traces`. **Falta `logs`.**
- El datasource de Tempo en `grafana-datasources.yaml` falta la sección `tracesToLogs`.
- La app Python (`app.py`) es un stub; debes:
  - Añadir el `TracerProvider` + `LoggerProvider` con el mismo `Resource` (`service.name=otel-06-02-demo`).
  - Implementar una función `process_order()` que abra 3 spans anidados: `receive`, `validate`, `charge`. Cada uno debe emitir al menos un `logger.info(...)` dentro.
  - Correr el flujo N veces (p. ej. 10) y escribir el `trace_id` del último run en `/tmp/otel-06-02/trace-id.txt`.

### Paso 1 — Collector

Edita `collector-config.yaml` y añade la pipeline de `logs`:

- Receiver: `otlp` (ya está).
- Exporter: `loki` apuntando a `http://loki:3100/loki/api/v1/push`.
- Processors: al menos `batch` y `resource` (promover `service.name`).

### Paso 2 — Grafana

En `grafana-datasources.yaml`:

- Datasource `Tempo` con `url: http://tempo:3200`.
- Dentro del Tempo, bloque `jsonData.tracesToLogsV2` apuntando al datasource `Loki` con `spanStartTimeShift: "-5m"` y `spanEndTimeShift: "5m"`. Mapea con `traceId` → tag `trace_id`.

### Paso 3 — Instrumentar y correr

- Completa `app.py`.
- `docker compose up -d`.
- `python3 app.py` — debería emitir traces + logs.
- Verifica en Grafana → Explore → Tempo que aparezca un trace con 3 spans.
- Haz click en un span → debería aparecer "Logs for this span" con el `logger.info` correspondiente.

### Paso 4 — Evidencia

Deja en `$WORK/`:

- `trace-id.txt` — un trace_id de 32 hex chars.
- `evidence.md` — 5–10 líneas describiendo:
  - Cuántos spans tenía el trace y sus nombres.
  - Qué query LogQL usaste manualmente para encontrar los logs del trace.
  - Qué cambiarías para producción (p. ej. labels promovidos vs attributes de bajo cardinality).

## 6. Resultado esperado

- `$WORK/docker-compose.yml` arranca los 4 servicios.
- `$WORK/collector-config.yaml` tiene pipelines **logs** y **traces**.
- `$WORK/grafana-datasources.yaml` tiene `tracesToLogsV2`.
- `$WORK/trace-id.txt` contiene un trace_id hex válido.
- `$WORK/evidence.md` existe con los puntos pedidos.
- Click-through demostrable en Grafana.

## 7. Criterios de aceptación

- Pipeline de logs y traces separadas en el Collector.
- La app emite ≥ 3 spans anidados por operación.
- Cada span tiene al menos 1 log con `trace_id` correlacionado.
- `TraceToLogs` configurado y funcional.

## 8. Validación

```bash
bash tests/validate.sh
```

Si no tienes `docker` o `python3`, SKIP.

## 9. Preguntas de reflexión

1. ¿Qué pasa si el `spanEndTimeShift` es `0s` en vez de `5m`? Prueba y observa (algunos logs aparecen *justo después* del end del span).
2. Si quisieras que el click-through funcionara también al revés (log → trace), ¿qué configurarías en el datasource de Loki?
3. En producción, con 10M logs/día: ¿qué parte del `attributes` deberías promover a label de Loki y qué parte dejar en el body? Argumenta con cardinalidad.

## 10. Extensiones (opcionales)

- Añade `k8sattributes` processor "simulado" (atributos manuales `k8s.pod.name`, `k8s.namespace.name`) y ve cómo quedan como labels en Loki.
- Configura un `tail_sampling` processor en el gateway para quedarte con 100% de los traces con error + 10% de éxitos.
- Añade un segundo servicio (`notify-service`) que reciba el trace propagado y agregue sus propios logs; verifica que el click-through muestra logs de los dos servicios.

## 11. Limpieza

```bash
cd /tmp/otel-06-02
docker compose down -v
cd / && rm -rf /tmp/otel-06-02
```
