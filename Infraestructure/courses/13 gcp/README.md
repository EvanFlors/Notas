# Curso: GCP (diferencial contra AWS)

Roadmap especializado #6. Framing explícito: **curso diferencial**, no una reimplementación completa. Asume que el estudiante ya cursó **AWS** y aprovecha ese modelo mental. El objetivo no es cubrir todos los servicios de GCP sino **transferir** competencias cloud y marcar las diferencias conceptuales y operativas que realmente importan.

## 1. Introducción

### Qué es

**Google Cloud Platform (GCP)** es la plataforma pública de Google para infraestructura, datos, ML y servicios administrados. Su jerarquía nativa es **Organization → Folders → Projects → Resources**, y la unidad de aislamiento es el **project** (equivalente funcional de la "cuenta" AWS, pero más barato de crear y descartar). La identidad y autorización se gestiona con **IAM** sobre un modelo *role-based* (predefinidos, básicos y custom), con **principals** federables vía **Workload Identity Federation**.

### Diferencias de modelo contra AWS (síntesis para transferencia)

| Dimensión | AWS | GCP |
|-----------|-----|-----|
| Unidad de aislamiento | Account | Project (más barato de crear/eliminar) |
| Jerarquía | Organization → OUs → Accounts | Organization → Folders → Projects |
| Guardrails | SCPs (deny-list) | **Org Policies** (constraints, no listas de acciones) |
| IAM primitiva | Policy JSON por principal/recurso | **Bindings role→member** por recurso |
| Policies | Identity-based + Resource-based + SCP + Boundary + Session | IAM allow policies + **IAM deny policies** + Org policies, heredadas por la jerarquía |
| Secretos de corta vida | STS AssumeRole | **Workload Identity Federation** + Service Account impersonation |
| Red | VPC por región | **VPC global** (subnets regionales dentro de una VPC global) |
| Default egress | NAT Gateway por AZ (caro) | **Cloud NAT** regional (más barato de operar) |
| Compute | EC2 | **Compute Engine** |
| Managed K8s | EKS | **GKE** (más integrado, Autopilot opcional) |
| Contenedores "sin K8s" | ECS / Fargate / App Runner | **Cloud Run** (serverless containers, escalado 0→N, el más limpio) |
| Serverless | Lambda | **Cloud Functions (gen 2 = Cloud Run bajo el capó)** |
| Object storage | S3 | **Cloud Storage** (GCS) |
| SQL administrado | RDS/Aurora | **Cloud SQL** / **AlloyDB** (Postgres) |
| NoSQL managed | DynamoDB | **Firestore** / **Bigtable** / **Spanner** |
| Secretos | Secrets Manager | **Secret Manager** |
| Claves | KMS | **Cloud KMS** |
| Observabilidad | CloudWatch + X-Ray + CloudTrail | **Cloud Operations** (ex-Stackdriver): Logging, Monitoring, Trace, Profiler, **Audit Logs** |
| Edge/CDN | CloudFront | **Cloud CDN** sobre Cloud Load Balancing (global anycast) |
| DNS | Route 53 | **Cloud DNS** |
| TLS gestionado | ACM | **Google-managed certs** (en LBs) |
| Multi-cuenta gobernanza | Organizations + Control Tower | **Resource Manager** + Org Policies + **Assured Workloads** |
| SSO | IAM Identity Center | **Cloud Identity** / Workspace (Google Groups usados en bindings) |
| Billing | Account-based | **Billing Accounts** separadas, se enlazan a projects (facturación cross-project nativa) |

Puntos "sorprendentes" para alguien formado en AWS:
- La **VPC es global**, no regional. Esto simplifica muchas topologías.
- **Projects son baratos**: patrón común "un project = un workload × un ambiente".
- **IAM bindings** van en el recurso, no en el principal. Un rol se otorga asignándolo a un (recurso, principal); el principal "no tiene" una lista central de permisos.
- **Service Accounts** son principals de pleno derecho (no "roles"); el flujo moderno es *impersonation* vía Workload Identity Federation, análogo a OIDC-to-AWS.
- **Cloud Run** es un sweet spot que AWS no tiene exactamente igual: contenedores HTTP serverless con escalado 0→N por request, con mínimo IAM/VPC fricción.
- **GKE Autopilot** oculta node management casi por completo (más que EKS Fargate en integración).
- **Google-managed certs** se emiten automáticamente para dominios validados.

