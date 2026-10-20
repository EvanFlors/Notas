# Recursos — k8s-16

## Pod Security Standards & Admission

- Pod Security Standards (kubernetes.io): https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Pod Security Admission (built-in): https://kubernetes.io/docs/concepts/security/pod-security-admission/
- Migrar de PodSecurityPolicy a PSA: https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/
- AdmissionConfiguration + PodSecurityConfiguration (default por cluster): https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/

## securityContext, seccomp, AppArmor

- Configure a Security Context for a Pod/Container: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- Seccomp (RuntimeDefault, Localhost, Security Profiles Operator): https://kubernetes.io/docs/tutorials/security/seccomp/
- AppArmor nativo en securityContext (K8s 1.30+): https://kubernetes.io/docs/tutorials/security/apparmor/

## Runtimes aislados

- RuntimeClass: https://kubernetes.io/docs/concepts/containers/runtime-class/
- gVisor (`runsc`): https://gvisor.dev/docs/user_guide/quick_start/kubernetes/
- Kata Containers en K8s: https://github.com/kata-containers/kata-containers/blob/main/docs/install/README.md

## Supply chain: cosign, Kyverno, policy-controller

- cosign (Sigstore): https://docs.sigstore.dev/cosign/overview/
- Kyverno `verifyImages`: https://kyverno.io/docs/writing-policies/verify-images/
- Kyverno install (Helm): https://kyverno.io/docs/installation/methods/#install-kyverno-using-helm
- sigstore policy-controller: https://docs.sigstore.dev/policy-controller/overview/
- SLSA (niveles y specs): https://slsa.dev/spec/v1.0/
- Trivy (CLI): https://aquasecurity.github.io/trivy/latest/
- Trivy Operator (in-cluster scanning): https://aquasecurity.github.io/trivy-operator/latest/

## Runtime security

- Falco (docs): https://falco.org/docs/
- Falco rules language: https://falco.org/docs/concepts/rules/
- Falco Helm chart: https://github.com/falcosecurity/charts/tree/master/charts/falco
- falcosidekick (outputs): https://github.com/falcosecurity/falcosidekick

## CIS Benchmark y herramientas

- CIS Kubernetes Benchmark (acceso con registro): https://www.cisecurity.org/benchmark/kubernetes
- kube-bench (Aqua): https://github.com/aquasecurity/kube-bench
- kube-hunter (Aqua): https://github.com/aquasecurity/kube-hunter
- NSA/CISA Kubernetes Hardening Guide: https://www.cisa.gov/news-events/cybersecurity-advisories/aa22-213a

## Control plane: encryption, audit, RBAC

- Encrypting Secret data at rest (KMS v2): https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- Auditing: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- RBAC good practices: https://kubernetes.io/docs/concepts/security/rbac-good-practices/
- `rbac-tool` (insightsengineering): https://github.com/alcideio/rbac-tool
- `rbac-lookup`: https://github.com/FairwindsOps/rbac-lookup

## Lecturas complementarias

- Kubernetes Security Checklist (oficial): https://kubernetes.io/docs/concepts/security/security-checklist/
- `kubernetes/community` SIG-Security: https://github.com/kubernetes/community/tree/master/sig-security
- *Kubernetes Security and Observability* — Kashyap/Serradell (O'Reilly).
- Awesome-Kubernetes-Security: https://github.com/magnologan/awesome-k8s-security
