# Recursos — plat-09

Referencias oficiales y lecturas de apoyo. **Verificar vigencia en Fase 4** (los enlaces y versiones cambian).

## Crossplane

- Sitio oficial: `https://www.crossplane.io/`
- Documentación: `https://docs.crossplane.io/`
- Composite Resources (CompositeResourceDefinitions, Compositions, Claims): `https://docs.crossplane.io/latest/concepts/composite-resources/`
- Providers (catálogo): `https://marketplace.upbound.io/providers`
- Composition Functions: `https://docs.crossplane.io/latest/concepts/composition-functions/`
- Crossplane v2 (si disponible): revisar changelog oficial para cambios en claims/composite.
- `crossplane-contrib/provider-kubernetes`: `https://github.com/crossplane-contrib/provider-kubernetes`

## Alternativas K8s-native

- AWS Controllers for Kubernetes (ACK): `https://aws-controllers-k8s.github.io/community/`
- GCP Config Connector: `https://cloud.google.com/config-connector/docs/overview`
- Azure Service Operator (ASO): `https://azure.github.io/azure-service-operator/`

## Alternativas Terraform-via-PR

- Atlantis: `https://www.runatlantis.io/`
- Terraform Cloud / Enterprise: `https://developer.hashicorp.com/terraform/cloud-docs`
- Env0: `https://www.env0.com/`
- Spacelift: `https://spacelift.io/`
- OpenTofu + GHA: `https://opentofu.org/`

## Backstage Scaffolder (ya tocado en plat-06)

- Scaffolder overview: `https://backstage.io/docs/features/software-templates/`
- Built-in actions (`fetch:template`, `publish:github`, `catalog:register`): `https://backstage.io/docs/features/software-templates/builtin-actions`
- Writing a custom action: `https://backstage.io/docs/features/software-templates/writing-custom-actions`

## GitOps

- Argo CD: `https://argo-cd.readthedocs.io/`
- Flux: `https://fluxcd.io/`

## Policy as code sobre K8s claims

- Kyverno: `https://kyverno.io/`
- OPA Gatekeeper: `https://open-policy-agent.github.io/gatekeeper/`

## Herramientas usadas en las actividades

- `kind` (Kubernetes IN Docker): `https://kind.sigs.k8s.io/`
- `kubectl`: `https://kubernetes.io/docs/reference/kubectl/`
- `helm`: `https://helm.sh/`

## Lecturas recomendadas

- CNOE (Cloud Native Operational Excellence) reference stack: `https://cnoe.io/`
- "Infrastructure From Code" vs "Infrastructure as Code" (artículos varios): buscar en blogs de Humanitec y Palo Alto Networks.
- Case study Deutsche Telekom con Crossplane: buscar "Deutsche Telekom crossplane" en el blog de Upbound/CNCF.
- "Platform as a Product" (Thoughtworks, Team Topologies).
