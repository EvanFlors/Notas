# ADR-001: Platform Contract

> **Nota didáctica.** Esta es *una* respuesta razonada para el escenario del README. No es la única correcta. Lee tu ADR, lee este, y defiende las diferencias.

## Status

Accepted — 2026-10-13 — Platform Team (3 FTE).

## Context

Fintech regulada por PCI-DSS. 60 ingenieros en 7 equipos, 2 clusters EKS (stage, prod) y 1 kind local por dev. 40 microservicios HTTP/gRPC; Postgres y Kafka managed fuera del cluster. CI despliega hoy con `kubectl apply` desde un rol `cluster-admin` compartido; drift frecuente y auditoría frágil para PCI-DSS. Ya existen `kube-prometheus-stack`, `cert-manager`, `ingress-nginx`, `Velero` y Pod Security Admission `baseline`. No hay policy framework, GitOps, mesh ni cost visibility. Equipo de plataforma de 3 FTE con 6 meses para la v1 del contrato.

El objetivo es **cerrar drift**, **devolver auditabilidad** y **recuperar lead time** sin introducir piezas que la plataforma no pueda operar. Las decisiones se toman con el principio *menos cajas, más tarde*.

## Decisions

- Packaging: We will adopt Helm and Kustomize because upstream (operators, ingress, prometheus stack, cert-manager) es Helm por defecto, mientras que nuestras ~40 apps internas son casi idénticas entre entornos y se expresan mejor como `base/ + overlays/` sin templating.
- GitOps: We will adopt Argo CD because la UI acelera la adopción con 7 equipos aprendiendo a la vez, `ApplicationSet` cubre nuestra matriz clusters × apps, y PCI-DSS se beneficia de un modelo donde las credenciales del cluster no viajan a CI.
- Service mesh: We will adopt no service mesh because los síntomas que justificarían un mesh (mTLS automático inter-workload, L7 obs uniforme sobre apps no instrumentables, canary multi-service) no son el dolor actual; nuestro dolor es drift y auditoría, no observabilidad L7. Añadir Istio o Linkerd hoy consumiría FTE de los 3 disponibles sin resolver el problema prioritario.
- Cost management: We will adopt OpenCost because es CNCF, open source, se integra con el Prometheus que ya operamos, y queremos **showback** por `team=` y `product=` antes de siquiera hablar de chargeback.

## Platform Contract

### What the platform offers

