# k8s-12 — RBAC, ServiceAccounts, Admission y Policy-as-Code

## Identificación

- **ID:** `k8s-12-rbac-serviceaccounts-admission-policy`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-11-control-plane-internals`

## Objetivo

Autorizar peticiones al API server con el mínimo privilegio necesario y validar/mutar objetos antes de persistirlos mediante policy-as-code. Al terminar el módulo serás capaz de diseñar RBAC por workload, aplicar `Pod Security Admission` restricted y escribir políticas obligatorias con Kyverno y `ValidatingAdmissionPolicy`.

## Temas

- **ServiceAccount** y token projection (`projected` volume, `BoundServiceAccountTokenVolume`, audiencias).
- **RBAC**: `Role`, `RoleBinding`, `ClusterRole`, `ClusterRoleBinding`, aggregation (`aggregationRule`).
- Patrón **least privilege**: un SA por workload, verbos exactos, resources exactos.
- **Impersonation** (`--as`, `--as-group`) y auditoría.
- **Admission controllers built-in**: `NamespaceLifecycle`, `ResourceQuota`, `LimitRanger`, `PodSecurity`, `ServiceAccount`, `DefaultStorageClass`, etc.
- **MutatingAdmissionWebhook** y **ValidatingAdmissionWebhook** (orden y riesgos).
- **ValidatingAdmissionPolicy (VAP)** con CEL en el API server (sin webhook externo).
- **Pod Security Admission (PSA)**: labels `enforce|audit|warn=baseline|restricted` por namespace.
- **OPA/Gatekeeper**: `ConstraintTemplate` + `Constraint` + Rego.
- **Kyverno**: `ClusterPolicy` declarativa (mutate/validate/generate) + `verifyImages` con cosign/sigstore.

## Conceptos internos (fundamentos)

Una request viaja así por el API server:

```
cliente → authn → authz(RBAC) → mutating admission → object schema validation →
                                 validating admission → persist (etcd)
```

- **authn** verifica *quién* eres (cert, token, OIDC).
- **authz (RBAC)** verifica *qué puedes hacer* contra `verb × resource × namespace`.
- **mutating admission** puede *modificar* el objeto (inyectar sidecars, defaults).
- **validating admission** puede *rechazar* el objeto pero no modificarlo.
- **ValidatingAdmissionPolicy** evalúa CEL dentro del API server (sin salto de red).
- **Kyverno** habla YAML; **Gatekeeper** habla Rego. Ambos son webhooks.

## Competencias

- **Conceptual:** explicar los 5 pasos de una request y qué puede denegarla en cada uno.
- **Operativa:** escribir RBAC mínimo por workload y auditar `cluster-admin` indebido.
- **Arquitectónica:** elegir entre VAP, Kyverno y Gatekeeper por caso de uso.

## Ejemplos

- `examples/01-rbac-least-privilege/` — `Role` + `RoleBinding` mínimos para un reader.
- `examples/02-psa-restricted-namespace/` — namespace con labels `enforce=restricted`.
- `examples/03-kyverno-require-signed-image/` — `ClusterPolicy` con `verifyImages`.
- `examples/04-validatingadmissionpolicy-cel/` — VAP que exige `runAsNonRoot: true` sin webhook externo.

## Actividades

- `activities/01-write-rbac-for-ci-user/` — **guided-lab**: diseñar RBAC para un usuario de CI que despliega una app pero no debe ver secretos ni modificar nodos.
- `activities/02-enforce-signed-images-cluster-wide/` — **independent**: instalar Kyverno y escribir una `ClusterPolicy` que rechace imágenes sin firma.

## Entregables

- Cluster `kind` con namespace `apps` etiquetado `enforce=restricted`.
- `ServiceAccount` + `Role` + `RoleBinding` para el usuario CI, validados con `kubectl auth can-i`.
- Kyverno instalado y una `ClusterPolicy` activa que rechaza Pods sin firma de imagen.

## Criterios de evaluación

- **Conceptual:** diagramar la cadena `authn → authz → mutating → validating → persist` sin consultar docs.
- **Operativa:** auditar un `ClusterRoleBinding` que da `cluster-admin` a un `ServiceAccount` de aplicación y proponer la corrección mínima.
- **Arquitectónica:** decidir cuándo usar VAP (CEL) frente a Kyverno frente a Gatekeeper para una política concreta.

## Recursos

Ver `resources/links.md`.
