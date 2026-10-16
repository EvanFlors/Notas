# Escenario — Acme Foods Platform

**Org**: Acme Foods, cadena de supermercados; equipo de plataforma de 6 personas sirviendo a producto.

**Equipos consumidores**: 5 (checkout, catalog, pricing, loyalty, data-platform).
**Servicios totales**: 22 hoy, estimados 50 en 18 meses.
**Ambientes**: `dev`, `stg`, `prod`. Prod multi-región (eu-west-1 + eu-central-1).
**Clusters**:
- `dev` (1 cluster, shared tenancy).
- `stg` (1 cluster).
- `prod-eu-west` + `prod-eu-central` (dos clusters prod).

**Compliance**: PCI-DSS para pricing+checkout. Audit log de todo cambio a prod. Review mínima: 2 approvals SRE para prod, 1 approval team-lead para stg.

**Pipeline actual**: GitHub Actions construye imagen y la empuja a `ghcr.io/acme/*`. Hoy un humano hace `kubectl set image` — se quiere migrar a GitOps.

**Deploy frequency objetivo**:
- `dev`: ≥ 20 deploys/día agregado.
- `stg`: 5–10 deploys/día.
- `prod`: 1–3 deploys/día, nunca viernes 17h–lunes 8h.

**PR previews**: deseadas para `catalog`, `checkout`, `loyalty`. No para `data-platform` (datos sensibles, demasiado pesado).

**Observabilidad**: Prometheus + Grafana ya corren en los clusters (kube-prometheus-stack).

**Notificaciones**: Slack canal `#platform-alerts` para warnings; `#platform-oncall` para críticos; PagerDuty integrado a ambos.

**IDP**: evaluando Backstage; alternativa es cookiecutter + script. Decisión aún no tomada.

**Restricciones**:
- Un solo repo de infra (`acme/platform-manifests`). No se abre monorepo por equipo.
- Secretos ya en Vault (ESO ya configurado desde `argo-09`).
- `argocd-image-updater` autorizado para `dev` únicamente; stg/prod exigen PR humano.
- No se admite `targetRevision: HEAD` en prod.

**Objetivo del ADR**: escribir el contrato que operará esta plataforma los próximos 18 meses.
