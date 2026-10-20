# Ejercicio arquitectónico — Plataforma Kubernetes para "Fintoro"

> Dimensión: arquitectónica. Peso: 30 pts. Entregable: **un ADR** siguiendo el formato Michael Nygard.
> Tiempo recomendado: 30–40 min dentro del total del examen.

## Contexto

**Fintoro** es una fintech regional en crecimiento. Hoy corre 8 microservicios en EC2 con Ansible, y quiere migrar a Kubernetes para habilitar iteración más rápida y aislar equipos. Datos relevantes:

- **Equipo**: 3 SRE/plataforma, 24 devs en 4 squads de producto, 1 compliance officer.
- **Workloads**: 8 microservicios HTTP (Python/Go, stateless), 1 Postgres (ya en RDS, se queda), 1 Redis (en ElastiCache, se queda), 2 workers Kafka consumers (Kafka externo, managed).
- **Tráfico**: pico 500 req/s, promedio 80 req/s. Picos previsibles (payroll fin de mes).
- **Regulatorio**: PCI-DSS parcial (no almacenan PAN, pero sí tokens). Auditoría anual. Necesitan **audit log** inmutable y **mTLS** entre servicios que tocan datos tokenizados (2 de los 8).
- **Cloud**: AWS, multi-AZ (3 AZ) en una región. Latencia a usuarios aceptable con una sola región.
- **Presupuesto plataforma**: USD 6k/mes para infra K8s (fuera de RDS/ElastiCache/Kafka).
- **SLO**: 99.9% para los microservicios críticos, RPO 1h, RTO 4h para el cluster (los datos están en servicios managed).
- **Timeline**: 6 meses para migración completa.
- **Preferencia declarada**: equipo chico, prefieren "boring", OSS cuando posible, evitar lock-in extremo pero sin maximalismo multi-cloud.

## Restricciones duras

1. **Managed control plane** (el equipo de 3 SRE no puede operar etcd self-hosted sosteniblemente).
2. **GitOps** obligatorio: nada se aplica a mano en el cluster.
3. **Policy-as-code** obligatorio: bloqueo en admission de `privileged`, `hostPath`, imágenes sin firmar y pods sin `runAsNonRoot`.
4. **Backups demostrables** del estado del cluster (CRs y configuración; los datos están fuera).
5. **Observabilidad OSS** (ya tienen Grafana Cloud contratado, pero el stack dentro del cluster debe ser portable).
6. **Sin service mesh "porque sí"**: debes justificar explícitamente si lo introduces o no.
7. Imágenes firmadas con **cosign** y verificadas en admission.

## Decisiones que tu ADR debe cubrir

Para **cada** una: decisión + alternativas consideradas + por qué descartaste las otras + consecuencias (buenas y malas) + señal/condición que te haría reconsiderar.

1. **Distribución del cluster**: EKS vs un self-hosted con kOps vs k3s en EC2. (La restricción 1 fuerza una respuesta razonada, no automática.)
2. **Multi-tenancy entre squads**: namespace-per-squad con RBAC + ResourceQuota + LimitRange, vcluster, o clusters separados por squad. Justifica con el tamaño del equipo y el presupuesto.
3. **Policy engine**: Pod Security Admission `restricted` suficiente, PSA + Kyverno, PSA + Gatekeeper, o PSA + ValidatingAdmissionPolicy (CEL). Debes justificar la elección sabiendo que necesitas verificación de firmas y labels obligatorios.
4. **Ingress / norte-sur**: ingress-nginx, AWS Load Balancer Controller + Gateway API, o Istio Gateway. Considera que solo 2 servicios necesitan mTLS.
5. **mTLS para los 2 servicios con tokens**: Linkerd, Istio ambient, Cilium Cluster Mesh, o mTLS a nivel app con cert-manager + SPIFFE. ¿Introduces mesh o no?
6. **Autoscaling**: HPA + Cluster Autoscaler, HPA + Karpenter, HPA + KEDA (porque hay Kafka consumers). Justifica.
7. **GitOps**: Argo CD vs Flux. Modelo de repos (mono vs multi) y promoción entre `dev/stg/prod`.
8. **DR del cluster**: Velero + S3 + snapshot CSI, o reconstrucción pura desde Git + Terraform. RPO/RTO objetivo y cómo los cumples.
9. **Hardening mínimo "día 1"**: PSA `restricted` namespace-wide, `audit-log` policy, encryption at rest etcd (en EKS: habilitar KMS), network default-deny por namespace. Decide qué entra en "día 1" y qué puede esperar al mes 2.
10. **Lo que NO vas a hacer** (y por qué). Al menos 3 decisiones explícitas de descarte (ej. "no voy a introducir mesh en los primeros 3 meses porque...").

## Formato del ADR (obligatorio)

```markdown
# ADR-001 — Arquitectura de plataforma Kubernetes para Fintoro

## Estado
Propuesto | Aceptado | Reemplazado por ...

## Contexto
<Resumen del problema, restricciones y actores. No copies este scenario; sintetízalo
en tus palabras y añade cualquier supuesto que necesites hacer explícito.>

## Decisión
<Decisión principal + sub-decisiones numeradas 1..10 arriba, cada una en 3–6 líneas.>

## Alternativas consideradas
<Por cada sub-decisión, qué alternativas evaluaste y por qué las descartaste.>

## Consecuencias
### Positivas
- ...
### Negativas / costos aceptados
- ...
### Riesgos y mitigaciones
| Riesgo | Probabilidad | Impacto | Mitigación |

## Plan de reversión
<Cómo deshaces las decisiones críticas si fallan en los primeros 3 meses.>

## Métricas / señales que me harían reconsiderar
- ...

## Lo que NO voy a hacer (y por qué)
- ...
```

## Criterios de evaluación

Ver sección 5.3 de `EXAM.md`. Puntaje máximo 30. Se penaliza:

- Elegir service mesh sin justificar contra la restricción 6.
- Omitir el apartado "qué NO vas a hacer".
- Decisiones sin trade-off (solo pros).
- Diseños que violan alguna restricción dura sin reconocerlo.

Preguntas de seguimiento del instructor (si evalúa en vivo) están en `EXAM.md` §6.4.
