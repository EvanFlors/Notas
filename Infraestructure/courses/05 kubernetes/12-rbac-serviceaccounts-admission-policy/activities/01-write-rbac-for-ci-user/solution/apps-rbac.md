# ADR — RBAC para ci-deployer

## Status
Accepted — 2026-10-15

## Context

Hasta hoy, la pipeline usaba el `ServiceAccount` `default` del namespace `apps` con un `ClusterRoleBinding` a `cluster-admin`. Esto le daba:

- Acceso total a Secrets de todo el cluster (incluido `kube-system`, donde viven credenciales del control plane).
- Posibilidad de crear, modificar y eliminar cualquier objeto RBAC (escalada total).
- Capacidad de modificar Nodes y evictear workloads críticos.

El riesgo materializable es trivial: una vulnerabilidad RCE en la pipeline o un script comprometido tiene impacto cluster-wide. La guía NSA/CISA (2022) marca este patrón como "critical" en el ranking de hardening.

## Decision

- Un `ServiceAccount` dedicado `ci-deployer` en `apps`, con `automountServiceAccountToken: false` (el token solo se monta en Pods que explícitamente lo necesitan).
- Un `Role` namespace-scoped con verbos y resources exactos:
  - `pods`, `pods/log`: solo lectura.
  - `services`, `deployments`: CRUD acotado.
  - `replicasets`: lectura.
- `RoleBinding` en el mismo namespace. **No** se crea ningún objeto cluster-scope.
- No se habilita `delete` por default: cualquier borrado debe ser explícito y revisado (minimiza daño de un bug de pipeline).

## Consequences

**Positivas:**
- El blast radius de un compromiso de pipeline queda confinado al namespace `apps`.
- Secrets del cluster y de otros namespaces siguen fuera de alcance.
- La auditoría (`kubectl auth can-i --list`) devuelve una lista corta y revisable.

**Negativas / costos:**
- Si la pipeline necesita un verbo nuevo (p. ej. `delete deployments` para rollback destructivo) hay que ampliar el `Role` conscientemente, no "mágicamente".
- Si crece el número de apps en `apps`, cada una debería tener su propio SA (no reciclar `ci-deployer`).

**Pendiente (fuera de scope):**
- Rotar el `ServiceAccount` token legacy si existe algún `Secret` tipo `kubernetes.io/service-account-token` ligado al SA `default` previo.
- Añadir una `ValidatingAdmissionPolicy` que impida crear `ClusterRoleBinding` a `cluster-admin` para subjects de tipo `ServiceAccount` fuera de `kube-system`.
