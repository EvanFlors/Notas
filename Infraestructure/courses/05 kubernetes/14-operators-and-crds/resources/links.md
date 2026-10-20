# Recursos — Operadores y CRDs

> Verificar vigencia antes de citar. Priorizar siempre docs oficiales.

## CRDs y extensibilidad del API

- Kubernetes docs — Custom Resources: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
- Kubernetes docs — CRD versions & conversion: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/
- Kubernetes docs — API aggregation layer: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/

## Operator pattern

- Kubernetes docs — Operator pattern: https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
- CoreOS blog original (histórico): "Introducing Operators" (2016).
- Awesome Operators (listado comunitario): https://github.com/operator-framework/awesome-operators

## Frameworks

- Kubebuilder book: https://book.kubebuilder.io/
- controller-runtime: https://pkg.go.dev/sigs.k8s.io/controller-runtime
- Operator SDK docs: https://sdk.operatorframework.io/docs/
- Metacontroller: https://metacontroller.github.io/metacontroller/
- Kopf (Python, alternativa no-Go): https://kopf.readthedocs.io/

## Testing

- envtest (controller-runtime): https://book.kubebuilder.io/reference/envtest.html
- Ginkgo + Gomega: https://onsi.github.io/ginkgo/

## Operadores famosos — docs

- **cert-manager**: https://cert-manager.io/docs/
- **external-secrets**: https://external-secrets.io/
- **CloudNativePG**: https://cloudnative-pg.io/documentation/
- **Zalando postgres-operator**: https://postgres-operator.readthedocs.io/
- **Crunchy PGO**: https://access.crunchydata.com/documentation/postgres-operator/
- **Strimzi (Kafka)**: https://strimzi.io/documentation/
- **Prometheus Operator**: https://prometheus-operator.dev/
- **Argo CD**: https://argo-cd.readthedocs.io/
- **Argo Workflows**: https://argo-workflows.readthedocs.io/
- **Argo Rollouts**: https://argoproj.github.io/argo-rollouts/
- **Istio**: https://istio.io/latest/docs/
- **Linkerd**: https://linkerd.io/2/overview/

## CNCF landscape y maturity

- CNCF Landscape — Automation & Configuration: https://landscape.cncf.io/
- CNCF Graduated / Incubating / Sandbox: https://www.cncf.io/projects/

## Lecturas recomendadas

- *Kubernetes Operators* (O'Reilly, Dobies & Wood, 2020).
- *Programming Kubernetes* (O'Reilly, Hausenblas & Schimanski, 2019) — base de controllers.
- KEP-95: CustomResourceDefinition versioning.
- KEP-1740: subresources `status`/`scale` para CRDs.
