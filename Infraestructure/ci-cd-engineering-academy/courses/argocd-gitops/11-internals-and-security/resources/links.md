# Recursos — argo-11

## Argo CD — arquitectura e internals

- Architectural Overview: https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/
- High Availability (HA) y sharding del application-controller: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/
- argocd-cm reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/argocd-cm.yaml/
- argocd-cmd-params-cm reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/argocd-cmd-params-cm.yaml/
- argocd-secret reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/argocd-secret.yaml/
- Server configuration (TLS, --insecure): https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-server/

## Autenticación y SSO

- User Management overview: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
- OIDC con Dex: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#dex
- OIDC directo (sin Dex): https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#existing-oidc-provider
- Dex GitHub connector: https://dexidp.io/docs/connectors/github/
- Project JWT tokens: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/#project-roles

## RBAC

- Argo CD RBAC spec: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- Casbin (library used underneath): https://casbin.org/docs/syntax-for-models
- `argocd account can-i`: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_account_can-i/

## Hardening & security

- Security best practices: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/
- Security considerations: https://argo-cd.readthedocs.io/en/stable/operator-manual/security_considerations/
- Kubernetes Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Pod Security Admission: https://kubernetes.io/docs/concepts/security/pod-security-admission/
- NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policies/

## CVEs y advisories

- Argo CD GitHub Security Advisories: https://github.com/argoproj/argo-cd/security/advisories
- CVE-2022-24348 (path traversal in Helm/Kustomize): https://github.com/argoproj/argo-cd/security/advisories/GHSA-63qx-x74g-jcr7
- CVE-2022-29165 (auth bypass): https://github.com/argoproj/argo-cd/security/advisories/GHSA-h4w9-6x78-8vrj
- CVE-2024-21661 (DoS via large request): https://github.com/argoproj/argo-cd/security/advisories/GHSA-h744-qvjj-7f3h

## Backup / Restore

- `argocd admin export` / `import`: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/
- Velero docs: https://velero.io/docs/latest/
- Velero AWS provider plugin: https://github.com/vmware-tanzu/velero-plugin-for-aws
- MinIO quickstart: https://min.io/docs/minio/kubernetes/upstream/

## Notifications & observability (puente a argo-12)

- argocd-notifications: https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/
- Metrics reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/
