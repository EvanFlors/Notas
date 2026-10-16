# otel-02-01 — Identify a breaking semconv change

## 1. Identificación

- **ID:** `otel-02-01-identify-breaking-semconv-change`
- **Tecnología:** `opentelemetry`
- **Módulo:** `02-specification-semconv-and-context-propagation`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** independent (debug)

## 2. Contexto

Tu equipo opera 3 microservicios en producción. Hoy pasa algo raro: los dashboards de latencia HTTP agrupados por `http.method` muestran la mitad del tráfico que ayer. No ha bajado el tráfico — simplemente **algunos spans ya no se agrupan ahí**.

Investigando descubres que, en los últimos meses, cada servicio **actualizó su SDK OTel por su cuenta** a versiones distintas, y la semconv HTTP evolucionó entre esas versiones (migración `http.method` → `http.request.method` y amigos). El resultado: tres servicios emiten tres variantes distintas de los mismos atributos.

Tu misión: **identificar qué servicio emite qué**, cuáles son los atributos **deprecados**, y proponer un **plan de migración** que no rompa dashboards durante la transición.

## 3. Objetivos

- Reconocer atributos HTTP semconv deprecados vs vigentes.
- Clasificar los 3 servicios por versión semconv.
- Proponer un plan de migración con **dual-emit** transitorio.
- Explicar qué dashboards romperían si cortas sin dual-emit.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md`, especialmente la sección 6.
- `python3`. **SKIP si falta.**
- `bash`, `grep`.

## 5. Instrucciones

1. **Genera los tres payloads de ejemplo** ejecutando el starter:

   ```bash
   cd "$(git rev-parse --show-toplevel)/courses/opentelemetry/02-specification-semconv-and-context-propagation/activities/01-identify-breaking-semconv-change"
   bash starter/build-samples.sh
   ```

   Esto crea `/tmp/otel-02-01-samples/` con tres archivos `service-{a,b,c}.json`, cada uno conteniendo un span emitido por una versión distinta del SDK.

2. **Lee los tres archivos** y responde en `/tmp/otel-02-01-samples/answer.md`:

   - **A)** Para cada servicio, lista qué atributos usa y clasifícalos: `CURRENT` (semconv HTTP v1 vigente), `DEPRECATED`, o `UNKNOWN/custom`.
   - **B)** Identifica cuál servicio está en semconv antiguo, cuál en nuevo, cuál mixto.
   - **C)** Lista **todos** los renombres deprecated → current que detectes.
   - **D)** Escribe un plan de migración en 4 pasos que incluya **dual-emit** y especifique un criterio de cutoff.

3. **Valida tu respuesta**:

   ```bash
   bash tests/validate.sh
   ```

   El validador comprueba que tu `answer.md` contiene los puntos clave (nombres de atributos deprecados, mención a dual-emit, orden de pasos).

**No consultes la solución** hasta haber producido tu `answer.md` y haber corrido `validate.sh`. Hay una solución de referencia en `solution/`.

## 6. Resultado esperado

- `/tmp/otel-02-01-samples/answer.md` existe y pasa `tests/validate.sh`.
- Clasificación correcta de los 3 servicios.
- Plan de migración con 4 pasos y mención explícita a dual-emit.

## 7. Criterios de aceptación

- **Funcionalidad**: `tests/validate.sh` imprime `RESULT: OK` y exit 0.
- **Calidad**: la lista de renombres cubre al menos `http.method`, `http.status_code`, `http.url`, `http.target`, `http.host`.
- **Reproducibilidad**: regenerar los samples y rehacer la respuesta produce el mismo resultado.

## 8. Validación

```bash
bash tests/validate.sh
```

Debe salir con exit 0 y mensaje final `RESULT: OK`.

## 9. Preguntas de reflexión

1. ¿Por qué la comunidad eligió renombrar `http.method` en lugar de añadir un alias? ¿Qué cuesta mantener dos nombres para siempre?
2. En tu organización, ¿quién decide cuándo cortar el dual-emit? ¿Qué métricas usarías para saber que ya es seguro?
3. ¿Qué pasaría si no haces nada y simplemente dejas que los SDKs se actualicen "cuando toque"?
4. ¿Cómo detectarías proactivamente este tipo de deriva en tu plataforma (CI, scraping del Collector, otros)?

## 10. Extensiones

- Añade un cuarto servicio ficticio que emita atributos con nombres propios (`methodName`, `statusCode`) y propone cómo "normalizarlo" con un `transform` processor en el Collector (ver `otel-08`).
- Diseña una query PromQL que **combine** `http.method` y `http.request.method` para que el dashboard sobreviva la migración.

## 11. Limpieza

```bash
rm -rf /tmp/otel-02-01-samples
```
