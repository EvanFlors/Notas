# Recursos — k8s-05

## Documentación oficial

- **ConfigMap** — <https://kubernetes.io/docs/concepts/configuration/configmap/>
- **Secret** — <https://kubernetes.io/docs/concepts/configuration/secret/>
- **Managing Secrets using kubectl** — <https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/>
- **Managing Secrets using Config File** — <https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-config-file/>
- **Projected volumes** — <https://kubernetes.io/docs/concepts/storage/projected-volumes/>
- **Downward API** — <https://kubernetes.io/docs/concepts/workloads/pods/downward-api/>
- **Volume types** — <https://kubernetes.io/docs/concepts/storage/volumes/>
- **`hostPath` warning** — <https://kubernetes.io/docs/concepts/storage/volumes/#hostpath>

## Encryption at rest

- **Encrypting Confidential Data at Rest** — <https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/>
- **KMS v2 (apiserver + external KMS)** — <https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/>
- **EKS envelope encryption** — <https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html>
- **GKE Application-Layer Secrets Encryption** — <https://cloud.google.com/kubernetes-engine/docs/how-to/encrypting-secrets>
- **AKS KMS etcd encryption** — <https://learn.microsoft.com/azure/aks/use-kms-etcd-encryption>

## Secret managers externos

- **External Secrets Operator (ESO)** — <https://external-secrets.io/>
- **Secrets Store CSI Driver** — <https://secrets-store-csi-driver.sigs.k8s.io/>
- **Vault Agent Injector (HashiCorp)** — <https://developer.hashicorp.com/vault/docs/platform/k8s/injector>
- **AWS Secrets and Configuration Provider (ASCP)** — <https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html>
- **GCP Secret Manager CSI provider** — <https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp>

## Lecturas complementarias

- **"Kubernetes Secrets are not encrypted — but can be"** — buscar; hay varias versiones de la comunidad (CNCF blog, DigitalOcean blog).
- **CNCF TAG-Security — Secrets management whitepaper** — <https://github.com/cncf/tag-security>
- **12-factor App — Config** — <https://12factor.net/config>
- **OWASP Kubernetes Top 10 — K05 Inadequate Secrets Management** — <https://owasp.org/www-project-kubernetes-top-ten/>

## Herramientas útiles

- **`kubeseal` / Sealed Secrets (Bitnami)** — <https://github.com/bitnami-labs/sealed-secrets> (alternativa a ESO: cifra Secrets *en el repo* con una llave del cluster).
- **`sops`** — <https://github.com/getsops/sops> (encripta YAML/JSON para GitOps; combina con `helm-secrets` y `kustomize`).
- **`kubectl neat`** — <https://github.com/itaysk/kubectl-neat> (limpia campos autogenerados al imprimir manifiestos; útil al diffear Secrets).
- **`stern`** — <https://github.com/stern/stern> (multi-pod logs, para auditar leaks por `env` en tiempo real).
