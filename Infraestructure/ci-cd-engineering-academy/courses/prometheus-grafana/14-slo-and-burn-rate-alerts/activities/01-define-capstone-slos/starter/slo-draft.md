# SLO draft — payments

> Rellena cada bloque. Objetivo: un documento que cualquier ingeniero del equipo pueda leer en 5 min y entender el contrato.

## 1. Servicio
- Nombre: `payments`
- Owner: `payments-team`
- Criticidad: tier-1 / tier-2 / tier-3

## 2. SLI
- Familia: availability | latency | correctness | freshness
- Numerador ("good"): <!-- PromQL exacto -->
- Denominador ("total"): <!-- PromQL exacto -->
- Inclusiones/exclusiones (¿429 cuenta?, ¿health checks?):

## 3. SLO
- Objetivo: <!-- p.ej. 99.9% -->
- Ventana: <!-- rolling 30d -->
- Error budget (`1 - SLO`):

## 4. Política de budget
- 25 % budget restante → <!-- revisión semanal, priorizar reliability -->
- 10 % budget restante → <!-- freeze de features -->
- 0 % budget → <!-- rollback de release si aplica, postmortem obligatorio -->
- Autoriza excepciones: <!-- rol/persona -->

## 5. Observabilidad
- Dashboard asociado: <!-- URL/path -->
- Runbook: <!-- URL -->
- Canal de alerta: <!-- #slack-channel, pagerduty service -->
