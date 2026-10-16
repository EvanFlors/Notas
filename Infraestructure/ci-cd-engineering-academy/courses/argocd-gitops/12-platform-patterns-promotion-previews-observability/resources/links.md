# Recursos — argo-12 Platform patterns

## Oficiales (Argo CD)

- Argo CD docs — https://argo-cd.readthedocs.io/
- ApplicationSet CRD — https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
  - **Git generator** — `https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/`
  - **Pull Request generator** — `https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/`
  - **Progressive syncs** — `https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/`
- Notifications controller — https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/
- Métricas Prometheus (operator manual) — https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/
- Sync windows — https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/
- Resource hooks y waves — https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/

## argocd-image-updater

- Repo oficial (argoproj-labs) — https://github.com/argoproj-labs/argocd-image-updater
- Docs — https://argocd-image-updater.readthedocs.io/
- Write-back methods — https://argocd-image-updater.readthedocs.io/en/stable/basics/update-methods/
- Update strategies — https://argocd-image-updater.readthedocs.io/en/stable/basics/update-strategies/

## Observabilidad

- Dashboards Grafana comunidad
  - 14584 "ArgoCD" — https://grafana.com/grafana/dashboards/14584
  - 19993 "Argo CD Operational" — https://grafana.com/grafana/dashboards/19993
- Alertas de referencia (awesome-prometheus-alerts) — https://samber.github.io/awesome-prometheus-alerts/rules#argo-cd

## OpenGitOps y plataforma

- OpenGitOps principles — https://opengitops.dev
- CNCF GitOps Working Group — https://github.com/open-gitops/documents

## IDP / Backstage

- Backstage docs — https://backstage.io/docs/
- Backstage Argo CD plugin — https://backstage.io/docs/features/software-catalog/well-known-annotations#argocdprojectslugs
- "Software Templates" (scaffolder) — https://backstage.io/docs/features/software-templates/

## Lecturas recomendadas

- Codefresh blog — https://codefresh.io/blog/ (secciones de ApplicationSets, Image Updater)
- Akuity blog — https://akuity.io/blog
- "GitOps Patterns" (ejemplos reales de folder/branch promotion) — https://github.com/argoproj/argocd-example-apps

## Comparaciones y alternativas

- Flux `image-automation-controller` (equivalente nativo) — https://fluxcd.io/flux/components/image/
- CNCF landscape (categoría continuous-delivery) — https://landscape.cncf.io/card-mode?category=continuous-integration-delivery

## Checklist de verificación en Fase 4

- Versión actual estable de Argo CD y ApplicationSet (progressive sync GA state).
- Estado `argocd-image-updater` (sigue en argoproj-labs, no core).
- Compatibilidad `notifications-controller` + templates (breaking changes recientes).
- Grafana dashboard IDs vigentes.
- Backstage Argo CD plugin compatible con versión instalada.
