# Runbook — Deploy & Rollback

## Deploy

El deploy es GitOps vía Argo CD. Un merge a `main` produce una imagen nueva (CI), actualiza el `values.yaml` de la Helm release, y Argo CD sincroniza en 2–5 min.

## Diagnóstico de un deploy sospechoso

1. Dashboard Grafana: `checkout-service` → error_rate, p95 latency.
2. Argo CD: `argocd app get checkout-service` → ¿sync OK? ¿health OK?
3. Logs: `kubectl logs -l app=checkout-service -n checkout --tail=200 --since=15m`.

## Mitigación — Rollback

Si el deploy nuevo degrada el servicio:

```bash
# listar revisiones
argocd app history checkout-service
# volver a la anterior
argocd app rollback checkout-service <revision-id>
```

El rollback es prácticamente instantáneo; se completa en < 1 min.

## Escalación

- Oncall primario: team-platform-oncall (PagerDuty `checkout-service`).
- Si no responde en 15 min: team-platform lead.
- Si es incidente mayor (impacto > 10 % de usuarios): seguir el runbook de incident response de plataforma.
