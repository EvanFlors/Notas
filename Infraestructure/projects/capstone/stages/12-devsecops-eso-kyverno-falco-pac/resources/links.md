# Recursos — Capstone etapa 12 (DevSecOps completo)

## External Secrets Operator

- **ESO — documentación oficial** — <https://external-secrets.io/>
- **ESO — ClusterSecretStore** — <https://external-secrets.io/latest/api/clustersecretstore/>
- **ESO — ExternalSecret** — <https://external-secrets.io/latest/api/externalsecret/>
- **ESO — Vault provider** — <https://external-secrets.io/latest/provider/hashicorp-vault/>
- **ESO — AWS Secrets Manager provider** — <https://external-secrets.io/latest/provider/aws-secrets-manager/>
- **Vault — Kubernetes auth** — <https://developer.hashicorp.com/vault/docs/auth/kubernetes>

## Kyverno

- **Kyverno — documentación** — <https://kyverno.io/docs/>
- **Kyverno — verifyImages** — <https://kyverno.io/docs/writing-policies/verify-images/>
- **Kyverno — Pod Security policies** — <https://kyverno.io/policies/pod-security/>
- **Kyverno — `kyverno test` CLI** — <https://kyverno.io/docs/kyverno-cli/usage/test/>
- **Sigstore cosign (keyless)** — <https://docs.sigstore.dev/cosign/signing/overview/>

## Falco

- **Falco — documentación** — <https://falco.org/docs/>
- **Falco — rules syntax** — <https://falco.org/docs/rules/>
- **Falco — modern eBPF driver** — <https://falco.org/docs/setup/driver/modern-ebpf/>
- **falcosecurity/charts — Helm chart** — <https://github.com/falcosecurity/charts/tree/master/charts/falco>

## OPA / Conftest

- **OPA — Rego language** — <https://www.openpolicyagent.org/docs/latest/policy-language/>
- **OPA — `opa test`** — <https://www.openpolicyagent.org/docs/latest/policy-testing/>
- **Conftest — docs** — <https://www.conftest.dev/>
- **Conftest — Kubernetes example** — <https://www.conftest.dev/examples/>

## Admission control / Pod Security

- **Kubernetes — Pod Security Standards** — <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
- **Kubernetes — admission controllers overview** — <https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/>
- **CNCF whitepaper — Cloud Native Security** — <https://github.com/cncf/tag-security/blob/main/security-whitepaper/v2/cloud-native-security-whitepaper.md>

## Patrones y ADRs del propio programa

- Curso `devsecops/13-secrets-at-scale-vault-eso-and-workload-identity` — origen del patrón ESO + Vault.
- Curso `devsecops/12-runtime-security-falco-and-tetragon` — base de la regla Falco de este stage.
- Curso `terraform/12-testing-and-policy-as-code` — Rego/conftest aplicado a `terraform plan`.
- Curso `kubernetes/16-security-hardening-and-supply-chain` — cosign + verifyImages.
