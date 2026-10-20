# ADR-001: Platform Chart Contract

## Status

Accepted — 2026-10-15, Platform Team (reference solution; adapt names and dates for your context).

## Context

La organización corre ~ 55 charts internos a lo largo de 11 equipos de producto. ~ 70% son servicios HTTP/gRPC casi idénticos, ~ 15% son workers de colas, y el resto son casos específicos — notablemente un PostgreSQL "casero" basado en StatefulSet + Jobs que ha roto producción dos veces por backups fallidos silenciosos. Los `_helpers.tpl` están duplicados y divergen; los hooks de Helm están siendo usados de forma inconsistente; hay drift entre lo que Helm cree y lo que hay en el cluster; y no existe política de versionado de los charts internos. Argo CD acaba de instalarse y todavía no se usa en serio.

Decidimos ahora el **contrato del chart de plataforma** porque sin él cualquier migración a GitOps empeorará los síntomas (más superficie, misma inconsistencia). Tenemos 2 trimestres para la primera versión del contrato, con capacidad de iterar.

## Decisions

- Library chart: We will adopt the platform-lib library chart as the single source of shared helpers (labels, selectors, naming, probe defaults). Rationale: eliminates 55 copies of `_helpers.tpl`, enables uniform rollout of label/selector changes, and makes drift between teams observable at review time rather than at incident time.
- Golden chart: We will adopt a golden chart with escape hatch, exposing a `platform-app` chart that covers the 70% HTTP/gRPC and 15% worker cases via `kind: web | worker` plus `values`, while explicitly supporting per-app charts for the specific 15% that cannot be modeled uniformly. Rationale: avoids the "mini-Kubernetes in values.yaml" antipattern while preserving uniformity for the common case.
- GitOps engine: We will adopt Argo CD because it is already installed, has team familiarity, and offers ApplicationSet with list/git/matrix generators that fit the "same app across 3 clusters" shape of this org. Flux was considered but rejected to avoid introducing a second controller.
- Versioning policy: We will adopt SemVer with deprecation window, documenting MAJOR / MINOR / PATCH semantics explicitly, maintaining N and N-1 under patch, and requiring a `MIGRATING.md` for every MAJOR bump.

## Chart Contract

### What the golden chart offers

- Deployment (or StatefulSet when `kind: worker` with persistence) with configurable image, resources, replicas and HPA.
- Service + optional Ingress (TLS via cert-manager annotations) + ServiceMonitor if Prometheus is enabled.
- PodDisruptionBudget derived from `replicas` by default.
- Platform-standard labels and selector labels from `platform-lib` v1.
- NetworkPolicy with sensible defaults (deny-all + explicit egress to platform services).
- Pre-upgrade `helm.sh/hook` for schema migrations, with the equivalent `argocd.argoproj.io/hook: PreSync` annotation for GitOps parity.

### What the golden chart expects from product teams

- Container image signed by cosign and available on a pull-through registry.
- `livenessProbe` and `readinessProbe` endpoints exposed by the app on `/healthz` and `/ready`.
- `values.yaml` conforms to `values.schema.json` (no extra properties).
- Mandatory labels in `values`: `team`, `product`, `owner`.
- No reliance on `cluster-admin`; app runs under its own ServiceAccount with the generated minimal Role.
- Explicit `kind: web | worker` so the chart can select the right primitive.

## Versioning Policy

El chart interno (`platform-app` y la lib `platform-lib`) se versiona con SemVer explícito, independiente del `appVersion` de la aplicación consumidora:

- **MAJOR**: cualquier cambio incompatible en `values` (campo renombrado, type change, removal) o en los recursos aplicados (p. ej. la selector label cambia). Un consumidor **tiene que** editar algo. Un `MIGRATING.md` se publica junto con la release.
- **MINOR**: feature nueva compatible — nuevo `value` con default seguro, nuevo recurso opcional detrás de un flag.
- **PATCH**: bug fix sin cambio de interfaz.
- **Deprecation window**: cualquier `value` o helper que vaya a desaparecer se marca como *deprecated* en 2 MINOR previos, con warning renderizado por el chart. Las versiones N y N-1 reciben patches de seguridad.
- Se mantiene un `CHANGELOG.md` por chart. El pipeline bloquea PRs sin entrada en el changelog.

## GitOps Integration

Los charts se consumen desde Argo CD vía `Application` (o `ApplicationSet` cuando sea la misma app en varios clusters/entornos). Un `values-<env>.yaml` por entorno vive junto al chart (o como *multiple sources* si se separa el repo de config del repo del chart).

Trampas conocidas y cómo las aceptamos:

- Argo CD **no ejecuta `helm install`**: renderiza con `helm template` y aplica. No hay Secret de release de Helm — `helm list` no verá nada. El rollback es `argocd app rollback` o `git revert`, no `helm rollback`.
- Los **hooks de Helm** se mapean a hooks de Argo (`PreSync`, `PostSync`, `SyncFail`). Weights no son 1:1; los charts internos documentan en cada hook la equivalencia Argo.
- `releaseName` debe fijarse explícitamente en el `Application`; si no, Argo usa `metadata.name`, lo que cambia los nombres que generan los helpers `fullname`.
- `--atomic` y `--wait` de la CLI no aplican; se replican con `syncPolicy.retry` + `syncOptions`.

