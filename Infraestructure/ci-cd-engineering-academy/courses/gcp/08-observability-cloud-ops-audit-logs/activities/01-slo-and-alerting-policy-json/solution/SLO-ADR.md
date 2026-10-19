# ADR 001 — SLO de disponibilidad para checkout-api en Cloud Run

## Estado

Propuesto (Fase 3). Materializar con Terraform en Fase 4 (`google_monitoring_slo` + `google_monitoring_alert_policy`).

## Contexto

`checkout-api` es la ruta crítica de pago en Cloud Run. SLA interno acordado con el negocio: **99.9% de disponibilidad en 30 días rolling**. Hasta hoy el equipo alerta "por métrica cruda" (5xx > 1% durante 5 min), lo que produce ruido en incidentes transitorios y silencia alertas en degradaciones lentas. Queremos:

- Definir el SLI operativamente.
- Fijar un SLO declarativo en Cloud Monitoring.
- Alertar por **burn rate**, no por threshold cruda.
- Capturar métrica adicional de negocio (`payment_declined` por `reason`) para análisis separado del SLO técnico.

## Decisión

### 1. SLI

Request-based ratio sobre Cloud Run:

```
good  = request_count{response_code_class != "5xx"}
total = request_count
SLI   = good / total
```

(Nos saltamos 4xx del "mal" porque son errores del cliente, no del servicio.)

### 2. SLO

- **Goal**: `0.999` (99.9%).
- **Rolling period**: `30 días` (2592000 segundos). Alineado con el acuerdo de negocio.
- **Service**: Cloud Run `checkout-api` detectado automáticamente por Cloud Monitoring.
- Error budget resultante: 0.1% del tiempo ≈ **43m 12s de "unavailable" al mes**.

### 3. Burn rate alerts

- **Fast burn (P1)**: 14.4× la tasa objetivo durante 1h → consume 2% del budget en 1h. Notifica PagerDuty + Slack SRE. Policy en `alerting-policy.json`.
- **Slow burn (P2, extensión opcional)**: 6× durante 6h → consume 10% en 3 días. Notifica solo Slack SRE.

### 4. Logs-based metric complementaria

`payment_declined_count` (counter), label por `reason` y `app_version`. Alimenta un dashboard de negocio, **no** alertas. Se separa del SLO técnico: un bump en `payment_declined` por un release puede no romper el SLO (son 2xx desde el POV HTTP) pero sí ser incidente de negocio.

### 5. Documentación obligatoria en la policy

Cada alerta carga `documentation.content` con runbook, dashboard URL (placeholder), owner y 3-4 pasos de triage. Sin esto, la alerta se rechaza en code review.

### 6. Placeholders

Todo JSON usa `PROJECT_ID`, `SERVICE_ID`, `SLO_ID`, `CHANNEL_ID_*`. En Fase 4, Terraform resuelve los literales.

## Consecuencias

### Positivas

- Alertas alineadas con experiencia del usuario (burn rate), no con picos aislados de métrica.
- SLO visible en consola Monitoring como objeto de primera clase; auditable.
- Reducción esperada de alertas P1 (menos ruido en el oncall).
- Métrica de negocio separada → el equipo product puede dashboardear sin tocar la observabilidad SRE.

### Negativas

- Educación: el equipo debe entender burn rate antes de interpretar las alertas (no "±5xx igual a mal").
- Si el tráfico de `checkout-api` es muy bajo, el SLI request-based pierde señal estadística; en ese caso se migraría a windows-based.
- Mantener `documentation.content` actualizada requiere disciplina (linting en PR revisará enlaces rotos — ver pregunta 4 del README).

## Alternativas descartadas

### Alternativa A: alertar por threshold de 5xx sin SLO

Alerta "5xx rate > 1% durante 5 min" directo sobre `run.googleapis.com/request_count`. Rechazada porque:

- Ruidosa en picos transitorios (ok cuando se auto-recupera, dispara igual).
- Silencia degradaciones lentas (0.5% sostenido 10 días no dispara nunca y aun así quema budget).
- No da vista agregada de "cuánto budget nos queda".

### Alternativa B: SLO con rolling period 7 días

Más reactivo (resetea más rápido tras incidente), pero:

- Desalineado con el acuerdo de negocio (30 días).
- Un incidente grande "desaparece" del cálculo demasiado rápido y pierde visibilidad en reviews mensuales.

### Alternativa C: windows-based SLI en vez de request-based

Útil cuando el tráfico es muy desigual, pero `checkout-api` tiene volumen suficiente para que request-based sea estadísticamente estable. Se re-evalúa si el tráfico baja >10× en una ventana.
