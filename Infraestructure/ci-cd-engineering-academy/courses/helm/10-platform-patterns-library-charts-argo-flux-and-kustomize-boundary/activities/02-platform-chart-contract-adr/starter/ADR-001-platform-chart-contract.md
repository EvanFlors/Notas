# ADR-001: Platform Chart Contract

## Status

TODO: Proposed | Accepted | Superseded, con fecha y autor.

## Context

TODO: resume el escenario (lee la seccion 5.1 del README): 55 charts internos, 11 equipos, Argo CD recien instalado, dolores (helpers duplicados, hooks fragiles, PostgreSQL casero, drift, versionado inexistente), 2 trimestres para la primera version del contrato. Describe en 1-2 parrafos *que* vas a decidir y *por que ahora*.

## Decisions

Cada decision debe empezar literalmente por "We will adopt". Ejemplos de forma (sustituye el placeholder por tu eleccion real):

- Library chart: We will adopt TODO (platform-lib library chart | no library chart) because TODO.
- Golden chart: We will adopt TODO (platform-app golden chart | one chart per app | golden chart with escape hatch) because TODO.
- GitOps engine: We will adopt TODO (Argo CD | Flux) because TODO.
- Versioning policy: We will adopt TODO (SemVer with deprecation window | ad-hoc | calendar versioning) because TODO.

## Chart Contract

### What the golden chart offers

- TODO: Deployment + Service + optional Ingress + HPA + PDB + probes + resources defaults.
- TODO: standard labels from platform-lib.
- TODO: ...

### What the golden chart expects from product teams

- TODO: image signed by cosign, probe path configurable, required labels (team, product).
- TODO: no cluster-admin.
- TODO: ...

## Versioning Policy

TODO: define reglas SemVer para el chart interno. Debe mencionar explicitamente los tres niveles MAJOR / MINOR / PATCH, la deprecation window (ej. "N y N-1 reciben patches; se deprecan values con N-2 anuncios previos"), y la obligatoriedad de un MIGRATING.md por cada MAJOR.

## GitOps Integration

TODO: describe como se consume el chart desde el engine elegido (Application de Argo o HelmRelease de Flux), con que valueFiles por entorno, y nombra al menos una trampa conocida (hooks de Helm bajo Argo, releaseName, Secret de release ausente, ...).

## Boundary: Helm vs Kustomize vs Operator

TODO: tres bullets, uno por escenario del dolor organizacional. Formato esperado:

- Scenario A - "<nombre del caso>": We will use TODO (Helm | Kustomize | Operator). Reason: TODO.
- Scenario B - "<nombre del caso>": We will use TODO (Helm | Kustomize | Operator). Reason: TODO.
- Scenario C - "<nombre del caso>": We will use TODO (Helm | Kustomize | Operator). Reason: TODO.

Al menos uno debe elegir Operator (recuerda el PostgreSQL casero del escenario).

## Alternatives Considered

- TODO: alternativa 1 descartada y por que.
- TODO: alternativa 2 descartada y por que.
- TODO: alternativa 3 descartada y por que.

## Consequences

- TODO: consecuencia 1 (positiva o negativa).
- TODO: consecuencia 2.
- TODO: consecuencia 3.
- TODO: consecuencia 4.

## Risks and Mitigations

- Risk: TODO. Mitigation: TODO.
- Risk: TODO. Mitigation: TODO.
- Risk: TODO. Mitigation: TODO.

## Review Triggers

- TODO: trigger 1 (ej. "si crece a 150 charts internos").
- TODO: trigger 2 (ej. "si el lead time p50 no baja en 3 meses").
