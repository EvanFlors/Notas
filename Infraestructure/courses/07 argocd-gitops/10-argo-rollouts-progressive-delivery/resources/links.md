# Recursos — argo-10

## Documentación oficial

- Argo Rollouts — https://argo-rollouts.readthedocs.io/
- CRD `Rollout` reference — https://argo-rollouts.readthedocs.io/en/stable/features/specification/
- Blue/green strategy — https://argo-rollouts.readthedocs.io/en/stable/features/bluegreen/
- Canary strategy — https://argo-rollouts.readthedocs.io/en/stable/features/canary/
- Analysis + metrics providers — https://argo-rollouts.readthedocs.io/en/stable/features/analysis/
- Traffic management overview — https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/
- Argo CD + Rollouts integration (health check) — https://argo-rollouts.readthedocs.io/en/stable/features/argocd/
- Plugin `kubectl argo rollouts` — https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation
- Dashboard — https://argo-rollouts.readthedocs.io/en/stable/dashboard/

## Providers específicos

- Prometheus provider — https://argo-rollouts.readthedocs.io/en/stable/analysis/prometheus/
- Datadog provider — https://argo-rollouts.readthedocs.io/en/stable/analysis/datadog/
- CloudWatch provider — https://argo-rollouts.readthedocs.io/en/stable/analysis/cloudwatch/
- Kayenta provider — https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/

## Traffic management

- ingress-nginx canary annotations — https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#canary
- Istio VirtualService + Rollouts — https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/istio/
- Gateway API plugin — https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi
- SMI TrafficSplit — https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/smi/
- AWS ALB — https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/alb/

## Comparativas y lecturas

- Flagger vs Argo Rollouts — https://docs.flagger.app/
- "Progressive Delivery" (Weaveworks) — https://www.weave.works/blog/what-is-progressive-delivery
- Google SRE Workbook, cap. "Canarying Releases" — https://sre.google/workbook/canarying-releases/
- Prometheus `histogram_quantile` best practices — https://prometheus.io/docs/practices/histograms/

## Herramientas relacionadas

- Flagger (alternativa) — https://flagger.app/
- Service Mesh Interface (SMI) — https://smi-spec.io/
- Gateway API — https://gateway-api.sigs.k8s.io/
