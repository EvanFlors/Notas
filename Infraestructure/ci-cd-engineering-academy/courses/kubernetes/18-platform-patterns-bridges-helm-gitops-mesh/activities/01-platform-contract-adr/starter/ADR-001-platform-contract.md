# ADR-001: Platform Contract

## Status

TODO: Proposed | Accepted | Superseded, con fecha y autor.

## Context

TODO: resume el escenario (lee la sección 5.1 del README) y las restricciones que más pesan: equipos, clusters, regulación (PCI-DSS), estado actual (kubectl apply desde CI con cluster-admin), dolor (lead time, drift, auditoria, coste).

Describe en 1-2 parrafos *qué* vas a decidir y *por qué ahora*.

## Decisions

Cada decision debe empezar literalmente por "We will adopt". Ejemplos de forma (sustituye el placeholder por tu eleccion real):

- Packaging: We will adopt TODO (Helm | Kustomize | Helm and Kustomize) because TODO.
- GitOps:    We will adopt TODO (Argo CD | Flux) because TODO.
- Service mesh: We will adopt TODO (no service mesh | Istio | Linkerd | Cilium Service Mesh) because TODO.
- Cost management: We will adopt TODO (OpenCost | Kubecost | no cost management) because TODO.

## Platform Contract

### What the platform offers

- TODO: ingress / cert-manager / observabilidad OSS / policy / backup / GitOps / ...
- TODO: ...
- TODO: ...

### What the platform expects from product teams

- TODO: health probes correctas, requests/limits realistas, labels obligatorios (team, product), imagenes firmadas, no cluster-admin.
- TODO: ...
- TODO: ...

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

- TODO: Risk 1 — descripcion. Mitigation: ...
- TODO: Risk 2 — descripcion. Mitigation: ...
- TODO: Risk 3 — descripcion. Mitigation: ...

## Review Triggers

- TODO: trigger 1 (ej. "si lead time p50 no baja en 3 meses, revisamos").
- TODO: trigger 2 (ej. "si aparece un segundo cluster prod en otra region, revisamos mesh y multi-cluster GitOps").
