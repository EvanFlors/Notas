# Certificación OpenTelemetry — Examen Sumativo

- **Curso:** `opentelemetry`
- **Nivel:** intermedio-avanzado
- **Dimensiones evaluadas:** conceptual, operativa, arquitectónica (`todas`)
- **Duración:** 110 minutos (rango 90–120)
- **Umbral de aprobación:** 70% del puntaje total
- **Modalidad:** take-home con entorno virtualizado (Python 3.11+ y Collector local). Si el ejercicio operativo requiere binarios que el candidato no puede instalar, se marcará como **SKIP** y se recalculará el denominador (ver sección 3).
- **Idioma:** prosa en español; código, YAML, logs, nombres de archivo y comandos en inglés.

> **Nota de integridad.** Este examen prioriza la demostración de **por qué** sobre la repetición de **qué**. Memorizar banderas de CLI no aprueba. Reproducir ejemplos sin adaptarlos a los enunciados tampoco.

---

## 1. Matriz de competencias evaluadas

| ID       | Competencia                                                                                                         | Dimensión     | Peso |
|----------|---------------------------------------------------------------------------------------------------------------------|---------------|------|
| OTEL-C1  | Leer y descomponer un header W3C `traceparent` y explicar su rol en continuidad cross-service                       | Conceptual    | 10   |
| OTEL-C2  | Aplicar Semantic Conventions vigentes y justificar impacto de migraciones breaking                                  | Conceptual    | 10   |
| OTEL-C3  | Diagnosticar trace "cortado": inject/extract, propagators, context en async                                         | Conceptual    | 10   |
| OTEL-C4  | Comparar head-based vs tail-based sampling con criterio de costo, visibilidad y consistencia                        | Conceptual    | 10   |
| OTEL-C5  | Explicar temporalidad `cumulative` vs `delta` y predecir síntoma de mismatch                                        | Conceptual    | 5    |
| OTEL-O1  | Instrumentar Python/FastAPI con auto + spans manuales y exportar OTLP                                               | Operativa     | 20   |
| OTEL-O2  | Configurar Collector multi-pipeline con processors y exporters correctos                                            | Operativa     | 15   |
| OTEL-A1  | Diseñar topología de Collector para una org dada (ADR)                                                              | Arquitectónica| 10   |
| OTEL-A2  | Diseñar política de sampling tail-based con presupuesto de memoria                                                  | Arquitectónica| 10   |
| **Total**|                                                                                                                     |               |**100**|

Aprobación: **≥ 70 puntos**. Si OTEL-O1 u OTEL-O2 se marcan **SKIP** por entorno, el peso se redistribuye proporcionalmente sobre las dimensiones restantes y se exige **≥ 70%** del nuevo denominador.

---

## 2. Preguntas conceptuales (dimensión conceptual — 45 pts, ~35 min)

> Responder en prosa breve (3–8 frases por pregunta) salvo cuando se pide tabla.

### Q1 — `traceparent` descompuesto (OTEL-C1, 10 pts)

Dado el header recibido por un servicio B:

```http
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
tracestate:  rojo=t61rcWkgMzE
```

1. Identifica los cuatro campos del `traceparent` y qué significa cada uno.
2. ¿Qué información aporta `tracestate` que `traceparent` no cubre?
3. Si el servicio B registra un nuevo span bajo este contexto, ¿qué valor NO cambia respecto al header recibido y por qué eso es imprescindible para que Tempo arme el trace?

### Q2 — Breaking change de Semantic Conventions (OTEL-C2, 10 pts)

Tu plataforma emite spans HTTP con el atributo legacy `http.method`. Un dashboard en Grafana filtra por `http.method = "POST"`. Un equipo actualiza su SDK y empieza a emitir `http.request.method` (semconv HTTP v1 estable).

