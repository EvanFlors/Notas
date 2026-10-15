# Analysis: When NOT to introduce a service mesh

## Scenario

TODO: describe el escenario elegido (A, B, C, o uno propio): tamano del equipo, numero de clusters, workloads, FTE de plataforma, regulacion, dolor actual.

## Symptoms that would justify a mesh

- TODO: sintoma 1 (ej. "necesitamos mTLS automatico entre workloads porque PCI-DSS lo exige y no podemos tocar el codigo de 40 apps").
- TODO: sintoma 2.
- TODO: sintoma 3.
- TODO: sintoma 4.

## Preconditions before introducing a mesh

Para cada precondicion, indica como la mides. La palabra "Evidence" debe aparecer en cada bullet.

- TODO: precondicion 1 (ej. observabilidad base operativa). Evidence: TODO (ej. dashboards publicados, SLO cumplido 3 meses).
- TODO: precondicion 2 (policy framework activo). Evidence: TODO.
- TODO: precondicion 3 (FTE asignado al mesh). Evidence: TODO.
- TODO: precondicion 4 (budget CPU/memoria/latencia aceptado). Evidence: TODO.
- TODO: precondicion 5 (plan de rollback). Evidence: TODO.

## Red flags against introducing a mesh

- TODO: red flag 1 (ej. "equipo de plataforma de 2 FTE ya saturado").
- TODO: red flag 2.
- TODO: red flag 3.

## Alternatives without a mesh

- TODO: alternativa 1 (vincula a un sintoma). Ej. "mTLS limitado a pares criticos con cert-manager + SPIFFE".
- TODO: alternativa 2.
- TODO: alternativa 3.

## Decision

TODO: una linea que empiece por "We will NOT adopt a service mesh at this time" seguida de 1-2 frases de justificacion, O por "We will adopt (Istio|Linkerd|Cilium Service Mesh)" con justificacion.

## Revisit Conditions

- TODO: condicion 1 (ej. "si aparece un segundo cluster prod en otra region").
- TODO: condicion 2.
- TODO: condicion 3.
