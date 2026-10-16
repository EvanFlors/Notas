# Runbook — Incident: 5xx surge

## Síntomas

- `error_rate` del servicio > 2 % durante 5 min.
- Alerta Prometheus `ExampleService5xxSurge` dispara.

## Diagnóstico rápido

1. Mirar el dashboard del servicio en Grafana (link en `docs/index.md`).
2. Correlacionar con el último deploy (ver pestaña Argo CD del Component en Backstage).
3. Revisar logs: `kubectl logs -l app=example-service -n default --tail=200`.

## Mitigación

- Si el error empezó justo tras un deploy: **rollback** desde Argo CD (`argocd app rollback example-service <revision>`).
- Si no hay deploy reciente: escalar réplicas (`kubectl scale deploy/example-service --replicas=5`).

## Escalación

- Oncall primario: team-platform-oncall (PagerDuty service `example-service`).
- Si no responde en 15 min: team-platform lead.