1. ¿Qué pasa con el dashboard y por qué?
2. Explica una estrategia de **dual-emit transitorio** en el Collector (sin cambiar código de las apps) usando el procesador apropiado.
3. ¿Por qué no basta con renombrar en la query de Grafana y seguir?

### Q3 — Trace cortado entre dos servicios (OTEL-C3, 10 pts)

Un servicio A (FastAPI, instrumentado con `opentelemetry-instrumentation-fastapi` y `opentelemetry-instrumentation-httpx`) llama a un servicio B (Flask, instrumentado con `opentelemetry-instrumentation-flask`). En Tempo se ven **dos traces independientes**: uno con un único span de A y otro con un único span de B.

Enumera **tres causas plausibles distintas**, ordenadas de más a menos probable, y para cada una describe el síntoma distintivo que confirmaría la hipótesis sin cambiar código todavía.

### Q4 — Head vs tail sampling (OTEL-C4, 10 pts)

Operas 50 microservicios Python emitiendo 20 000 spans/s en total. El equipo de FinOps exige reducir el volumen a Tempo en 10×, pero el equipo de SRE exige **ver el 100% de los traces con error** y **el 100% de los traces con latencia > p99**.

1. ¿Puede resolverse esto con head-based `ParentBased(TraceIdRatioBased(0.1))`? Justifica en términos de qué información está disponible en el root span.
2. Describe la política tail-based mínima que cumple ambos SLAs. Indica dónde se configura y qué estado mantiene el Collector.
3. ¿Qué rompe la **consistencia** del sampling si el servicio raíz no propaga `tracestate`?

### Q5 — Temporalidad mismatch (OTEL-C5, 5 pts)

Migraste una métrica `requests_total` de `prometheus_client` a OTel SDK y la exportas vía OTLP al Collector, que a su vez remote-writea a Prometheus. En Grafana la métrica aparece **plana en cero** o con **picos imposibles**, aunque los logs confirman tráfico.

Diagnóstico en una frase y configuración mínima a cambiar (nombre del parámetro o processor) para arreglarlo.

---

## 3. Ejercicio operativo (dimensión operativa — 35 pts, ~45 min)

**SKIP condicional:** si el candidato declara por escrito que no puede ejecutar Python 3.11 **o** no puede descargar el binario `otelcol-contrib`, el ejercicio se marca **SKIP** y los 35 pts se redistribuyen sobre las dimensiones restantes.

### Enunciado

Dado el starter en `operative/`, el candidato debe:

1. **Instrumentar** la aplicación `app.py` (FastAPI con un endpoint `GET /checkout/{order_id}`) de forma que:
   - Use **auto-instrumentation** para FastAPI y `httpx`.
   - Agregue **un span manual** llamado `checkout.compute_total` como hijo del span HTTP, con atributos:
     - `order.id` (del path param)
     - `order.item_count` (int, del request simulado)
     - `payment.method` (string)
   - Registre un **evento** `discount_applied` cuando el total supere 100.
   - Registre `span.record_exception(e)` y `span.set_status(Status(StatusCode.ERROR))` cuando el `order_id` sea `fail`.
   - Use `Resource` con `service.name=checkout`, `service.version=1.0.0`, `deployment.environment=exam`.
   - Exporte vía **OTLP/gRPC** a `localhost:4317`.

2. **Configurar** el `otel-collector-config.yaml` (starter incluido con huecos marcados `# TODO`) para una pipeline de **traces** que:
   - Reciba OTLP gRPC en `0.0.0.0:4317`.
   - Aplique `memory_limiter` (limit 256 MiB), `batch`, y un `attributes` processor que **inserte** `env=exam` y **borre** cualquier atributo cuyo nombre empiece por `user.email`.
   - Exporte a `debug` (verbosity detailed) y a `file` (`./out/traces.json`).
   - Pase `otelcol validate`.

### Materiales de inicio