- Ingress HTTPS listo (ingress-nginx + cert-manager + Let's Encrypt / ACM).
- Observabilidad base (Prometheus Operator + Grafana + Loki + dashboards oficiales), con `ServiceMonitor` disponible para apps.
- Policy framework (Kyverno) con policies obligatorias cluster-wide: `restricted` PSA, no `cluster-admin` para apps, imágenes firmadas con cosign, labels `team` y `product` requeridos.
- GitOps: Argo CD con `AppProject` por equipo y `ApplicationSet` por entorno.
- Backup: Velero con snapshots CSI y restore testeado trimestralmente.
- Cost visibility: OpenCost en showback, dashboards por `namespace`, `team`, `product`.
- Secret delivery: External Secrets Operator contra AWS Secrets Manager (no secretos en Git).
- SLOs de plataforma publicados: lead time PR→prod p95 ≤ 20 min; disponibilidad del plano GitOps ≥ 99.5% mensual.

### What the platform expects from product teams

- Health probes bien definidas (`readiness`, `liveness`, `startup` donde aplique) y no `liveness` dependiente de servicios externos.
- `requests/limits` realistas; QoS `Burstable` como mínimo para workloads críticos.
- Labels obligatorios: `app.kubernetes.io/name`, `team`, `product`, `env`.
- Imágenes firmadas con cosign (política bloquea las no firmadas en admission).
- No `privileged`, `hostNetwork`, `hostPID`, `hostPath` salvo exención documentada.
- Chart propio (Helm o Kustomize) en el monorepo de la app; nada de `kubectl apply` manual.
- Participación en game-days trimestrales de restore y upgrade.

## Alternatives Considered

- Flux en lugar de Argo CD — descartado porque, con 7 equipos nuevos a GitOps simultáneamente, la UI de Argo CD reduce curva de aprendizaje; además queremos un `AppProject` por equipo y `ApplicationSet` nativo.
- Solo Helm (sin Kustomize) — descartado: forzaría a templating a ~40 apps internas que son casi idénticas entre entornos; los overlays son más legibles para esos casos.
- Introducir Istio ya mismo "para PCI-DSS" — descartado: PCI-DSS no exige mesh; exige segmentación, auditoría y control de acceso, que Kyverno + NetworkPolicy + GitOps cubren con menos operabilidad.
- Kubecost en lugar de OpenCost — descartado por coste de licencia y porque las features comerciales (multi-cluster, forecasts) no son prioritarias aún; podemos migrar más adelante dado que Kubecost es un superconjunto.
- Mantener `kubectl apply` desde CI con mejoras (role per team) — descartado: no cierra drift ni mejora auditoría; perpetúa el acoplamiento credenciales-CI.

## Consequences

- (+) Fin del drift silencioso: Argo CD reporta y auto-cura divergencias; `git revert` es nuestro rollback.
- (+) PCI-DSS gana trazabilidad: todo cambio es un commit auditable; policies obligatorias en admission dejan evidencia.
- (+) Cost showback crea presión sana sobre sobre-aprovisionamiento (requests infladas → señal visible por equipo).
- (-) Curva de aprendizaje para los 7 equipos: nuevo flujo (PR → Argo sync) + nuevo policy framework; esperamos 4–8 semanas de ramp-up por equipo.
- (-) 3 FTE de plataforma quedan muy ocupados durante los primeros 3 meses (bootstrap, docs, soporte, migración app por app).
- (+) Sin mesh, el budget de latencia P99 y de CPU/memoria queda intacto para los workloads.
- (-) Sin mesh, el mTLS inter-workload sigue siendo manual (o inexistente para apps internas); aceptable mientras los pares críticos tengan TLS en la app o detrás de ingress.

## Risks and Mitigations

- Risk 1 — Adopción desigual: algún equipo sigue haciendo `kubectl apply` por costumbre. Mitigation: deshabilitar el token `cluster-admin` compartido tras M2; auditoría semanal; `OnlyRunByGitOps` Kyverno policy que rechaza objetos sin anotación `argocd.argoproj.io/tracking-id`.
- Risk 2 — Sobrecarga del equipo de plataforma durante la migración. Mitigation: freeze de features del backlog interno de la plataforma durante M1–M3; comunicaciones semanales con producto; un "office hour" fijo semanal.
- Risk 3 — Falso ahorro por OpenCost mal etiquetado (apps sin `team`/`product`). Mitigation: Kyverno obliga labels requeridos; dashboard "unlabeled cost" visible en el canal de plataforma; owners nombrados.
- Risk 4 — PCI-DSS pide pruebas de restore y nunca ejecutamos uno real. Mitigation: game-day trimestral de restore con Velero y reporte firmado.

## Review Triggers

- Lead time PR→prod p50 no baja a ≤ 2 h antes de M4 → revisamos pipeline y Argo sync waves.
- Aparece un segundo cluster prod en otra región o un cluster multi-tenant interno → reevaluamos service mesh (multi-cluster, mTLS cross-cluster) y multi-cluster GitOps.
- OpenCost unlabeled cost > 15% del total durante 2 meses consecutivos → sprint de "label hygiene" o rediseño de la política de labels.
- Equipo de plataforma pasa a ≥ 5 FTE o la organización pasa a ≥ 100 ingenieros → evaluamos Backstage + Crossplane como golden path.
- Un incidente de seguridad L7 que un mesh habría prevenido (ej. secret filtrado en logs L7 inter-service) → reabrimos la decisión de mesh con datos concretos.
