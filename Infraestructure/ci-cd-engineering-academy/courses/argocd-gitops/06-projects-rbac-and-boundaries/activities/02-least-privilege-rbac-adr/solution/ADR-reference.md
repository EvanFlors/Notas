# ADR-001 (reference) — Migración de `legacy-everything` a projects acotados

> Esta es **una** solución razonable, no la única. Compara estructura y
> justificación con la tuya.

## Status

Accepted.

## Context

El project `legacy-everything` fue creado como atajo temporal en mayo 2024.
Hoy soporta 4 Applications en producción con permisos totalmente abiertos:

- `sourceRepos: ['*']` — cualquier repo puede entrar.
- `destinations: [{server:'*', namespace:'*'}]` — cualquier namespace de cualquier cluster.
- `clusterResourceWhitelist: [{group:'*',kind:'*'}]` — se puede crear `ClusterRoleBinding`, lo que permite escalada a cluster-admin.
- Un role `admin` con un JWT emitido hace >1 año; expiró, pero no se verificó revocación explícita.
- `orphanedResources.warn: false` — perdimos visibilidad de drift humano.

Resultado real: cualquier developer con permiso de crear `Application` en el
project puede desplegar lo que quiera donde quiera. No hay aislamiento entre
`team-payments` y `team-checkout`.

Las 4 Applications auditadas pertenecen a 3 dominios distintos:

| App | Repo | Destino | Recursos |
|-----|------|---------|----------|
| platform-monitoring | acme-platform/monitoring-stack | monitoring | Namespace + ClusterRole + ClusterRoleBinding + CRDs |
| payments-api | acme-payments/payments-manifests | payments-prod | Deployment, Service, ConfigMap, HPA |
| payments-worker | acme-payments/payments-manifests | payments-prod | Deployment, Service, ConfigMap, Secret, NetworkPolicy |
| checkout-ui | acme-checkout/checkout-manifests | checkout-prod | Deployment, Service, Ingress, ConfigMap |

## Decision

Reemplazamos `legacy-everything` por **tres** `AppProject` acotados:

1. **`platform`** — para `platform-monitoring` y cargas transversales futuras.
   - `sourceRepos: [github.com/acme-platform/*]`.
   - `destinations: [{server: in-cluster, namespace: 'monitoring'}, {..., 'kube-system'}, {..., 'cert-manager'}]`.
   - `clusterResourceWhitelist`: `Namespace`, `ClusterRole`, `ClusterRoleBinding`, `CustomResourceDefinition`. Justificado por scraping cross-namespace.
   - Role `platform-admin` → grupo OIDC `acme:platform-team`.

2. **`team-payments`** — para `payments-api` y `payments-worker`.
   - `sourceRepos: [github.com/acme-payments/*]`.
   - `destinations: [{server: in-cluster, namespace: 'payments-*'}]`.
   - `clusterResourceWhitelist: []` — platform provisiona namespaces y cualquier recurso cluster-scoped.
   - `namespaceResourceWhitelist`: `*` del grupo `''`, `apps`, `networking.k8s.io`, `autoscaling`.
   - Role `payments-admin` + role `ci-syncer` (JWT 24 h) para el pipeline.

3. **`team-checkout`** — análogo para `checkout-ui`.
   - `sourceRepos: [github.com/acme-checkout/*]`.
   - `destinations: [{server: in-cluster, namespace: 'checkout-*'}]`.
   - `clusterResourceWhitelist: []`.
   - Role `checkout-admin` + role `ci-syncer`.

El project `default` queda con `sourceRepos: []`, `destinations: []` — nadie
puede crear Applications sin especificar un project real.

## Consequences

Positivas:

- Aislamiento real entre equipos. Un error humano en `team-payments` no toca
  namespaces de checkout.
- Pipelines con JWT acotados: podemos emitirlos y rotarlos sin tocar la cuenta `admin`.
- Auditoría trazable: cada Application dice a qué dominio pertenece.
- Platform recupera control sobre cluster-scoped (nadie fuera de `platform`
  puede crear `ClusterRoleBinding`).

Negativas / costes:

- Hay que migrar las 4 Applications cambiando su `spec.project`. Breve ventana
  de "ambos projects coexistiendo".
- Platform asume el trabajo de crear namespaces para payments y checkout.
- Los nombres cambian: cualquier policy CSV externa que referenciara
  `legacy-everything/*` hay que reescribirla.

## Alternatives considered

- **A1: Un único project acotado para todos.** Rechazado — no aísla equipos.
  Era casi el estado actual con menos wildcards.
- **A2: Project por entorno (`prod`, `stg`, `dev`).** Rechazado — no cubre el
  caso donde el riesgo primario es la contaminación cross-team dentro de prod.
- **A3: Project por equipo-y-entorno (`team-payments-prod`, `team-payments-dev`).**
  Diferido — útil cuando prod tenga requisitos regulatorios distintos
  (PCI/HIPAA). Hoy duplica configuración sin ganancia.

## Migration plan

1. **T0** — Crear los 3 nuevos projects **sin** mover ninguna Application todavía.
   `legacy-everything` sigue vivo. Platform crea los namespaces nuevos si faltan.
2. **T0 + 1 día** — Para cada Application:
   - Cambiar `spec.project` al nuevo (merge en el repo de manifests, no edición
     manual).
   - Esperar reconciliation; verificar `Synced` y `Healthy` con el project nuevo.
3. **T0 + 3 días** — Verificar que `legacy-everything` ya no tiene Applications
   asociadas (`argocd app list -p legacy-everything` vacío).
4. **T0 + 3 días** — Revocar explícitamente cualquier JWT del role `admin` de
   `legacy-everything`:
   ```
   argocd proj role list-tokens legacy-everything admin
   argocd proj role delete-token legacy-everything admin <ID>
   ```
   Aunque ya expirara, dejamos la evidencia en el log.
5. **T0 + 4 días** — Borrar `legacy-everything` (`kubectl delete appproject legacy-everything -n argocd`).
6. **T0 + 4 días** — Endurecer `default`: `sourceRepos: []`, `destinations: []`.
7. **CI check** — Añadir a CI un gate que falle si cualquier `AppProject` del
   repo contiene `'*'` en `sourceRepos` o `destinations` (ver extensión E1).

Rollback: si cualquier Application falla, basta con `kubectl patch` para
devolverla a `legacy-everything` mientras se investiga; el project viejo sigue
existiendo hasta T0 + 4 días.