- `operative/app.py` — FastAPI skeleton con `TODO` marcados.
- `operative/otel-collector-config.yaml` — pipeline con huecos.
- `operative/requirements.txt` — dependencias OTel pinned.
- `operative/README.md` — instrucciones de ejecución.
- `operative/validate.sh` — script de validación (ver abajo).

### Entregables

- `app.py` corregido.
- `otel-collector-config.yaml` corregido.
- `out/traces.json` con **al menos 3 spans** generados por una petición exitosa y una fallida.
- `run.log` con el output del Collector mostrando los spans en formato debug.

### Procedimiento de validación

El script `operative/validate.sh` ejecuta:

```bash
otelcol-contrib validate --config operative/otel-collector-config.yaml
jq -e '
  [.resourceSpans[].scopeSpans[].spans[]
   | select(.name=="checkout.compute_total")] | length >= 1
' operative/out/traces.json
jq -e '
  [.resourceSpans[].resource.attributes[]
   | select(.key=="service.name" and .value.stringValue=="checkout")] | length >= 1
' operative/out/traces.json
jq -e '
  [.resourceSpans[].scopeSpans[].spans[]
   | select(.status.code==2)] | length >= 1
' operative/out/traces.json
! jq -e '
  [.resourceSpans[].scopeSpans[].spans[].attributes[]
   | select(.key | startswith("user.email"))] | length > 0
' operative/out/traces.json
```

Los cinco checks deben pasar.

---

## 4. Ejercicio arquitectónico (dimensión arquitectónica — 20 pts, ~25 min)

Ver `architectural/scenario.md` para el escenario completo. El candidato debe entregar:

1. **Diagrama de topología** (ASCII/Mermaid aceptado) con componentes, protocolos y puertos.
2. **ADR** (formato Nygard o MADR) de **1 página** respondiendo:
   - Decisión de topología (agent-only, gateway-only, agent+gateway, sidecar).
   - Política de sampling (head, tail, mix) con parámetros (`decision_wait`, `num_traces`).
   - Trade-offs considerados y descartados (al menos 2 alternativas).
3. **Snippet YAML** del `tail_sampling` processor con las policies elegidas.

Rúbrica detallada en sección 5.

---

## 5. Rúbrica

### 5.1 Preguntas conceptuales (Q1–Q5)

Puntaje por pregunta usando la siguiente escala por criterio, promediada:

| Criterio                | Insuficiente (0)                                   | Básico (1)                                      | Competente (2)                                           | Experto (3)                                                                 |
|-------------------------|----------------------------------------------------|-------------------------------------------------|----------------------------------------------------------|-----------------------------------------------------------------------------|
| Corrección técnica      | Afirmaciones falsas o invertidas                   | Idea general correcta, detalles errados         | Correcta y precisa, menor imprecisión tolerable          | Correcta, precisa y con matices (consistent sampling, breaking semconv, etc.)|
| Razonamiento (por qué)  | No justifica                                       | Repite la pregunta como justificación           | Deriva de principios (data model, context, OTLP)         | Conecta con operación real (costo, blind spots, cardinalidad)               |
| Semántica OTel          | Confunde API/SDK/Collector o signals               | Usa terminología correcta de forma mecánica     | Usa terminología correcta y aplicada                     | Distingue casos límite (orphan spans, propagators, tracestate)              |

Peso por pregunta se mapea a los puntos declarados en §1.

### 5.2 Ejercicio operativo (OTEL-O1 + OTEL-O2)

| Criterio               | Insuficiente (0)                     | Básico (1)                                           | Competente (2)                                                       | Experto (3)                                                                 |
|------------------------|--------------------------------------|------------------------------------------------------|----------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Instrumentación Python | No emite spans / falla al arrancar   | Auto-instr funciona, falta span manual               | Auto + span manual + atributos + status/exception                    | Resource completo, span kind correcto, sin atributos ruidosos               |
| Collector config       | `otelcol validate` falla             | Validate OK, pero falta `memory_limiter` o `batch`   | Pipeline completo, processors en orden correcto                      | `attributes` processor con insert+delete bien, exporters múltiples OK       |
| Validación automática  | 0–1 checks pasan                     | 2–3 checks pasan                                     | 4 checks pasan                                                       | 5 checks pasan y output limpio                                              |
| Operabilidad           | Requiere ajustes manuales no triviales| Corre con un paso extra documentado                 | Corre con `./validate.sh` sin intervención                           | Idempotente, logs legibles, `out/` reproducible                             |

