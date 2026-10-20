# Recursos — argo-06

## Documentación oficial de Argo CD

- **Projects** — https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- **RBAC configuration** — https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- **Built-in roles y policies CSV** — https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/#basic-built-in-roles
- **SSO con OIDC (directo o vía Dex)** — https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
- **ApplicationSet y herencia de project** — https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/ (referencia para `argo-07`)
- **`argocd proj` CLI** — https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_proj/
- **Project roles y tokens** — https://argo-cd.readthedocs.io/en/stable/user-guide/projects/#project-roles

## Casbin (motor de policies)

- **Casbin — editor interactivo** — https://casbin.org/editor/
- **Casbin — modelos y matcher** — https://casbin.org/docs/syntax-for-models

## OIDC / SSO

- **Dex connectors** (GitHub, LDAP, OIDC pass-through…) — https://dexidp.io/docs/connectors/
- **OpenID Connect — spec corta** — https://openid.net/specs/openid-connect-core-1_0.html

## Multi-tenancy en Kubernetes (contexto)

- **Kubernetes multi-tenancy — SIG** — https://github.com/kubernetes-sigs/multi-tenancy
- **Namespaces no son barrera de seguridad por sí solos** — https://kubernetes.io/docs/concepts/security/multi-tenancy/

## Lectura recomendada

- Blog "Argo CD RBAC Deep Dive" (Codefresh) — https://codefresh.io/blog/argo-cd-rbac/
- Charla KubeCon "Scaling GitOps with Argo CD" (ver sección "Projects for Tenancy") — buscar en https://www.youtube.com/@cncf
- CNCF white paper **Multi-Tenancy in Kubernetes** — https://github.com/cncf/tag-security/tree/main/community/working-groups/multi-tenancy

## Herramientas útiles para auditoría

- **`argocd admin`** (comandos de administración) — https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd_admin/
- **`argocd admin settings rbac can`** — simula una decisión de policy sin reconfigurar nada.
- **`kubeaudit`** — https://github.com/Shopify/kubeaudit (para el lado K8s RBAC).
- **`polaris`** — https://github.com/FairwindsOps/polaris (auditoría de workloads).

## Nota de versiones

Todo lo descrito aplica a **Argo CD ≥ 2.9**. Antes de 2.7 el formato de policies CSV y la emisión de tokens eran similares pero algunos flags cambiaron (`--expires-in` existe desde 1.5). Verifica con `argocd version`.
