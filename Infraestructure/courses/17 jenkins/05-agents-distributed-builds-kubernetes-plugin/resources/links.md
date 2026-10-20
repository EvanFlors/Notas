# Recursos — jk-05

Referencias oficiales. **Verificar en Fase 4** del curso.

## Oficiales (Jenkins)

- **Distributed builds**: `https://www.jenkins.io/doc/book/using/using-agents/`
- **Kubernetes plugin**: `https://plugins.jenkins.io/kubernetes/`
- **Kubernetes plugin repo**: `https://github.com/jenkinsci/kubernetes-plugin`
- **Pipeline Kubernetes agent docs**: `https://github.com/jenkinsci/kubernetes-plugin/blob/master/docs/PIPELINE-SYNTAX.md`
- **Inbound agent image**: `https://hub.docker.com/r/jenkins/inbound-agent/`

## Kubernetes de apoyo

- **kind** (Kubernetes in Docker): `https://kind.sigs.k8s.io/`
- **helm chart `jenkins/jenkins`**: `https://github.com/jenkinsci/helm-charts/tree/main/charts/jenkins`
- **Pod Security Standards**: `https://kubernetes.io/docs/concepts/security/pod-security-standards/`

## GitHub Actions Runner Controller (comparación)

- **ARC docs**: `https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller`
- **ARC repo**: `https://github.com/actions/actions-runner-controller`

## Lecturas

- CloudBees — "Scaling Jenkins with Kubernetes" (buscar edición más reciente).
- "Jenkins Best Practices for Kubernetes" — blogs recurrentes de la fundación.

## Checklist de verificación requerida en Fase 4

- Versión actual del `kubernetes` plugin y breaking changes.
- Versión actual del LTS Jenkins compatible con el plugin.
- Estado de ARC (madurez, GA).
- Compatibilidad del plugin con PSS `restricted`.
