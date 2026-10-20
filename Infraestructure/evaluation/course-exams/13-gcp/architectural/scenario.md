# Ejercicio arquitectónico — Diseño de landing zone GCP para **Acme Payments**

> **Dimensión:** arquitectónica (30% del examen).
> **Tiempo sugerido:** 30–40 min.
> **Entregable:** `architectural/answer.md` (un único archivo Markdown) con las 4 secciones solicitadas al final.
> **Modalidad:** documental. **No** se requiere Terraform ejecutable; sí snippets HCL ilustrativos cuando aclaren decisiones.

---

## Contexto de negocio

**Acme Payments** es una fintech latinoamericana (~80 ingenieros) que migra de AWS a GCP por:

- Un contrato con un cliente enterprise que exige **Binary Authorization** y **CMEK** sobre todo dato PII.
- La necesidad de un backend transaccional **multi-región activo-activo** con consistencia fuerte (candidato Spanner).
- Reducir el pegamento operativo del equipo de plataforma (3 personas) frente a su stack actual EKS + IRSA + Kyverno + cosign.

### Portafolio de workloads a soportar

| ID | Workload | Perfil | Nota |
|----|----------|--------|------|
| W1 | `payments-api` | HTTP stateless, p95 150 ms, picos 20× | público, PII |
| W2 | `ledger` | OLTP crítico, multi-región, strong consistency | PII, SOX-like |
| W3 | `risk-batch` | job batch nocturno, 60–120 min, GPU opcional | datos agregados |
| W4 | `analytics` | queries ad-hoc sobre histórico | sin PII |
| W5 | `admin-portal` | app interna, baja carga, acceso solo empleados | SSO |

### Equipos y entornos

- Equipos: `payments`, `risk`, `data`, `platform`, `security`.
- Entornos: `prod`, `staging`, `dev`, `sandbox` (último para experimentación personal).
- Fuente de identidad: Google Workspace ya existente en `acmepayments.example`.
- Fuente de código: GitHub Enterprise Cloud (`my-github-org`, placeholder).
- Billing: una sola Billing Account corporativa.

### Restricciones duras

1. **Prohibido** crear service account keys estáticas. Nunca.
2. Todo tráfico de producción con **TLS gestionado** y una sola IP pública por servicio (anycast).
3. VMs y pods en producción **sin IP externa**.
4. Pipeline de CI/CD solo desde **GitHub Actions** del repo oficial de cada workload, rama `main`.
5. Admisión en Kubernetes **solo** imágenes firmadas por el atestador del entorno (`cosign-<env>-attestor`).
6. Audit Logs retenidos **≥ 400 días** sin inflar el costo de Cloud Logging.
7. Presupuesto plataforma: ~$8 000/mes en el primer trimestre.

---

## Lo que debes entregar en `architectural/answer.md`

### Sección 1 — Diseño de la landing zone (Org/Folders/Projects/VPC)

- Diagrama `mermaid` con la jerarquía Org → Folders → Projects, señalando qué project aloja qué workload y cuál es la **host project** de la Shared VPC.
- Tabla de projects con: id placeholder, folder padre, propósito, APIs mínimas habilitadas.
- Decisión y justificación sobre: Shared VPC vs VPC por project, cuántas VPCs globales, segmentación por subnet regional, uso o no de Network Connectivity Center.
- Lista de **org policies** aplicadas y en qué nivel de la jerarquía (al menos: `iam.disableServiceAccountKeyCreation`, `compute.vmExternalIpAccess`, `storage.publicAccessPrevention`, `iam.allowedPolicyMemberDomains`, `compute.restrictVpcPeering`).

### Sección 2 — Identidad, acceso y supply chain

- Modelo de bindings: qué grupos (Google Groups) existen y qué roles reciben en qué nivel. Ningún binding a usuario individual en `folders/prod`.
- Diseño de **Workload Identity Federation** para GitHub Actions: pools, providers, attribute mapping, attribute condition. Explica qué previene cada condición.
- Diseño de **Binary Authorization**: un atestador por entorno; policy por cluster; qué pasa si un pod es admitido en `dev` pero su imagen no está firmada para `prod` (promotion gating).
- Al menos **una IAM Deny Policy** perimetral (p. ej. denegar `iam.serviceAccountKeys.create` incluso a owners de project, excepto a un grupo `break-glass@`).

### Sección 3 — Compute, datos y observabilidad por workload

Para cada W1..W5, decide compute + datastore + observabilidad y defiende en 2–4 líneas. Debe aparecer explícitamente:

- Cloud Run con min-instances y concurrency para W1.
- Spanner (regional o multi-region) **o** AlloyDB con una razón para W2. Si eliges AlloyDB, justifica por qué no Spanner (costo y lock-in son respuestas aceptables si están defendidas).
- Decisión GKE Autopilot vs Cloud Run jobs vs Batch para W3.
- BigQuery para W4 con partitioning + authorized views.
- Cloud Run + IAP para W5 (SSO corporativo, sin IP pública directa).
- SLO + alerta mínima por workload y qué va a Cloud Ops vs qué se exporta a Grafana/BigQuery.

### Sección 4 — ADR y plan de migración desde AWS

Un **ADR** corto (plantilla MADR o similar) sobre **la** decisión más controvertida de tu diseño (típicamente: *Spanner vs AlloyDB para W2*, o *Shared VPC vs VPC-per-project*, o *GKE Autopilot vs Cloud Run para la mayoría del portafolio*). Debe incluir:

- Contexto, decisión, alternativas descartadas con razón, **consecuencias** (incluyendo las negativas), y **cómo revertir**.

