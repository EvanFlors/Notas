# k8s-14-operators-and-crds — Operadores y CRDs

## Identificación
- **ID:** `k8s-14-operators-and-crds`
- **Nivel:** avanzado
- **Duración estimada:** 7 h
- **Prerrequisitos:** `k8s-11-control-plane-internals`, `k8s-12-rbac-serviceaccounts-admission-policy`

## Objetivo
Extender el API de Kubernetes con **CustomResourceDefinitions (CRDs)** y escribir un **controller mínimo** que las reconcilie, para después evaluar con criterio operadores de terceros.

## Temas y subtemas

1. **CRD** y versionado (`v1alpha1 → v1beta1 → v1`), conversion webhooks.
2. **Operator pattern**: controller + domain knowledge.
3. Frameworks: **controller-runtime**, **Operator SDK**, **Kubebuilder**, **Metacontroller**.
4. Estado del arte en operadores famosos:
   - Postgres: **CloudNativePG**, **Zalando postgres-operator**.
   - Kafka: **Strimzi**.
   - PKI: **cert-manager**.
   - Secretos: **external-secrets**.
   - CD / workflows: **Argo CD**, **Argo Workflows**.
5. Diseño de API: sub-resources `status`, printer columns, categorías, short names, scope `Namespaced` vs `Cluster`.
6. Testing con **envtest** (controller-runtime).
7. Observabilidad del operador (metrics, eventos).
8. Criterios de adopción / rechazo de un operador de terceros.

## Conceptos internos (fundamentos)

- Un **operador** *es* un controller que lee CustomResources (CRs) y produce recursos nativos (Deployments, Services, Secrets, …) para converger el estado deseado.
- El sub-resource **`/status`** separa escrituras de `spec` (usuarios) y `status` (controller) para evitar conflictos y respetar RBAC.
- El **versionado** (`v1alpha1 → v1beta1 → v1`) + **conversion webhooks** permite evolucionar la API sin romper usuarios.
- `envtest` arranca un **kube-apiserver + etcd** reales sin kubelet para probar reconciliación rápido y sin cluster completo.

## Competencias

- **Conceptual:** explicar por qué un operador es "controller + conocimiento de dominio" y cuándo aplica.
- **Operativa:** escaffoldear un operador con Kubebuilder, implementar un `Reconcile`, probarlo contra un cluster kind.
- **Arquitectónica:** evaluar y decidir sobre operadores de terceros (criterios de madurez, upgrade story, blast radius).

## Ejemplos

- `examples/01-crd-echo-controller/` — CRD mínima + esqueleto de controller.
- `examples/02-cert-manager-overview/` — walkthrough de instalación y `ClusterIssuer`.
- `examples/03-cnpg-postgres-operator/` — CloudNativePG como operador maduro de referencia.

## Actividades

- `activities/01-write-echo-operator-with-kubebuilder/` — mini-proyecto: operador `Echo` que materializa un ConfigMap.
- `activities/02-evaluate-postgres-operators/` — evaluación independiente: CloudNativePG vs Zalando.

## Entregables

- Operador **echo** funcional (o, como fallback sin Go/Kubebuilder, CRD YAML + pseudocódigo de `Reconcile` documentados).
- Documento `EVALUATION.md` comparando dos operadores de Postgres con recomendación justificada.

## Criterios de evaluación

- **Diseño del CRD**: tipos correctos, `status` como sub-resource, printer columns útiles.
- **Reconcile**: idempotente, maneja `NotFound`, usa `controllerutil.CreateOrUpdate` o equivalente, setea `ownerReferences`.
- **Evaluación de terceros**: usa criterios explícitos (madurez, backup/restore, HA, upgrade path, comunidad, blast radius, docs, licencia).

## Recursos

Ver `resources/links.md`.
