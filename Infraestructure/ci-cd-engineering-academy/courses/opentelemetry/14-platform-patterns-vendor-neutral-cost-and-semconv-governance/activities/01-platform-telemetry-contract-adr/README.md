# otel-14-01 — ADR: contrato de telemetría de la plataforma

## 1. Identificación

- **ID:** `otel-14-01-platform-telemetry-contract-adr`
- **Tecnología:** opentelemetry
- **Módulo:** `14-platform-patterns-vendor-neutral-cost-and-semconv-governance`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent (ADR)

## 2. Contexto

Redactas el **ADR** que fija el contrato de telemetría para la siguiente organización ficticia:

> **Nimbora Finance** — fintech regulada en EU, ~60 microservicios en Python/Go/Node, Kubernetes multi-cluster (EU-WEST, EU-NORTH), ~2k RPS en pico. Hoy conviven: Datadog (contratado por el equipo de producto hace 2 años, factura mensual que creció 4x), Prometheus self-hosted (SRE, para infra), Jaeger (abandonado, deployment huérfano), Splunk (compliance, logs de auditoría). Dashboards fragmentados en tres UIs. Un incidente reciente: una métrica con `user_id` como label hizo colapsar un ingester de Prometheus. La dirección pide: "un plan para no depender de Datadog" sin romper lo que ya funciona.

Tu trabajo: redactar el **ADR** del contrato de telemetría. El validador comprueba la **estructura** del ADR — no evalúa tu criterio por ti; eso lo hace la revisión humana.

> No reveles aquí la "respuesta correcta". El ADR es tu respuesta y se discute en revisión con tu lead.

## 3. Objetivos

Al terminar deberías poder:

- Redactar un ADR con contexto, decisión, consecuencias y alternativas.
- Prohibir explícitamente al menos **5 prefijos de atributos propietarios** (`dd.*`, `datadog.*`, `newrelic.*`, `splunk.*`, `honeycomb.*`, etc.).
- Definir al menos **4 SLOs medibles** de la propia plataforma (ingest availability, ingest latency, drop rate, exemplar coverage, u otros).
- Describir el proceso de **deprecación de SemConv** con ventana de dual-emit y fecha de cutover.
- Enumerar al menos **3 riesgos del status quo** (lock-in Datadog, fragmentación, cardinalidad descontrolada).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (secciones 1-11).
- Haber hecho `otel-11-01`, `otel-12-01`, `otel-13-01`.
- Un editor de texto. Nada que instalar.
- Sin coste.

## 5. Instrucciones

1. Copia la plantilla a scratch:

   ```bash
   mkdir -p /tmp/otel-14-01
   cp activities/01-platform-telemetry-contract-adr/starter/ADR-telemetry-contract.md /tmp/otel-14-01/ADR-telemetry-contract.md
   ```

2. Edítala. Rellena **cada sección**. La plantilla te marca qué va en cada una.

3. Para la sección "6. Decisión", redacta un contrato con subsecciones **MUST**, **MUST NOT**, **SLOs**, **Deprecations**. Debe prohibir atributos propietarios con una lista explícita.

4. Para la sección "7. Alternativas consideradas", enumera **≥ 2 alternativas** (p. ej. "quedarse con Datadog y renegociar", "migrar todo a self-hosted ya", "multi-cloud híbrido permanente") con pros/contras.

5. Para la sección "9. Plan de migración" enumera **≥ 3 pasos** cronológicos.

6. Elimina todos los marcadores `TODO`.

7. Valida la estructura:

   ```bash
   bash activities/01-platform-telemetry-contract-adr/tests/validate.sh
   ```

## 6. Resultado esperado

- Archivo `/tmp/otel-14-01/ADR-telemetry-contract.md` con 9 secciones completas, sin `TODO`, con la lista de prefijos prohibidos, los SLOs definidos y el proceso de deprecación.
- Validador imprime `RESULT: N/N checks OK.` dos veces seguidas.

## 7. Criterios de aceptación

| Dimensión | Criterio |
| --- | --- |
| Funcionalidad | Todas las secciones del ADR presentes. |
| Calidad | Prohibición vendor con lista explícita; SLOs cuantificados (números, no "rápido"). |
| Seguridad | Si menciona credenciales/tokens, están referenciadas por Secret, no literales. |
| Reproducibilidad | Validador OK dos veces seguidas. |
| Mantenibilidad | Fechas de revisión del contrato definidas (p. ej. trimestral). |

## 8. Validación

```bash
bash activities/01-platform-telemetry-contract-adr/tests/validate.sh
```

Smoke test manual: correrlo dos veces para confirmar idempotencia.

## 9. Preguntas de reflexión

- Un comercial de Datadog ofrece 50% de descuento a cambio de que uses "Live Processes" (propietario). ¿Cómo lo rebates manteniendo neutralidad?
- Un equipo pide excepción para añadir `dd.service` "temporalmente". ¿Cuál es tu respuesta y bajo qué condiciones?
- Si tu plataforma declara 99.9% de ingest availability, ¿cómo lo mides en la práctica? ¿Qué pasa cuando el Collector mismo cae?
- La migración "sin romper nada" en una org con Datadog embebido ¿es realista? ¿Qué sacrificas?

## 10. Extensiones

- Añade una sección "Shadow mode" explicando cómo multi-exportar a dos backends durante 4 semanas para comparar sin cortar nada.
- Diseña el dashboard "meta-observabilidad" (los SLIs de la plataforma) como JSON de Grafana en un apéndice.
- Documenta un drill: cómo probarías mensualmente que el switch de vendor funciona.

## 11. Limpieza

```bash
rm -rf /tmp/otel-14-01
```
