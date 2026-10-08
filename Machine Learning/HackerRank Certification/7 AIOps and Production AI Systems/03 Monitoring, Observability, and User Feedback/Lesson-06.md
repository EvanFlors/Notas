# Dashboards, Respuesta a Incidentes y Estrategia Integral

## ¿Qué es?

Una **estrategia integral de monitoreo** une todo lo visto en las lecciones anteriores (señales doradas, observabilidad, drift, performance, feedback) en un sistema coherente: dashboards por audiencia, alertas con severidad, runbooks accionables, protocolo de incidentes y postmortems que generan aprendizaje.

Un buen sistema de monitoreo no es solo tecnología; es también **cultura**: la forma en que el equipo responde cuando algo falla y aprende de ello.

## ¿Por qué importa?

- Sin **dashboards para cada audiencia**, el equipo no tiene lenguaje común: SRE, ML engineers, product managers y ejecutivos necesitan vistas distintas de la misma realidad.
- Sin **runbooks**, el conocimiento vive en la cabeza del ingeniero senior y desaparece cuando él duerme o se va.
- Sin **postmortems blameless**, los incidentes se repiten y la gente aprende a esconder errores.
- La estrategia determina si los $100k en herramientas de observabilidad producen valor o solo producen dashboards bonitos que nadie mira.

## ¿Cómo funciona?

### Estrategia por niveles (tiered monitoring)

| Nivel | Audiencia | Frecuencia | Preguntas que responde |
|---|---|---|---|
| **L1 Executive** | C-level, product | Diario / semanal | ¿El producto crece? ¿Satisface a usuarios? ¿Cuánto cuesta? |
| **L2 Business / Product** | PM, data analysts | Diario | CTR, conversión, retención, NPS, segmentación |
| **L3 Model Health** | ML engineers | Horario | Drift, calibración, performance, feedback |
| **L4 Service Health** | SRE, backend | Minuto | Latencia, errores, saturación, deploys |
| **L5 Infrastructure** | Platform / SRE | Segundo | CPU, GPU, memoria, red, discos |

Las métricas fluyen hacia arriba (una caída en L5 puede causar un problema en L1), pero cada nivel debe poder diagnosticar su propio dominio sin pedir ayuda a los otros niveles.

### Diseño de dashboards (principios)

1. **Una pregunta por dashboard**: "¿Está sano el servicio?", "¿Cómo va el experimento X?". No mezclar.
2. **La información más importante arriba a la izquierda** (regla de lectura).
3. **Comparar siempre contra una línea base**: valor absoluto sin contexto no ayuda. Mostrar hoy vs. 7 días atrás, o vs. baseline esperado.
4. **Usar colores con significado**: rojo = malo, verde = bueno, amarillo = sospechoso. Nunca por estética.
5. **Mostrar incertidumbre**: bandas p50-p95, intervalos de confianza en experimentos.
6. **Enlazar a runbooks y a traces** desde cada panel.
7. **Menos es más**: 6-10 paneles por dashboard. Más es ruido.

### Protocolo de respuesta a incidentes

1. **Detectar**: alerta automática, reporte de usuario, observación interna.
2. **Triaje**: ¿severidad P0-P3? ¿quién es el on-call? ¿se necesita incident commander?
3. **Comunicar**: canal dedicado (`#incident-2026-10-07-llm-latency`), status page si afecta a clientes.
4. **Mitigar**: lo primero es **parar el daño** (rollback, reducir tráfico, deshabilitar feature) antes que investigar la causa.
5. **Investigar**: con la mitigación aplicada, ahora sí buscar causa raíz.
6. **Resolver**: fix permanente, verificación.
7. **Postmortem**: documento blameless con timeline, impacto, causa raíz, acciones correctivas.

### Runbooks: la memoria del equipo

Cada alerta debe tener un runbook enlazado. Un runbook mínimo contiene:

- **Síntoma** que dispara la alerta.
- **Impacto esperado** en el usuario.
- **Primera verificación** (comandos, dashboards a abrir).
- **Mitigaciones conocidas** (rollback, scale up, flush cache).
- **Escalación**: a quién llamar si no funciona.

