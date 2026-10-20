# ADR — Contrato de telemetría de la plataforma (Nimbora Finance)

## 1. Estado

TODO — proposed | accepted | superseded

## 2. Fecha

TODO — YYYY-MM-DD

## 3. Autores

- TODO — Nombre, rol
- TODO — Nombre, rol

## 4. Contexto

Describe el estado actual de la observabilidad en Nimbora (3-6 párrafos): backends vigentes (Datadog, Prometheus, Jaeger huérfano, Splunk), síntomas (fragmentación, factura 4x, incidente de cardinalidad), presión de dirección ("plan para no depender de Datadog").

TODO

## 5. Riesgos del status quo

Enumera al menos **3 riesgos concretos** del esquema actual.

- TODO — riesgo 1
- TODO — riesgo 2
- TODO — riesgo 3

## 6. Decisión

**Decisión:** TODO — frase única que resume la decisión (ej. "Adoptar el patrón 'equipos emiten OTLP, plataforma decide backend' con Collector como única frontera, pin de SemConv v1.27.0 y prohibición explícita de atributos vendor-prefixed").

### 6.1 MUST (obligaciones de los equipos)

TODO — lista.

### 6.2 MUST NOT (prohibiciones)

Prohíbe explícitamente al menos 5 prefijos de atributos propietarios.

- `dd.*`
- `datadog.*`
- `newrelic.*`
- TODO — añade al menos 2 más
- TODO
- TODO

### 6.3 SLOs de la plataforma

Define al menos 4 SLOs cuantificados.

| SLI | Target |
| --- | --- |
| TODO | TODO |
| TODO | TODO |
| TODO | TODO |
| TODO | TODO |

### 6.4 Proceso de deprecación de SemConv

Describe el proceso con ventana de dual-emit y fecha de cutover. Debe mencionar explícitamente las palabras "dual-emit" y "cutover".

TODO

## 7. Alternativas consideradas

Enumera al menos **2 alternativas** con pros/contras.

- TODO — alternativa 1
- TODO — alternativa 2

## 8. Consecuencias

TODO — qué cambia, qué queda estable, costo operacional, lock-in reducido pero no cero, etc.

## 9. Plan de migración

Enumera al menos **3 pasos** cronológicos.

1. TODO — paso 1
2. TODO — paso 2
3. TODO — paso 3