### Casos de uso

- Workloads que ya viven en el stack de datos/ML de Google (BigQuery, Vertex, Pub/Sub).
- Servicios HTTP ligeros donde Cloud Run elimina mucha operación.
- GKE para equipos que quieren Kubernetes administrado "con menos pegamento".
- Multi-cloud con GCP como secundaria por red global y precios de egress.

### Alternativas

Las mismas del curso AWS; aquí interesa el **mapping**. Los conceptos no cambian: cambia la UX, la ergonomía y los defaults.

### Ventajas / limitaciones

**Ventajas**: red global y load balancing anycast, Cloud Run, GKE Autopilot, Workload Identity Federation ergonómica, UX de consola más consistente.

**Limitaciones / riesgos**:
- Catálogo más estrecho que AWS en algunas verticales.
- Menos regiones (relevante para compliance).
- Ecosistema de terceros más chico (menos módulos TF comunitarios y menos talento disponible por región).
- Cambios de UX y renombres (Stackdriver → Operations, g.co/*). Los nombres cambian más que en AWS.
- Facturación es por project y debe gobernarse igual que en AWS (budgets + alertas).

### Relación con el programa

- Es alternativa a AWS en el capstone — no necesariamente lo re-despliegas, pero debes **poder razonarlo**.
- Comparte conceptualmente **OIDC federation** con Actions, **IaC con Terraform**, **K8s** y **observabilidad** con el resto del programa.
- Útil para comparaciones conceptuales en entrevistas de arquitectura.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | **Curso AWS completo o paralelamente curso GCP sin tabla de equivalencias — se asume que ya existe el modelo mental cloud.** Curso **terraform**. |
| Recomendados | Curso **docker**, curso **github-actions**, curso **kubernetes** (para GKE y para las comparaciones con EKS). |
| Complementarios | — |

## 3. Organización (4 niveles)

El curso tiene **10 módulos** (más corto que AWS *por diseño*: solo cubre lo que es materialmente distinto o estratégicamente relevante).

- **Nivel 1 — Fundamentos diferenciales** (3): modelo global y billing/projects, IAM GCP (bindings, deny policies, Service Accounts), VPC global y networking.
- **Nivel 2 — Compute, datos, secretos** (3): compute (GCE, Cloud Run, Cloud Functions gen 2), datos administrados (Cloud SQL, Firestore, Bigtable, Spanner — mapping), KMS + Secret Manager.
- **Nivel 3 — Avanzado** (2): **GKE** y Autopilot, Observability (Cloud Logging/Monitoring/Trace + Audit Logs).
- **Nivel 4 — Producción empresarial** (2): multi-project org (folders, org policies, Cloud Identity), DevSecOps + platform (WIF, Binary Authorization, Artifact Registry + SBOM/firmas, Assured Workloads, FinOps).

## 4. Entregables del curso

- Project GCP configurado con budget + MFA en identidades.
- VPC global con subnets regionales y Cloud NAT; comparación de costo vs equivalente AWS.
- App del capstone desplegada en **Cloud Run** y, por separado, en **GKE Autopilot**.
- Pipeline GHA → GCP vía **Workload Identity Federation** (sin keys JSON).
- **Binary Authorization** aplicando política de firmas de imagen en GKE.
- ADR de elección cloud (AWS vs GCP) para un workload dado, con criterios explícitos.

## 5. Evaluación

- **Conceptual**: traducir conceptos AWS↔GCP sin tabla; explicar el modelo de evaluación IAM GCP (allow + deny + org policies por jerarquía); diferencia entre Cloud Run y Lambda/Fargate; cuándo Cloud Run vs GKE.
- **Operativa**: desplegar el mismo workload en Cloud Run y GKE; federar OIDC desde GHA a GCP; aplicar Binary Authorization.
- **Arquitectónica**: ADR GCP vs AWS; estrategia multi-project; política mínima de org con Org Policies.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial: `cloud.google.com/docs`.
- Google Cloud Architecture Framework (equivalente a Well-Architected).
- Terraform `hashicorp/google` y `google-beta` providers.
- Guías oficiales de Workload Identity Federation (AWS, GitHub, GitLab, OIDC genérico).
- Documentación de Binary Authorization y Artifact Registry.
- GKE release notes (cambios frecuentes de defaults, versiones y Autopilot).
