# Actividad 02 — Log-based metric para error rate

## 1. Identificación

- **ID:** `obs-13-02-log-based-metric-for-error-rate`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `13-loki-and-logs-in-the-stack`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent

## 2. Contexto

Hay un servicio `api` que **no puedes instrumentar directo** (binario cerrado o legacy). Loguea JSON con un campo `level` y a veces líneas que contienen la palabra `ERROR`. Negocio quiere un dashboard con el **error rate** del servicio y una alerta cuando sube.

Tienes dos opciones:
- Esperar a que el equipo dueño instrumente (bloqueado).
- **Derivar una log-based metric** de los logs ya existentes.

Esta actividad hace la segunda. Al final tendrás un dashboard JSON provisionable con un panel cuya query es **exactamente**:

```logql
sum(rate({app="api"} |= "ERROR" [5m]))
```

y un validador comprueba que esa query está presente en el JSON.

**No consultes `solution/` hasta terminar.**

## 3. Objetivos

- Entender cuándo una log-based metric es la respuesta correcta y cuándo es un parche.
- Escribir y validar en Explore la query `sum(rate({app="api"} |= "ERROR" [5m]))`.
- Construir un dashboard Grafana (JSON) con un panel que use esa query sobre el data source Loki.
- Añadir un segundo panel con `topk(5, sum by (path) (count_over_time({app="api"} | json | level="error" [15m])))` para los paths más ruidosos.
- Documentar en el propio dashboard (`description`) por qué esta métrica es log-based y qué pasaría si la app se instrumentara.

## 4. Prerrequisitos

- Haber terminado la actividad 01 (Loki + Alloy funcionando) **o** tener cualquier stack con Loki accesible y una app etiquetada `app=api` que loguee alguna línea `ERROR`.
- Grafana ≥ 11 para que el JSON de schemaVersion 39 sea compatible.
- **Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/setup.sh /tmp/obs13-lab02
cd /tmp/obs13-lab02
```

Se crea un **esqueleto** de dashboard JSON incompleto (`dashboard.json`) y un `README-task.md` con el enunciado detallado.

### 5.2 Decisión de diseño

Antes de escribir una línea de JSON, responde en `NOTES.md`:

1. ¿Por qué `rate()` y no `count_over_time() / 300`?
2. ¿Qué labels pondrías en `sum by (...)` si quisieras granularidad por `instance`?
3. ¿Qué cambiarías si la app logueara `ERROR` también para errores *de cliente* (`4xx`) y solo quisieras `5xx`?

### 5.3 Construir el dashboard

Edita `dashboard.json` para que contenga:

- Panel 1 (`timeseries`) — título `API error rate (log-based)` con la query:
  ```
  sum(rate({app="api"} |= "ERROR" [5m]))
  ```
- Panel 2 (`table` o `bar chart`) — top 5 paths con más errores:
  ```
  topk(5, sum by (path) (count_over_time({app="api"} | json | level="error" [15m])))
  ```
- Variable de tiempo por defecto `now-1h` → `now`.
- Descripción del dashboard explicando que es log-based y por qué.

Guárdalo en `/tmp/obs13-lab02/dashboard.json`.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/obs13-lab02
```

El validador comprueba JSON válido + presencia **exacta** de la query obligatoria + descripción no vacía.

### 5.5 (Opcional) Importarlo en Grafana

Si tienes el stack de la actividad 01 arriba, copia el archivo a `grafana/provisioning/dashboards/` y refresca.

## 6. Resultado esperado

- `dashboard.json` es JSON válido.
- Un panel referencia `sum(rate({app="api"} |= "ERROR" [5m]))` **literal**.
- La descripción del dashboard explica el enfoque log-based.
- `NOTES.md` responde las 3 preguntas del paso 5.2.

## 7. Criterios de aceptación

- [ ] `jq . dashboard.json` no falla.
- [ ] Hay al menos un target con la query exacta `sum(rate({app="api"} |= "ERROR" [5m]))`.
- [ ] El `datasource.type` de ese panel es `loki`.
- [ ] El dashboard tiene `description` no vacío.
- [ ] `NOTES.md` existe y tiene al menos 50 caracteres.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs13-lab02
```

Reporta OK/FAIL por check. Si `jq` no está instalado, el validador imprime `SKIP` y sale `0`.

## 9. Preguntas de reflexión

1. Cuando el equipo de la app finalmente instrumente un counter `api_requests_errors_total`, ¿qué haces con este dashboard? ¿Deprecate, mantener, migrar?
2. Si la ventana `[5m]` fuera `[1m]`, ¿qué pasa con la señal? ¿Y con el costo de scan?
3. La query no distingue nivel: ¿y si otros logs legítimos contienen la palabra `ERROR` en el mensaje? Rediseña usando `| json | level="error"`.
4. ¿En qué momento esta log-based metric se vuelve más cara que instrumentar directo? Esboza un cálculo con ingesta diaria.
5. Diseña una **alerta** sobre esta métrica desde Grafana alerting. ¿Qué `for:` eliges y por qué?

## 10. Extensiones

- **E1** — Añade una **recording rule de Loki** `api:log_error_rate:sum` que pre-calcule la misma query cada 30 s y haz que el panel la consuma en vez de la expresión cruda.
- **E2** — Añade un data link del panel al Explore de Loki con la query `{app="api"} |= "ERROR"` pre-cargada.
- **E3** — Diseña una variante del dashboard donde la métrica venga de un `counter` Prometheus (`api_requests_errors_total`) y compara ambas visualmente.

## 11. Limpieza

```bash
rm -rf /tmp/obs13-lab02
```
