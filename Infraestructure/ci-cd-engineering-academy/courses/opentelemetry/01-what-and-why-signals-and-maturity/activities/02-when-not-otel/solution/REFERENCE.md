# REFERENCE — otel-01-02-when-not-otel

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Escenario 1 — Greenfield, 3 microservicios Python en EKS

**Decisión:** **OTel SÍ ya.**

**Justificación:**

- **Python SDK está GA** para traces, metrics y logs. Las instrumentation libraries de FastAPI y los drivers habituales están Stable.
- Es greenfield: **no hay costo de migración**. Instrumentar con OTel desde el día 1 es más barato que instrumentar con un cliente propietario y migrar después.
- El backend aún no está elegido → **vendor-neutral importa**: cualquier backend que elijan (Grafana Cloud, Datadog, self-hosted) acepta OTLP.
- Equipo pequeño (2 personas): auto-instrumentation + Collector dan RED básico sin trabajo manual.

**Alternativa / estrategia parcial:** ninguna necesaria. Empezar directo con auto-instrumentation + spans manuales en los puntos clave del dominio.

**Riesgo si lo haces mal:** instrumentar con `prometheus_client` + un cliente de tracing propietario y luego migrar a OTel en 12 meses — doble trabajo evitable.

---

## Escenario 2 — Vendor APM (Datadog) contratado, maduro

**Decisión:** **OTel parcial** (empezar por el borde, dual-emit, no romper lo que funciona).

**Justificación:**

- El valor que da OTel aquí es **futuro** (opción de salir del lock-in), no inmediato. El equipo ya tiene dashboards y runbooks maduros.
- "Migrar todo ya" implica rehacer dashboards, re-entrenar al equipo y asumir riesgo de incidentes por telemetría peor.
- Datadog **acepta OTLP** (vía `exporter/datadog` del Collector o OTLP nativo). → se puede introducir OTel SDK en servicios nuevos y seguir enviando a Datadog **sin perder nada**.
- El contrato está pagado 2 años → urgencia operativa baja; estratégica alta.

**Alternativa / estrategia parcial:**

- Instrumentar con **OTel SDK** los servicios **nuevos** y hacer que el Collector exporte a Datadog.
- Mantener los servicios viejos con el agente de Datadog hasta la próxima migración natural.
- Preparar el *backup plan*: documentar cómo cambiar el exporter si se decide salir de Datadog en 24 meses.

**Riesgo si lo haces mal:** proyecto de 6 meses re-instrumentando sin ganancia operativa visible, pérdida de confianza del equipo en la plataforma de observabilidad.

---

## Escenario 3 — Stack poliglota con SDK inmaduro en un lenguaje

**Decisión:** **OTel parcial** (adoptar en los lenguajes maduros, esperar en el inmaduro).

**Justificación:**

- Node.js y Python: SDK GA, adoptar sin fricción.
- Erlang/Elixir: si algunos signals están Alpha/Beta, usarlos en producción crítica es un riesgo que **no compensa** aún.
- La unificación cross-lenguaje es la **meta**, pero no se logra sacrificando la fiabilidad de la pieza crítica.
- Dos verdades conviven: la **capa de transporte** (OTLP, Collector) puede ser común desde el día 1; el **SDK por lenguaje** se adopta cuando cada uno madura.

**Alternativa / estrategia parcial:**

- Adoptar OTel SDK en Node.js y Python ya; en Erlang/Elixir mantener la instrumentación existente **pero** emitir a un Collector común (vía receiver nativo o adaptador) para unificar transporte.
- Revisar status page de Erlang/Elixir cada 3 meses; migrar signal por signal cuando pasen a GA.

**Riesgo si lo haces mal:** adoptar un SDK Alpha en Erlang/Elixir → una minor rompe en producción y la app crítica queda sin trazas durante un incidente.

---

## Escenario 4 — Esperar a OTel profiling para resolver CPU alto

**Decisión:** **OTel NO (todavía)** para este problema concreto.

**Justificación:**

- **Profiling en OTel está en incubación / Experimental.** No es apto para resolver un problema de producción **hoy**.
- El problema (alto CPU en Go) tiene **herramientas maduras**: `pprof` nativo de Go, Pyroscope / Parca / Pixie para continuous profiling, flamegraphs via `perf`.
- Esperar a profiling OTel para resolver un dolor presente es confundir **adopción de estándar** con **resolución de incidente**.

**Alternativa / estrategia parcial:**

- Resolver **hoy** con `pprof` + Pyroscope/Parca (continuous profiling), que ya emiten en formatos compatibles con OTel cuando esté GA.
- Monitorear la madurez del signal de profiling; migrar cuando pase a Beta/Stable sin dependencia de este incidente.

**Riesgo si lo haces mal:** 3 meses esperando a que un signal en incubación llegue a GA mientras el servicio sigue consumiendo CPU en producción.

---

## Síntesis (modelo)

**Regla de adopción OTel que me llevo:** adoptar OTel **tan pronto** como el SDK del lenguaje y los signals que necesito estén GA, **y** haya al menos un driver real para hacerlo (greenfield, cambio de backend inminente, consolidación cross-equipos). Si no hay driver, adoptar **parcialmente** desde el borde (Collector + nuevos servicios) y esperar al resto.

**Rol del status page en mi decisión:** es el *primer* filtro. Sin verificar lenguaje × signal × instrumentation library × collector components, cualquier decisión es un acto de fe. Reviso **antes** de proponer el plan.

**Impacto de profiling en incubación:** no cuento con él para producción en este horizonte. Resuelvo problemas de CPU/heap con herramientas maduras hoy (`pprof`, Pyroscope, Parca) y migraré cuando el signal estabilice. No pospongo soluciones esperando a profiling OTel.

**7 preguntas-criterio:**

1. ¿Están GA el SDK y los signals que necesito para **cada lenguaje** de mi stack?
2. ¿Las **instrumentation libraries** de mis frameworks principales están Stable/Beta?
3. ¿Tengo **riesgo real** de cambiar de backend en los próximos 18–24 meses?
4. ¿Es **greenfield** o hay **costo de migración** no trivial (dashboards, runbooks, alertas)?
5. ¿El **vendor actual** acepta OTLP? Si sí, puedo dual-emit; si no, el bloqueo es mayor.
6. ¿Tengo el **equipo** para operar un Collector (al menos agent) o solo tengo cabeza para SDK + exporter directo?
7. ¿El signal que **más necesito** está GA, o estoy esperando algo en incubación (p. ej. profiling)?

## Punto a repetir hasta que suene aburrido

> OTel es el estándar al que todos vamos. **Cuándo** llegar depende de madurez (status page), horizonte (riesgo de cambio de backend), costo (greenfield vs brownfield) y equipo. "Siempre ya" es tan erróneo como "nunca".
