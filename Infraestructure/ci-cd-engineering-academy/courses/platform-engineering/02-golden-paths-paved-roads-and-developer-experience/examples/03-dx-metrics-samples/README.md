# Example 03 — Métricas DX: muestras, fórmulas y antipatterns

> Ejemplo de **lectura y análisis**. Catálogo de métricas DX con fórmulas y modos de fallo.

## Convenciones

- Numerador / denominador explícitos.
- Horizonte temporal (ventana) explícito.
- Para cada métrica, al menos un *failure mode*.

---

## 1. Time-to-first-commit (TTFC)

- **Fórmula:** mediana de `(ts(primer commit productivo) - ts(creación del repo vía scaffolder))`, en minutos.
- **Ventana:** últimos 30 días, agrupado por path.
- **Objetivo típico:** p50 < 10 min.
- **Qué "productivo" significa:** commit del developer, excluir los commits automáticos del scaffolder.
- **Failure mode:** el scaffolder deja un commit `feat: initial` que algunos cuentan como "primer commit" → métrica cae a 0 sin que la DX cambie.

## 2. Time-to-production (TTP)

- **Fórmula:** mediana de `(ts(primer deploy a prod) - ts(creación del repo))`, en horas.
- **Ventana:** últimos 90 días.
- **Objetivo típico:** p50 < 24 h para el path "nuevo microservicio".
- **Failure mode:** deploys de "hola mundo" cuentan igual que servicios reales. Ajustar excluyendo repos marcados `demo:true` o con tráfico cero N días.

## 3. Tasa de errores de scaffolding

- **Fórmula:** `# ejecuciones del scaffolder que fallaron / # ejecuciones totales`.
- **Ventana:** últimos 30 días.
- **Objetivo típico:** < 5 %.
- **Failure mode:** errores silenciados (p. ej. `|| true` en una step) hacen que la métrica caiga pero el usuario sigue sin su repo. Añadir métrica de "repos esperados vs repos entregados".

## 4. Platform NPS (específico del path)

- **Fórmula:** `(% promotores (9–10) - % detractores (0–6))`.
- **Pregunta base:** "¿Qué tan probable es que recomiendes el path *X* a otro equipo para un caso similar?"
- **Ventana:** survey trimestral o semestral.
- **Objetivo típico:** ≥ 30 (positivo), ≥ 50 (bueno).
- **Failure mode:** autoselección (contestan solo los contentos). Mitigar con muestreo estratificado y recordatorio.

## 5. Tickets evitados (estimación)

- **Fórmula:** `# tickets abiertos para la tarea X antes del path - # tickets abiertos después`.
- **Ventana:** 90 días antes / 90 días después del release del path.
- **Objetivo típico:** reducción ≥ 50 %.
- **Failure mode:** otros factores (hiring, reorganización, deuda nueva) contaminan la comparación. Reportar siempre con contexto cualitativo.

## 6. Adopción espontánea

- **Fórmula:** `# servicios nuevos (últimos 90 días) creados vía el path / # servicios nuevos totales`.
- **Ventana:** últimos 90 días.
- **Objetivo típico:** > 50 % trimestre 1, > 70 % trimestre 2.
- **Failure mode:** inflar numerador con repos de prueba. Excluir repos con tag `experiment` o sin tráfico después de N días.

---

## Constelación recomendada para un primer path

Elige **3–5** métricas, nunca **1**:

```
TTP (p50)         ← flujo
Adopción          ← tracción
Error rate        ← calidad
Platform NPS      ← percepción
DX interviews     ← contexto
```

Si todas tus métricas apuntan al mismo lado (p. ej. todas de "velocidad"), estás ciego a trade-offs.

## Goodhart aplicado

> *"Cuando una métrica se vuelve objetivo, deja de ser una buena métrica."*

Reglas de higiene:

- Nunca ates **bonos/compensación** a métricas DX directamente.
- Reporta métricas **en pares** (velocidad + calidad, adopción + NPS).
- Rota la métrica "estrella" cada 2–3 trimestres.
- Si una métrica mejora sin que las entrevistas lo confirmen, sospecha de gaming.