Cada criterio ponderado 25% del bloque operativo.

### 5.3 Ejercicio arquitectónico (OTEL-A1 + OTEL-A2)

| Criterio               | Insuficiente (0)                                 | Básico (1)                                          | Competente (2)                                                       | Experto (3)                                                                   |
|------------------------|--------------------------------------------------|-----------------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------------------------------------|
| Topología              | Elige sin justificar o escoge sidecar sin motivo | Agent **o** gateway sin considerar el otro          | Agent+gateway con rationale de batching y back-pressure              | Añade queue persistente, HPA, failure domain y plan de upgrade                |
| Sampling               | Head-only o tail-only sin criterio               | Tail con 1 policy (errors)                          | Tail con `status_code` + `latency` + `probabilistic` + `decision_wait`| Presupuesta memoria (`num_traces`) y maneja consistencia con `tracestate`     |
| ADR                    | Decisión sin alternativas                        | Lista alternativas sin trade-offs                   | Trade-offs claros con 2 alternativas descartadas                     | Trade-offs cuantificados (costo, latencia, blast radius) + riesgos abiertos   |
| Vendor neutrality      | Acopla a un vendor sin razón                     | OTLP mencionado pero no central                     | OTLP end-to-end, Collector como punto único de decisión              | Demuestra swap de backend sin tocar app                                       |

### 5.4 Umbral y agregación

- Total 100 pts.
- Aprobación: **≥ 70 pts**.
- **No se aprueba** si cualquier **red flag** de §6.3 aparece, aun con 70 pts.
- SKIP de operativo documentado → recalcular denominador y exigir ≥ 70%.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo (resumen)

**Q1.** `00` version, `4bf9…4736` trace-id (16 bytes hex), `00f0…02b7` parent-id (8 bytes hex, span-id del caller), `01` flags (sampled). `tracestate` lleva estado vendor-specific/consistent-sampling. El `trace-id` NO cambia; es la clave con la que Tempo agrupa spans en un árbol. (Puntos clave: 16/8 bytes, flag `sampled`, invariancia del trace-id.)

**Q2.** El dashboard se queda vacío/parcial para los servicios actualizados porque filtra por un atributo que ya no se emite. Dual-emit transitorio con `transform` processor (OTTL): copiar `http.request.method` → `http.method` por N semanas. Renombrar en la query es una tirita por dashboard: no cubre alertas, exports, exemplars, y es N×M.

**Q3.** Causas típicas (orden razonable):
1. B no tiene propagator `tracecontext` configurado (ni habilitado por default en versión antigua) → recibe header pero no lo extrae. Síntoma: span de B tiene parent vacío.
2. A no instrumenta correctamente httpx (olvidó `HTTPXClientInstrumentor().instrument()`) → no inyecta `traceparent`. Síntoma: request a B llega sin header `traceparent`.
3. Context perdido por `ThreadPoolExecutor`/`asyncio.to_thread` sin copiar context. Síntoma: span manual dentro del executor es root.

**Q4.** Head no basta: en el root span no se conoce el status final ni la latencia. Tail policy mínima: `status_code=ERROR` + `latency gt_ms=<p99>` + `probabilistic sampling 10%`. Configurado en gateway (no agent) por `tail_sampling` processor; mantiene buffer en memoria por `decision_wait` segundos (típico 10–30 s) y `num_traces`. Sin `tracestate` no hay consistent sampling → dos servicios pueden decidir distinto y se pierde la mitad del trace.