Plus: **migration plan** por fases (bootstrap org → red → workload no crítico → crítico), con checkpoints de rollback y qué métrica dispararía un abort.

---

## Rúbrica

Ver `EXAM.md` §5.3.

## Guía de corrección (instructor-only)

### Respuesta de referencia (sketch)

- **Folders:** `bootstrap`, `shared`, `prod`, `nonprod` (con `dev` y `staging` como projects dentro), `sandbox`.
- **Projects:** `my-org-bootstrap-000`, `my-org-shared-vpc-001`, `my-org-logging-002`, `my-org-billing-003`, `my-org-payments-prod-100`, `my-org-ledger-prod-101`, `my-org-risk-prod-102`, `my-org-analytics-prod-103`, `my-org-admin-prod-104`, equivalentes `-dev-2xx`/`-staging-3xx`.
- **Red:** 1 Shared VPC global en `shared-vpc-001`, con subnets por región y por entorno; service projects attachment por workload. Private Google Access on; Cloud NAT regional para egress.
- **Org policies:** las 5 listadas aplicadas a nivel Org (no a nivel folder, para evitar drift). `allowedPolicyMemberDomains` restringe a `acmepayments.example` + dominio del cliente enterprise si aplica.
- **IAM:** grupos `gcp-payments-admins@`, `gcp-ledger-admins@`, `gcp-platform-admins@`, `gcp-security-auditors@` (viewer global), `gcp-break-glass@` (acceso rotatorio con MFA + aprobación JIT); deny policy sobre `iam.serviceAccountKeys.create` excepto `gcp-break-glass@`.
- **WIF:** 1 pool `github` en `shared`, 1 provider `github-oidc`; attribute condition por workload (`assertion.repository == "my-github-org/<repo>" && assertion.ref == "refs/heads/main"`); binding `workloadIdentityUser` a la deploy-SA del project destino usando `principalSet://.../attribute.repository/<repo>`.
- **Binauthz:** atestadores `cosign-dev-attestor`, `cosign-staging-attestor`, `cosign-prod-attestor`; policy per-cluster. Promoción: la firma de `prod` solo la emite un job que requiere aprobación manual en GitHub Environments.
- **W1 payments-api:** Cloud Run, min-instances=2, concurrency=40, Cloud SQL Postgres (HA regional). No Spanner (no multi-region write).
- **W2 ledger:** Spanner multi-region (p. ej. `nam-eur-asia1` solo si el cliente lo pide — típicamente `nam3` regional). Trade-off: costo base ~$650/mes para 1 node; defensa en el ADR.
- **W3 risk-batch:** Cloud Run jobs si cabe en 60 min sin GPU; GKE Autopilot con node pool GPU on-demand si no. Batch solo si volumen crece.
- **W4 analytics:** BigQuery con partitioning por fecha, clustering por `customer_id`, authorized views para equipos no-data; billing export al mismo project.
- **W5 admin-portal:** Cloud Run detrás de IAP + Google Workspace SSO. Sin IP pública directa.
- **ADR típico:** "Spanner `nam3` vs AlloyDB regional para `ledger`". Elegir Spanner **solo** si el requisito multi-region write es duro; si no, AlloyDB (10× más barato, SQL compatible, HA regional). Reversión: AlloyDB → Spanner implica rewrite de queries con interleaving; Spanner → AlloyDB implica dump/restore y pérdida de multi-region.
- **Migration plan:** (1) bootstrap org + billing export + logging project, (2) Shared VPC + Cloud NAT + managed cert, (3) W4 (sin PII, bajo riesgo), (4) W1 con shadow traffic desde ALB AWS, (5) W5, (6) W3, (7) W2 (con doble escritura + reconciliation ventana corta). Rollback checkpoint: tasa de error > 1% o latencia p95 > 2× baseline → `gcloud run services update-traffic --to-revisions=prev=100`.

### Errores comunes

- Un solo project "`acme-prod`" para todo (invalida sección 1).
- VPCs por project sin Shared VPC (penalización alta: operacionalmente insostenible con 15+ projects).
- `roles/editor` a grupos de desarrolladores "porque es más fácil".
- WIF global sin condition de `repository` ("cualquier Action del org puede desplegar").
- Spanner elegido "porque es cool" sin discutir costo mínimo (~$650/mes/nodo).
- Audit retention por 400 días en Cloud Logging directamente (caro) en vez de sink a BigQuery.
- ADR que lista alternativas pero no descarta ninguna con razón ("ambas son válidas, elegimos esta").

### Red flags (ver `competency-matrix.yaml`)

Especial atención en este ejercicio:

- Diagrama que muestra SA keys en el pipeline o en los Secrets de GitHub.
- `evaluationMode: ALWAYS_ALLOW` para producción en Binauthz.
- Bindings IAM a users (no groups) en folders de prod.
- Ausencia de org policies defensivas (no listar ninguna = invalida sección 1 completa).
- Project IDs reales o dominios reales.

### Preguntas de seguimiento (evaluación live)

- *"Elegiste Spanner. Si el cliente cancela el contrato en 6 meses, ¿cómo sale del lock-in sin reescribir el servicio?"*
- *"¿Por qué `allowedPolicyMemberDomains` y no simplemente auditar bindings post-hoc?"*
- *"¿Qué hace tu diseño si GitHub tiene un incidente de 4 h en el OIDC endpoint durante un deploy?"*
- *"Tu Shared VPC tiene un bug de ruteo. ¿Cuál es tu blast radius y cómo lo contienes?"*
- *"Me falta `security-command-center` en tu diseño. ¿Por qué lo dejaste fuera, o por qué debería estar?"*