Ejemplo de runbook corto para `LLMCostSpike`:

```markdown
# LLMCostSpike

**Síntoma**: costo proyectado > $50/hora durante 10m.
**Impacto**: fuga económica. Puede reflejar abuso, bug o prompt bloat.

## Paso 1: ¿quién consume?
- Dashboard `cost-by-tenant` (link).
- Si un tenant concentra >50%, posible abuso. Rate-limit temporal.

## Paso 2: ¿tokens por request subió?
- Dashboard `tokens-per-req` (link). Si sí, posible prompt bloat tras deploy reciente.
- `git log --since="24 hours"` en el servicio del prompt.

## Paso 3: ¿cache funcionando?
- `cache_hit_rate` debería ser >60%. Si cayó, revisar Redis.

## Escalación
- Si no se mitiga en 15m, paginar on-call senior.
```

### Postmortems blameless

Un postmortem efectivo:

- **Enfoca en sistemas, no en personas**: no "Juan desplegó mal" sino "no teníamos canary deploy automatizado".
- **Timeline detallado** con timestamps y acciones.
- **Impacto cuantificado**: usuarios afectados, requests fallidos, ingresos perdidos.
- **Causa raíz** usando técnicas como **5 whys**.
- **Acciones correctivas con dueño y fecha**: sin esto, el postmortem es terapia.
- **Compartido ampliamente**: el aprendizaje se propaga.

Una cultura blameless no significa "sin consecuencias"; significa **separar el error de la persona** y atacar las condiciones que lo permitieron.

### Métricas de madurez del monitoreo

| Métrica | Qué mide | Objetivo típico |
|---|---|---|
| **MTTD** (Mean Time To Detect) | Minutos entre fallo y alerta | < 5 min para P0 |
| **MTTR** (Mean Time To Resolve) | Minutos entre alerta y mitigación | < 30 min para P0 |
| **Alert precision** | % alertas accionables | > 70% |
| **Postmortem coverage** | % incidentes con postmortem | 100% para P0/P1 |
| **Action item completion** | % acciones correctivas cerradas | > 80% en 30 días |

### Diseño de un dashboard de salud de LLM (ejemplo)

```
┌──────────────────────────────────────────────────────────┐
│ FILA 1 (visión general)                                  │
│  [RPS] [p95 latencia] [error rate] [costo/hora]          │
├──────────────────────────────────────────────────────────┤
│ FILA 2 (calidad)                                         │
│  [thumbs ratio]  [llm-judge score p50/p95]               │
│  [regenerate rate] [tasa de hallucination flaggeada]     │
├──────────────────────────────────────────────────────────┤
│ FILA 3 (drift)                                           │
│  [embedding drift p95]  [top-5 queries que driftan]      │
├──────────────────────────────────────────────────────────┤
│ FILA 4 (desglose)                                        │
│  [latencia por etapa del pipeline]                       │
│  [tokens por request, trend 7d]                          │
└──────────────────────────────────────────────────────────┘
```

## Ejemplo con código

### Alertas Prometheus organizadas por severidad

```yaml
groups:
  - name: llm-service-slo
    interval: 30s
    rules:
      # P0 - paginar inmediatamente
      - alert: LLMServiceDown
        expr: up{job="llm-service"} == 0
        for: 1m
        labels: {severity: P0, team: ml-platform}
        annotations:
          summary: "Servicio LLM caído"
          runbook: "https://wiki/runbooks/llm-service-down"

      - alert: LLMErrorBudgetBurn
        expr: |
          (
            sum(rate(llm_requests_total{status="error"}[1h]))
            / sum(rate(llm_requests_total[1h]))
          ) > (14.4 * 0.001)   # burn 14.4x el budget mensual de 0.1%
        for: 5m
        labels: {severity: P0}
        annotations:
          summary: "Error budget quemándose rápido"

      # P1
      - alert: LLMLatencyP95High
        expr: histogram_quantile(0.95, rate(llm_request_latency_seconds_bucket[5m])) > 3
        for: 10m
        labels: {severity: P1}
        annotations:
          summary: "Latencia p95 > 3s"
          runbook: "https://wiki/runbooks/llm-latency"

      # P2
      - alert: EmbeddingDriftWarning
        expr: embedding_drift_p95 > 0.55
        for: 30m
        labels: {severity: P2}
        annotations:
          summary: "Drift semántico sostenido"

      # P2
      - alert: LLMJudgeScoreDrop
        expr: avg_over_time(llm_judge_score_mean[1h]) < 3.8
        for: 1h
        labels: {severity: P2}
        annotations:
          summary: "Score del juez LLM < 3.8 durante 1h"
```