**Q5.** Backend Prometheus espera cumulative; SDK está emitiendo delta (o viceversa). Fix: `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` en el SDK, o `cumulativetodeltaprocessor` / `deltatocumulativeprocessor` en el Collector.

### 6.2 Errores comunes

- Confundir `traceparent` con `tracestate` o inventar que el span-id del header es del callee.
- Proponer "borrar el dashboard viejo" como estrategia de migración semconv (no es dual-emit).
- Marcar `AlwaysOn` sampler y decir que "soluciona" el costo.
- Omitir `memory_limiter` o ponerlo después de `batch` (debe ir **primero** para proteger el proceso).
- Instrumentar `requests` cuando el código usa `httpx` (señal de copiar-pegar).
- Hardcodear endpoint OTLP sin usar env var y luego no documentarlo.

### 6.3 Red flags (invalidan la respuesta)

- Secretos hardcodeados en `app.py` o en el YAML (API keys, tokens Bearer en claro commiteados).
- Export directo del SDK a un vendor comercial sin pasar por Collector cuando el enunciado pide "pipeline local" (ignora el requisito explícito).
- `curl | bash` para instalar `otelcol-contrib` desde fuente no oficial.
- Baggage con PII (email, DNI, tarjeta) como "solución" a propagar contexto de negocio.
- `exporters: [debug]` como único exporter en producción propuesta (confunde debug con backend).
- `cluster-admin` o permisos equivalentes propuestos para el Operator sin justificar.
- Deshabilitar TLS en el escenario arquitectónico "por simplicidad".

### 6.4 Preguntas de seguimiento (evaluación en vivo)

Para distinguir memorización de comprensión, el instructor puede preguntar:

1. **Sobre Q1:** "Si el flag fuera `00` en lugar de `01`, ¿qué debería hacer B?" (Esperado: respetarlo; no muestrear a menos que haga tail-based en el Collector.)
2. **Sobre Q3:** "El candidato dice que es el propagator; ¿cómo lo verifica en 1 minuto sin cambiar código?" (Esperado: inspeccionar headers con `tcpdump`/`mitmproxy` o loggear request en B.)
3. **Sobre Q4:** "¿Qué pasa si pones el `tail_sampling` en el agente DaemonSet en vez de en el gateway?" (Esperado: cada agente ve solo spans locales; no puede decidir sobre el trace completo.)
4. **Sobre operativo:** "¿Por qué `BatchSpanProcessor` y no `SimpleSpanProcessor`?" (Esperado: throughput, no bloquea request path.)
5. **Sobre arquitectónico:** "Mañana el CFO exige cambiar de Tempo self-hosted a Grafana Cloud. ¿Qué cambia en el código de las apps?" (Esperado: nada; solo el exporter del gateway.)

### 6.5 Señales de "respondió sin entender"

- Copió el `traceparent` del enunciado tal cual al explicarlo, sin descomponerlo.
- Describe `batch` processor antes que `memory_limiter`.
- Dice "sampling probabilístico 10%" sin especificar cuándo decide (root span vs collector).
- Entrega `app.py` con `print(span)` en lugar de usar atributos.
- Entrega ADR con "elegimos agent+gateway porque es la mejor práctica" sin trade-offs.

---

## 7. Instrucciones de entrega

El candidato debe entregar un `tar.gz` con:

```
exam-submission/
├── answers.md            # Respuestas Q1–Q5
├── operative/
│   ├── app.py
│   ├── otel-collector-config.yaml
│   ├── out/traces.json
│   └── run.log
└── architectural/
    ├── diagram.md        # Mermaid/ASCII
    ├── adr.md
    └── tail-sampling.yaml
```

El corrector ejecuta `operative/validate.sh` sobre la entrega. Para la parte arquitectónica, aplica la rúbrica de §5.3 sin ejecutar el YAML pero verificando que `otelcol validate` lo aceptaría.
