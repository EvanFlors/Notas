# Analysis: When NOT to introduce a service mesh

> Respuesta de referencia para el escenario **C** (fintech PCI-DSS, 60 ingenieros, 2 clusters, 40 microservicios, 3 FTE de plataforma). No es la única razonable.

## Scenario

Fintech regulada por PCI-DSS. 60 ingenieros en 7 equipos; 2 clusters EKS (stage y prod); 40 microservicios HTTP/gRPC; Postgres y Kafka managed fuera del cluster; equipo de plataforma de 3 FTE; dolor actual = drift, auditoría, lead time, coste no visible. No hay mesh.

## Symptoms that would justify a mesh

- Necesidad de mTLS automático entre todos los workloads sin modificar las apps (PCI-DSS exige cifrado en tránsito, pero no exige mesh; cifrar end-to-end en apps es alternativa).
- Observabilidad L7 uniforme en apps que **no** podemos instrumentar (legacy, de terceros, binarios cerrados).
- Canary / mirroring multi-servicio con reglas finas que Ingress + Argo Rollouts no cubren.
- AuthZ L7 inter-servicio por método/path/header gestionada centralmente, no por app.
- Service discovery y mTLS cross-cluster para una topología multi-cluster activa.

## Preconditions before introducing a mesh

- Observabilidad base operativa (Prometheus + Grafana + Loki + Tempo + OTel). Evidence: dashboards publicados y SLO de freshness cumplido durante 3 meses consecutivos; alerts con MTTA < 15 min.
- Policy framework activo con PSA `restricted` + Kyverno. Evidence: 100% de los Pods admitidos cumpliendo `restricted`; informe mensual de denegaciones.
- GitOps en régimen (Argo CD en zona verde). Evidence: ≥ 95% de los `Application` healthy durante 2 meses; sync time p95 ≤ 5 min.
- FTE dedicado al mesh. Evidence: 1 persona asignada a tiempo completo durante 6 meses mínimo, con backup; documentado en el org chart.
- Budget de CPU/memoria y latencia aceptado por los equipos de producto. Evidence: medición P50/P99 por servicio antes/después en un namespace de staging; sign-off escrito de product owners.
- Plan de rollback probado. Evidence: runbook publicado + simulacro de desinstalación en staging ejecutado y documentado.

## Red flags against introducing a mesh

- Equipo de plataforma de 3 FTE ya saturado por la migración a GitOps y policy — mesh añadiría una pieza más que operar sin bandwidth.
- Dolor principal es **drift y auditoría**, no observabilidad L7 ni traffic shaping; mesh no ataca el problema prioritario.
- Postgres y Kafka están **fuera** del cluster; el valor del mTLS automático inter-pod baja (los pares más sensibles no son pod-a-pod en K8s).
- Sin equipo SRE 24/7, un upgrade fallido del control plane del mesh en viernes es un incidente mayor.
- No hay histórico de incidentes atribuibles a "falta de mesh"; introducirlo sería *prevention theater*.

## Alternatives without a mesh

- mTLS limitado a pares críticos con cert-manager emitiendo certs mutuos (o SPIFFE/SPIRE cuando se necesite identity workload-level), sin sidecars.
- Observabilidad L7 vía OpenTelemetry en las apps nuevas + exporters de métricas HTTP en las existentes; mesh no es imprescindible para RED metrics.
- Canary/blue-green con **Argo Rollouts** (o Flagger) + Gateway API — cubre ≥ 80% de los escenarios de progressive delivery sin instalar un control plane extra.
- AuthZ L7 en el edge (Gateway + ext_authz / OPA) y JWT verificación en el servicio receptor; evita AuthZ transversal pod-a-pod.
- Service discovery cross-cluster vía DNS federado + VPN/transit gateway cuando haga falta; mesh multi-cluster es solo útil con muchos pares cross-cluster.

## Decision

We will NOT adopt a service mesh at this time. El dolor prioritario (drift, auditoría, lead time, coste no visible) se resuelve con GitOps + policy + cost showback, no con mesh. Introducir un mesh ahora consumiría FTE escaso sin resolver el problema real.

## Revisit Conditions

- Aparece un segundo cluster prod en otra región (o un multi-tenant interno) y requerimos service discovery/mTLS cross-cluster.
- Más de 2 incidentes trimestrales con causa raíz "falta de observabilidad L7 inter-service" o "falta de mTLS entre pods" demostrada por post-mortem.
- Volumen de canary/blue-green supera lo que Argo Rollouts + Gateway API cubre cómodamente para los equipos.
- El equipo de plataforma pasa a ≥ 5 FTE con capacidad real para operar un control plane adicional 24/7.
- Nueva regulación o requisito de cliente que **exija explícitamente** cifrado automático inter-workload documentable por auditoría externa (no cubrible con cert-manager + policy).
