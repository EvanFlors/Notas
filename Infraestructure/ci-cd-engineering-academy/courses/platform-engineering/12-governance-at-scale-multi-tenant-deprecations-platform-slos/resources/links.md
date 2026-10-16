# Recursos — plat-12

Referencias oficiales y lecturas de apoyo para gobernanza, multi-tenancy, SLOs e inner-source. **Verificar vigencia** periódicamente (los enlaces y versiones evolucionan).

## Multi-tenancy

### Kubernetes

- **Multi-tenancy overview (K8s docs)**: `https://kubernetes.io/docs/concepts/security/multi-tenancy/`
- **Namespaces**: `https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/`
- **ResourceQuota**: `https://kubernetes.io/docs/concepts/policy/resource-quotas/`
- **NetworkPolicy**: `https://kubernetes.io/docs/concepts/services-networking/network-policies/`
- **Hierarchical Namespaces (HNC)**: `https://github.com/kubernetes-sigs/hierarchical-namespaces`
- **vcluster**: `https://www.vcluster.com/`
- **Capsule**: `https://capsule.clastix.io/`

### Cloud (AWS / GCP / Azure)

- **AWS Organizations + SCPs**: `https://docs.aws.amazon.com/organizations/`
- **AWS Multi-account strategy (Well-Architected)**: `https://docs.aws.amazon.com/wellarchitected/latest/management-and-governance-guide/`
- **GCP Resource hierarchy (Organizations / Folders / Projects)**: `https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy`
- **GCP Organization Policy**: `https://cloud.google.com/resource-manager/docs/organization-policy/overview`
- **Azure Management Groups**: `https://learn.microsoft.com/en-us/azure/governance/management-groups/`
- **Azure Policy**: `https://learn.microsoft.com/en-us/azure/governance/policy/`

### Argo CD

- **AppProject reference**: `https://argo-cd.readthedocs.io/en/stable/user-guide/projects/`
- **RBAC in Argo CD**: `https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/`

### Backstage permissions

- **Permission framework**: `https://backstage.io/docs/permissions/overview`
- **Writing permission policies**: `https://backstage.io/docs/permissions/writing-a-policy`

## SLOs y error budgets

- **Google SRE Workbook — Implementing SLOs (cap. 2)**: `https://sre.google/workbook/implementing-slos/`
- **Google SRE Book — Service Level Objectives**: `https://sre.google/sre-book/service-level-objectives/`
- **Burn rate alerting**: `https://sre.google/workbook/alerting-on-slos/`
- **slo.dev — Sloth** (generador de SLOs para Prometheus): `https://sloth.dev/`
- **OpenSLO (spec abierta de SLOs)**: `https://openslo.com/`
- **Nobl9 / Pyrra** (herramientas SLO populares): `https://pyrra.dev/`

## Deprecation policies — casos de estudio

- **GitHub API deprecation policy**: `https://docs.github.com/en/rest/overview/api-versions`
- **Kubernetes API deprecation policy**: `https://kubernetes.io/docs/reference/using-api/deprecation-policy/`
- **Google Cloud deprecation policy**: `https://cloud.google.com/terms/deprecation`
- **AWS deprecation policy (ejemplos por servicio)**: `https://aws.amazon.com/blogs/aws/category/aws-service-deprecation/`
- **Python PEP 387 — Backwards Compatibility Policy**: `https://peps.python.org/pep-0387/`
- **Semantic Versioning (SemVer)**: `https://semver.org/`
- **Keep a Changelog**: `https://keepachangelog.com/`
- **RFC 7231 Sunset header + Deprecation header (draft)**: `https://datatracker.ietf.org/doc/draft-ietf-httpapi-deprecation-header/`

## Inner-source

- **InnerSource Commons**: `https://innersourcecommons.org/`
- **InnerSource patterns**: `https://patterns.innersourcecommons.org/`
- **Trusted Committer pattern**: `https://patterns.innersourcecommons.org/p/trusted-committer`
- **InnerSource learning path**: `https://innersourcecommons.org/learn/`
- **The InnerSource Approach to Innovation and Software Development** (O'Reilly, free): `https://www.oreilly.com/library/view/getting-started-with/9781492041993/`

## Platform-as-product y team topologies

- **Team Topologies (libro + web)**: `https://teamtopologies.com/`
- **Platform-as-product (Thoughtworks, Martin Fowler)**: `https://martinfowler.com/articles/platform-prerequisites.html`
- **CNCF Platforms White Paper**: `https://tag-app-delivery.cncf.io/whitepapers/platforms/`
- **Platform Engineering Maturity Model (CNCF TAG App Delivery)**: `https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/`
- **Internal Developer Platform (sitio comunitario)**: `https://internaldeveloperplatform.org/`

## Comunicación y developer experience

- **DX Core 4 (metricas de developer experience)**: `https://dx.com/research`
- **SPACE framework (ACM Queue)**: `https://queue.acm.org/detail.cfm?id=3454124`
- **DevEx: What Actually Drives Productivity (ACM Queue, 2023)**: `https://queue.acm.org/detail.cfm?id=3595878`

## Deprecaciones y migraciones — ejemplos narrados

- **Shopify's approach to deprecations** (buscar blog posts recientes).
- **Stripe API versioning** (clásico de versionado explícito por fecha): `https://stripe.com/blog/api-versioning`
- **How we deprecate at Monzo / Cloudflare / Netflix** — blogs engineering de referencia.

## Específicos de los módulos previos (contexto)

- `plat-01` — Team Topologies y carga cognitiva.
- `plat-02` — Golden paths / paved roads.
- `plat-09` — Self-service infra con Crossplane (ver XRDs).
- `plat-10` — Scorecards de madurez.
- `plat-11` — DORA, SPACE, platform-as-product.

## Checklist de verificación

Al adoptar este módulo en una organización real, confirma:

- La **política de deprecations** elegida tiene TTLs defendibles para el ritmo de la organización.
- Los **SLOs** se pueden instrumentar con las herramientas de observabilidad existentes.
- El **modelo multi-tenant** se mapea limpio a los 4 planos (K8s, cloud, Argo CD, Backstage).
- La **guía inner-source** se publica en `CONTRIBUTING.md` del repo de plataforma antes de pedir contribuciones.
- El **dashboard "Platform Status"** está público interno antes de anunciar SLOs.
