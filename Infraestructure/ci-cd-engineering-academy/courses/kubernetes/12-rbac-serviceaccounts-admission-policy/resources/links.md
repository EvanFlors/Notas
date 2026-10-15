# Recursos — k8s-12 RBAC, admission y policy-as-code

## Documentación oficial Kubernetes

- Authentication: https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- Authorization overview: https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- Using RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- ServiceAccounts: https://kubernetes.io/docs/concepts/security/service-accounts/
- Bound ServiceAccount Tokens: https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#bound-service-account-tokens
- Admission Controllers Reference: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- Dynamic Admission Control: https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
- Validating Admission Policy (CEL): https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- Pod Security Admission: https://kubernetes.io/docs/concepts/security/pod-security-admission/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- CEL language spec: https://github.com/google/cel-spec

## Kyverno

- Documentación: https://kyverno.io/docs/
- Installation: https://kyverno.io/docs/installation/
- Verify Images: https://kyverno.io/docs/writing-policies/verify-images/
- Policy library: https://kyverno.io/policies/

## OPA/Gatekeeper

- Gatekeeper docs: https://open-policy-agent.github.io/gatekeeper/website/docs/
- Rego Playground: https://play.openpolicyagent.org/
- Policy library: https://open-policy-agent.github.io/gatekeeper-library/

## Sigstore / cosign

- cosign: https://docs.sigstore.dev/cosign/overview/
- Keyless signing: https://docs.sigstore.dev/cosign/signing/overview/
- Rekor (transparency log): https://docs.sigstore.dev/rekor/overview/

## Lecturas de referencia

- NSA/CISA Kubernetes Hardening Guide: https://www.cisa.gov/news-events/cybersecurity-advisories/aa22-181a
- CIS Kubernetes Benchmark: https://www.cisecurity.org/benchmark/kubernetes
- "Kubernetes Security" (Liz Rice & Michael Hausenblas), O'Reilly.
- KEP-3488: ValidatingAdmissionPolicy — https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/3488-cel-admission-control