Equipos documentan en el chart un `README.md` con el bloque `Application` recomendado y los flags Argo esperados.

## Boundary: Helm vs Kustomize vs Operator

- Scenario A — HTTP/gRPC estándar (70% de los charts hoy): We will use Helm with the `platform-app` golden chart. Reason: variación por entorno es tabular (imagen, replicas, 3-4 flags), hay valor en release lifecycle (`helm history` cuando se usa fuera de Argo, hooks de migration), y centralizar en un golden chart elimina 40 copias casi idénticas.
- Scenario B — Overrides corporativos uniformes a charts de terceros (ingress-nginx, cert-manager, external-dns): We will use Kustomize as a post-renderer applied to all third-party charts. Reason: necesitamos inyectar labels corporativos, tolerations y nodeSelectors que **no son** `values` oficiales de los charts upstream; forkear cada chart es intratable y el post-renderer es la vía oficial para patches uniformes sin templatizar más.
- Scenario C — PostgreSQL "casero" (StatefulSet + Jobs de backup custom): We will use an Operator (CloudNativePG). Reason: la operación requiere lógica continua (failover, backups condicionales con alerting, PITR), el estado deseado no es expresable como YAML estático, y el histórico de incidentes muestra que un chart no se auto-sana. Un operador maduro envuelve el dominio y expone CRDs (`PostgresCluster`) que el equipo consume sin saber qué StatefulSet hay debajo.

## Alternatives Considered

- Mantener 55 charts separados con `_helpers.tpl` duplicado — rechazado: coste de mantenimiento crece con cada equipo nuevo; divergencia garantizada; no hay forma de empujar un cambio de label a toda la plataforma.
- Un único "mega-golden-chart" que cubra el 100% de casos — rechazado: termina siendo un intérprete YAML con 300 knobs sin `values.schema.json` útil; los casos específicos (PostgreSQL custom, gateway Envoy) corrompen el contrato.
- Flux en vez de Argo CD — rechazado por ahora: Argo ya está instalado, hay familiaridad del equipo, y ApplicationSet cubre el patrón "misma app en N clusters" que tenemos. Si en 12 meses necesitamos ejecución real de hooks server-side y Argo no mejora en ese frente, reconsideramos.
- Migrar todo a Kustomize puro — rechazado: perdemos release lifecycle, hooks de migration DB se vuelven más complejos, y los charts que distribuimos a stakeholders fuera del core (p. ej. equipos de data) esperan un chart Helm.

## Consequences

- La plataforma tiene un contrato real y versionado; los upgrades dejan de ser un trabajo artesanal por chart.
- Los equipos pierden algo de flexibilidad en el 70% de los casos (deben ajustarse al `platform-app`) a cambio de velocidad y de recibir mejoras gratis.
- Introducir CloudNativePG requiere un periodo de migración y formación; a cambio, se elimina una fuente histórica de incidentes.
- Argo CD se vuelve un camino crítico; su upgrade o fallo bloquea cambios. Se formalizan runbooks y una ventana de mantenimiento mensual.
- El equipo de plataforma asume el rol de "mantenedor de un producto" (chart interno) con changelog, deprecation window y soporte. Hay que planificar el tiempo que esto consume.

## Risks and Mitigations

- Risk: el golden chart se vuelve un "mini-Kubernetes" si cada equipo pide un knob. Mitigation: política explícita "no se añaden `values` sin un escenario documentado y respaldado por al menos 2 equipos"; `values.schema.json` prohíbe campos extra para forzar la conversación.
- Risk: la migración a CloudNativePG retrasa roadmap de otros equipos. Mitigation: migración por fases (dev → stg → prod) con doble escritura y plan de rollback; equipo de plataforma dedica 20% de capacidad al proyecto durante 1 trimestre.
- Risk: `_helpers.tpl` de `platform-lib` v1 rompe charts existentes al adoptar la lib. Mitigation: `platform-lib` arranca en v0.x, los primeros meses son compatibles con los helpers legacy, y la v1 llega con `MIGRATING.md` y período de deprecation de 2 MINOR previos.
- Risk: los equipos saltan Argo CD con `kubectl apply` directo (drift). Mitigation: RBAC endurecido, política OPA/Kyverno que exija label `argocd.argoproj.io/instance`, y auditoría semanal del drift reportado por Argo.

## Review Triggers

- Si el número de charts internos crece por encima de 100, reconsiderar si el modelo golden chart escala o si hace falta multi-tenant platform.
- Si Argo CD introduce ejecución real de hooks server-side (o Flux ofrece ApplicationSet-equivalente estable), reevaluar el engine.
- Si aparece un segundo caso tipo "PostgreSQL casero" (ej. Kafka custom), subir prioridad a adopción de operadores de dominio.
- Si el lead time p50 de deploy no baja en 2 trimestres tras adopción del golden chart + GitOps, auditar el contrato.
