# otel-09-02 — ADR: trade-offs de topología del Collector

## 1. Identificación

- **ID:** `otel-09-02-tradeoffs-adr`
- **Tecnología:** opentelemetry
- **Módulo:** 09-collector-deployment-patterns-agent-vs-gateway
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Tu organización va a estandarizar la topología del OpenTelemetry Collector para tres grupos de workloads de escalas muy distintas. Como ingeniero de plataforma, debes producir un **Architecture Decision Record (ADR)** que:

- Justifique la decisión para **cada una** de las tres escalas (10 / 1 000 / 100 000 RPS).
- Describa las alternativas descartadas y por qué.
- Enumere las consecuencias (positivas y negativas).
- Fije límites: cuándo se revisará la decisión.

Esta actividad es intencionalmente **sin solución expuesta**: no hay un `solution/ADR.md` modelo. La validación es *estructural*, no de contenido.

## 3. Objetivos

- Producir un `ADR.md` que respete el formato clásico (MADR-like) con las secciones obligatorias.
- Decidir y justificar la **topología por escala** (10 / 1 000 / 100 000 RPS).
- Articular trade-offs explícitos (coste, pérdida ante falla, overhead, operabilidad).
- Elegir y defender la **distro** del Collector por entorno (al menos 2 entornos).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo.
- Haber terminado la Actividad 01 (vista práctica del patrón agent + gateway).
- No requiere infraestructura ni costos.

## 5. Instrucciones

1. Copia `starter/ADR.template.md` a `ADR.md` en esta misma carpeta.
2. Rellena **todas** las secciones. No borres ninguna.
3. Para cada escala, cubre al menos:
   - Patrón elegido (agent, gateway, agent+gateway, sidecar, sin Collector).
   - Replicas iniciales por capa + estrategia de escalado.
   - Processors en cada capa.
   - Política de queue persistence (sí/no, dónde, por qué).
   - Qué pasa si el backend se cae 5 minutos.
4. Añade una tabla **Distro por entorno** con al menos 2 entornos (p. ej. on-prem + AWS, o AWS + GCP) y la distro elegida con una línea de justificación.
5. Ejecuta `bash tests/validate.sh` para confirmar que la estructura es válida.

**No consultes** la Actividad 01 solution ni los ejemplos para copiar texto literal; debes razonar la decisión.

## 6. Resultado esperado

- Archivo `ADR.md` con las secciones:
  - **Status**
  - **Contexto**
  - **Decisión**
  - **Alternativas consideradas**
  - **Consecuencias**
  - **Trade-offs por escala** (con 3 sub-apartados: `10 RPS`, `1000 RPS`, `100000 RPS`)
  - **Distro por entorno**
  - **Revisión**
- Validador `bash tests/validate.sh` reporta `ALL CHECKS PASSED`.

## 7. Criterios de aceptación

- Estructural (automatizable): las 8 secciones presentes; los 3 sub-apartados de escala presentes; palabras clave como `agent`, `gateway`, `sending_queue`, `HPA`, `distro` aparecen al menos una vez.
- Contenido (revisión humana): decisiones diferentes para escalas distintas; alternativas con motivo real; consecuencias que incluyen *trade-offs negativos* (si todas son positivas, falta rigor).
- Longitud razonable: ≥ 150 palabras, ≤ 1 500. No un volcado de documentación.

## 8. Validación

```bash
bash tests/validate.sh
```

Comprueba estructura del Markdown y presencia de secciones y keywords. No evalúa calidad del razonamiento (eso es revisión humana).

## 9. Preguntas de reflexión

1. Para 100 000 RPS, ¿qué processor y qué política de sampling son indispensables para que la factura no explote?
2. ¿En qué caso elegirías explícitamente el patrón "sin Collector"? ¿Qué debe cumplirse?
3. Si tu organización usa 90 % AWS pero tiene un cluster on-prem, ¿cómo manejas la coexistencia ADOT + otelcol-contrib?
4. ¿Qué métrica del propio Collector usarías como alarma de saturación temprana?
5. ¿Qué cambia en el ADR si en 1 año se activa service mesh con mTLS entre pods?

## 10. Extensiones

- **E1.** Añade una sección "Rollout plan" al ADR con pasos de migración desde "sin Collector" hasta "agent + gateway" en un cluster existente.
- **E2.** Añade una sección "Observabilidad del propio Collector" con las métricas, logs y traces del Collector que monitorizarás y las alertas que generarás.

## 11. Limpieza

Esta actividad no crea recursos de infraestructura. Puedes dejar `ADR.md` en la carpeta o moverlo a tu repositorio personal de ADRs.
