# Recursos — sec-11

> Verificar en Fase 4 del curso para asegurar vigencia (versiones y UX cambian).

## Kyverno

- Sitio: `https://kyverno.io/`
- Docs: `https://kyverno.io/docs/`
- Install: `https://kyverno.io/docs/installation/`
- Policy types (`validate` / `mutate` / `generate` / `verifyImages`): `https://kyverno.io/docs/policy-types/`
- `verifyImages`: `https://kyverno.io/docs/writing-policies/verify-images/`
- CLI (`kyverno apply`, `kyverno test`): `https://kyverno.io/docs/kyverno-cli/`
- PolicyExceptions: `https://kyverno.io/docs/exceptions/`
- Policy library (recetas comunes): `https://kyverno.io/policies/`

## OPA / Gatekeeper

- Gatekeeper: `https://open-policy-agent.github.io/gatekeeper/`
- `ConstraintTemplate` vs `Constraint`: `https://open-policy-agent.github.io/gatekeeper/website/docs/constrainttemplates`
- Library: `https://github.com/open-policy-agent/gatekeeper-library`

## sigstore policy-controller

- Repo: `https://github.com/sigstore/policy-controller`
- `ClusterImagePolicy`: `https://docs.sigstore.dev/policy-controller/overview/`

## ValidatingAdmissionPolicy (nativo K8s)

- Docs oficiales: `https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/`
- CEL spec en K8s: `https://kubernetes.io/docs/reference/using-api/cel/`

## Admission control en general

- Kubernetes admission controllers reference: `https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/`
- Pod Security Standards (PSA): `https://kubernetes.io/docs/concepts/security/pod-security-standards/`

## Herramientas de apoyo

- **kind** (K8s local): `https://kind.sigs.k8s.io/`
- **kubectl**: `https://kubernetes.io/docs/reference/kubectl/`
- **cosign** (visto en `sec-09`): `https://docs.sigstore.dev/cosign/overview/`

## Lecturas recomendadas

- "Policy as Code in Kubernetes" — blogs de Nirmata / Styra comparando Kyverno vs Gatekeeper.
- CNCF whitepaper on supply chain security (sección admission).
- Changelogs recientes de Kyverno (features `verifyImages` evolucionan rápido).
