# Recursos — sec-12

Referencias oficiales y lecturas de apoyo. Verificar vigencia en Fase 4 del curso.

## Falco (oficiales)

- Sitio: `https://falco.org/`
- Documentación: `https://falco.org/docs/`
- Reglas por defecto: `https://github.com/falcosecurity/rules`
- Helm charts: `https://github.com/falcosecurity/charts`
- Falcosidekick (outputs): `https://github.com/falcosecurity/falcosidekick`
- Drivers (modern_ebpf vs kmod vs ebpf legacy): `https://falco.org/docs/concepts/event-sources/kernel/`
- Lenguaje de reglas: `https://falco.org/docs/concepts/rules/`
- Supported fields: `https://falco.org/docs/reference/rules/supported-fields/`
- Exceptions: `https://falco.org/docs/concepts/rules/exceptions/`
- K8s audit rules: `https://falco.org/docs/concepts/event-sources/kubernetes-audit/`

## Tetragon (oficiales)

- Sitio: `https://tetragon.io/`
- Documentación: `https://tetragon.io/docs/`
- Instalación en K8s: `https://tetragon.io/docs/installation/kubernetes/`
- TracingPolicy reference: `https://tetragon.io/docs/concepts/tracing-policy/`
- Enforcement (`matchActions`): `https://tetragon.io/docs/concepts/tracing-policy/selectors/#matchactions`
- Ejemplos de policies: `https://github.com/cilium/tetragon/tree/main/examples/tracingpolicy`

## eBPF (fundamentos)

- Introducción: `https://ebpf.io/what-is-ebpf/`
- BTF / CO-RE: `https://nakryiko.com/posts/btf-dedup/`
- `bpftool`: `https://docs.ebpf.io/linux/concepts/bpftool/`

## CNCF / contexto

- Falco (CNCF graduado): `https://www.cncf.io/projects/falco/`
- Tetragon (parte de Cilium, CNCF graduado): `https://www.cncf.io/projects/cilium/`
- CNCF Security Technical Advisory Group: `https://github.com/cncf/tag-security`

## Audit logs y forense

- Kubernetes audit logging: `https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/`
- MITRE ATT&CK for Containers: `https://attack.mitre.org/matrices/enterprise/containers/`

## Comparativas y lecturas

- Falco vs Tetragon vs Tracee — buscar artículos recientes (CNCF blog, Sysdig blog, Isovalent blog).
- "Runtime security best practices" — CNCF SIG Security.
- "The security maturity model" — para ubicar runtime en la curva.

## Herramientas relacionadas (fuera del scope del módulo)

- **Tracee** (Aqua Security): otro agente runtime basado en eBPF.
- **KubeArmor**: enforcement vía LSM.
- **Pixie** (New Relic): más orientado a debugging y observabilidad, pero comparte el sustrato eBPF.

## Checklist de verificación requerida en Fase 4

- Versión de Falco (estable y la del Helm chart).
- Driver recomendado por defecto (`modern_ebpf` vs `ebpf` legacy).
- Versión mínima de kernel para `modern_ebpf` (hoy ≥ 5.8 BTF).
- Versión de Tetragon y disponibilidad del enforcement (`matchActions: Sigkill`).
- Estado del Helm chart de Tetragon (upstream Cilium o Isovalent).
- Cambios recientes en el DSL de reglas Falco (campo nuevo o deprecación).