### Template de postmortem (markdown)

```markdown
# Postmortem — Incidente 2026-10-07 LLM Latency

**Severidad**: P1
**Duración**: 2026-10-07 14:12 UTC → 15:48 UTC (96 min)
**Impacto**: 12% de requests > 10s. ~3,400 usuarios afectados.

## Timeline (UTC)
- 14:12  Alerta `LLMLatencyP99High` dispara.
- 14:14  On-call reconoce. Abre canal `#incident-2026-10-07`.
- 14:21  Se descarta problema de GPU (dashboard infra OK).
- 14:35  Hipótesis: timeout del reranker. Confirmado en traces.
- 14:50  Rollback del deploy `reranker:v2.3` → `v2.2`. Latencia baja.
- 15:48  Métricas estables 1h. Incidente cerrado.

## Causa raíz
`reranker:v2.3` cargaba el modelo en cada request por bug en el singleton.
Latencia por request subió de 30 ms a 1200 ms.

## Por qué no lo detectó CI
Tests unitarios no miden cold-start. No había load test en el pipeline.

## Acciones correctivas
| # | Acción | Dueño | Fecha |
|---|---|---|---|
| 1 | Añadir load test en CI | @ana | 2026-10-14 |
| 2 | Canary deploy obligatorio para reranker | @luis | 2026-10-21 |
| 3 | Alerta sobre latencia por etapa, no solo total | @carla | 2026-10-10 |

## Lo que salió bien
- Tracing distribuido permitió localizar la causa en 20 min.
- Rollback fue inmediato por versionado estricto.
```

## Errores comunes

- **Dashboards sin audiencia definida**: 60 paneles mezclando infra, modelo y negocio; nadie los lee.
- **Alertas sin runbook**: despertar a alguien a las 3 AM sin indicarle qué hacer.
- **Postmortems con culpables**: la gente aprende a esconder errores en lugar de reportarlos.
- **Acciones correctivas sin dueño ni fecha**: el postmortem se vuelve catarsis.
- **No practicar incidentes**: la primera vez que el equipo coordina es durante un fallo real.
- **MTTR sin medir**: imposible mejorar lo que no se mide.
- **No separar severidades**: tratar todo como P0 agota al equipo; tratar todo como P3 ignora lo importante.
- **Status page silenciosa**: los clientes se enteran por Twitter.
- **Dashboards estáticos** sin baseline ni comparación: imposible saber si "20 RPS" está bien o mal.
- **Confundir tener observabilidad con usarla**: comprar Datadog no reemplaza la cultura de usarlo.

## Resumen

- Una estrategia integral de monitoreo tiene **cinco niveles** (ejecutivo, negocio, modelo, servicio, infra), cada uno con dashboards y audiencias propias.
- Los **dashboards efectivos** responden una pregunta, muestran comparación con baseline y enlazan a runbooks y traces.
- La **respuesta a incidentes** sigue un protocolo: detectar, triaje, comunicar, **mitigar primero**, investigar después, resolver, postmortem.
- Los **runbooks** convierten conocimiento tribal en memoria del equipo; cada alerta debe tener uno.
- Los **postmortems blameless** separan el error de la persona y producen acciones correctivas concretas con dueño y fecha.
- Métricas de madurez (**MTTD, MTTR, alert precision, postmortem coverage**) permiten mejorar el proceso iterativamente.
- Herramientas (**Prometheus, Grafana, Sentry, Datadog, PagerDuty, Opsgenie**) habilitan la estrategia pero no la reemplazan; la cultura es el verdadero multiplicador.
- El objetivo final no es "nunca fallar" (imposible), sino **detectar rápido, mitigar rápido y aprender siempre**.
