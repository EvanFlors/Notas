# REFERENCE — gcp-08-01-slo-and-alerting-policy-json

> Una referencia razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Archivos de referencia

- [`alerting-policy.json`](./alerting-policy.json) — fast burn alert sobre SLO 99.9%/30d.
- [`logs-based-metric.json`](./logs-based-metric.json) — counter `payment_declined_count` por `reason`/`app_version`.
- [`SLO-ADR.md`](./SLO-ADR.md) — ADR completo con 2 alternativas descartadas.
- [`README-INTENT.md`](./README-INTENT.md) — justificación operativa de cada pieza.

## Decisiones clave de esta solución

| Decisión | Qué elegimos | Por qué |
|----------|--------------|---------|
| SLI | request-based (good/total ratio) | Tráfico de `checkout` es alto y estable; request-based es estadísticamente sano. |
| Goal | 99.9% | Alineado con SLA interno con negocio. |
| Rolling period | 30 días | Alineado con reviews mensuales; evita "amnesia" de 7d. |
| Alert style | Burn rate 14.4× / 1h (fast) | Patrón canónico del SRE book; silencia ruido y detecta slow burn. |
| Métrica de negocio | log-based counter con labels acotados | Separa "SLO técnico" de "incidente de negocio" (declines no son 5xx). |
| Placeholders | `PROJECT_ID`, `SERVICE_ID`, etc. | El entregable es docs, no un despliegue real. |

## Qué comprueba el validador

El validador es **estructural**. No evalúa:

- Si tu threshold `14.4` es sensato (vs 10, vs 20).
- Si tu rolling period 30d es el correcto para tu negocio.
- Si tu filter de log-based metric es demasiado amplio en términos de volumen.

Para esas decisiones usa el ADR y compara con esta referencia.

## Errores comunes

1. **`notificationChannels` ausente o `[]`**. La policy sin canal es inútil (nadie se entera). El validador lo exige.
2. **`documentation.content` vacío o ausente**. Un runbook inline es parte del contrato de la alerta en este módulo.
3. **Filter de log-based metric sin `resource.type=...`**. Metric matchea demasiado y revienta la cuota.
4. **Project IDs reales en los JSON**. Usa siempre `PROJECT_ID`. El validador rechaza project paths no-placeholder.
5. **ADR sin "burn rate" ni "error budget"**. Es el centro conceptual del módulo; si no aparece, no hay razonamiento SRE.

## Cómo pasaría esto a Fase 4 (Terraform)

```hcl
# Walkthrough — NO es parte del entregable.
resource "google_monitoring_slo" "checkout_availability" {
  service      = google_monitoring_custom_service.checkout.service_id
  slo_id       = "checkout-availability-99-9"
  display_name = "checkout-api 99.9% availability (30d)"

  goal                = 0.999
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      good_service_filter  = "metric.type=\"run.googleapis.com/request_count\" metric.labels.response_code_class!=\"5xx\""
      total_service_filter = "metric.type=\"run.googleapis.com/request_count\""
    }
  }
}

resource "google_monitoring_alert_policy" "fast_burn" {
  display_name = "checkout-api fast burn"
  combiner     = "OR"
  # ...conditions, documentation, notification_channels...
}
```
