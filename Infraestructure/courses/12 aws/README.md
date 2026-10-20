# Curso: AWS (cloud principal)

Roadmap especializado #5. Cloud principal del programa. Framing explícito: formar un **ingeniero DevOps/Platform**, no un *Solutions Architect* generalista — el curso prioriza IAM, redes, contenedores, secretos, observabilidad y gobernanza multi-cuenta.

## 1. Introducción

### Qué es

**AWS** (Amazon Web Services) es un proveedor de infraestructura y servicios cloud organizado en **regiones** (áreas geográficas independientes) subdivididas en **zonas de disponibilidad** (AZs — datacenters aislados pero cercanos). Expone +200 servicios bajo APIs REST uniformes autenticadas mediante **SigV4** y gobernadas por un sistema de identidad y autorización central: **IAM**.

Modelo mental mínimo:
- **Cuenta** = unidad de aislamiento, facturación y confianza.
- **Región** = unidad de localización y failure domain geográfico.
- **AZ** = unidad de failure domain dentro de una región.
- **VPC** = red privada virtual regional.
- **IAM** = quién puede hacer qué sobre qué, bajo qué condiciones.

### Historia (síntesis)

- **2006** — Lanzamiento de S3 y EC2.
- **2011** — IAM.
- **2014** — Lambda (serverless mainstream).
- **2015** — ECS; posteriormente ECR.
- **2017** — Fargate (ECS/EKS serverless).
- **2018** — EKS (Kubernetes administrado).
- **2019** — Transit Gateway.
- **2021** — IAM Identity Center (sucesor de AWS SSO).
- **2022+** — Graviton (ARM), OIDC a GitHub Actions, EKS Pod Identity, cambios continuos en Config/Security Hub.

### Problemas que resuelve

- Infraestructura on-demand sin capex.
- Multi-región / multi-AZ para alta disponibilidad.
- Elasticidad (autoscaling) y pago por uso.
- Catálogo de servicios administrados (DB, colas, DNS, CDN, K8s, LB, etc.) para evitar operar primitivas.
- Modelo de seguridad consistente (IAM) y auditoría (CloudTrail) a través de todos los servicios.

### Casos de uso

- Hosting de aplicaciones web, APIs, y pipelines CI/CD backend.
- Clusters Kubernetes administrados (EKS) y containers (ECS/Fargate).
- Almacenamiento y análisis de datos.
- Edge delivery (CloudFront) y DNS global (Route 53).
- Entornos multi-cuenta con gobernanza central (Organizations, Control Tower).

### Arquitectura general

```
┌─────────────────────────────────────────────────────┐
│ AWS Organization (root → OUs → accounts)            │
│  - SCPs (guardrails)                                │
│  - IAM Identity Center (SSO)                        │
│  - Billing consolidation                            │
└─────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────┐
│ Account                                             │
│   IAM (users, roles, policies, STS)                 │
│   per Region:                                       │
│     VPC (subnets, RT, IGW/NAT, SG, NACL, endpoints) │
│     Compute (EC2, ECS, EKS, Lambda)                 │
│     Data (S3, RDS, DynamoDB, EBS, EFS)              │
│     Edge (ALB/NLB, Route 53, CloudFront, ACM)       │
│     Observability (CloudWatch, X-Ray, CloudTrail)   │
│     Security (KMS, Secrets Manager, GuardDuty,      │
│               Inspector, Config, Security Hub)      │
└─────────────────────────────────────────────────────┘
```

El API de todo es **IAM-gated**: cada request está firmada (SigV4) con credenciales de un *principal* (user, role) y evaluada contra políticas identity-based + resource-based + SCPs + permission boundaries + session policies, con lógica explícita de *Deny gana a Allow*.

### Alternativas

- **GCP** y **Azure** — cursos hermanos del programa (siguiente roadmap: GCP como diferencial).
- **Oracle Cloud, IBM Cloud, Alibaba** — alcance regional/vertical.
- **Hetzner, OVH, DigitalOcean, Linode** — opciones low-cost para workloads simples o educativos.
- **Kubernetes "on-prem"** o bare-metal cuando el objetivo es evitar lock-in.

### Ventajas / limitaciones

**Ventajas**: amplitud de catálogo, madurez de IAM/Organizations, ecosistema de terceros, documentación extensiva, mercado laboral grande.

**Limitaciones / riesgos**:
- **Costos sorpresa** (NAT Gateway, egress, DynamoDB mal dimensionada) → control de FinOps obligatorio.
- Superficie de **IAM** compleja: la mayoría de incidentes de seguridad en AWS son errores de IAM, no vulnerabilidades.
- Lock-in moderado (servicios administrados específicos: DynamoDB, SQS, EventBridge, Cognito).
- UX de consola inconsistente entre servicios.
- Cuentas nuevas tienen límites y defaults inseguros; necesitan *landing zone* explícita.

### Relación con el programa

- Blanco principal de **Terraform** (cursos previos) para IaC.
- Target de **GitHub Actions** vía **OIDC** sin credenciales de larga vida.
- Host del cluster **Kubernetes** (EKS) del capstone.
- Fuente de métricas, logs y traces integrables con **Prometheus/Grafana/OTel**.
- Donde se aterrizan controles de **DevSecOps** (KMS, Secrets Manager, Inspector, firma de imágenes, Config, Security Hub).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | T-3 Networking (OSI/TCP, IP, DNS, HTTP, TLS). T-7.1 IaaS/PaaS/SaaS. Curso **git-and-github** completo. |
| Recomendados | Curso **terraform** ≥ Nivel 2 (todo el curso usa IaC desde el principio). Curso **docker**. |
| Complementarios | Curso **github-actions** para los módulos de CI/CD (OIDC) y DevSecOps. |

## 3. Organización (4 niveles)

El curso tiene **17 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5): modelo global y billing, IAM fundamentals, VPC básico, EC2, S3.
- **Nivel 2 — Intermedio** (5): IAM avanzado (SCPs, boundaries, cross-account), networking avanzado (ALB/NLB/Route 53/TGW/PrivateLink), datos administrados (RDS/Aurora/DynamoDB), KMS + Secrets Manager + Parameter Store, containers (ECR + ECS/Fargate + App Runner).
- **Nivel 3 — Avanzado** (4): EKS en profundidad (control plane, IRSA/Pod Identity, add-ons), observabilidad (CloudWatch + X-Ray + CloudTrail), edge/DNS/CDN (Route 53 avanzado + CloudFront + ACM), serverless (Lambda + API Gateway + EventBridge + SQS/SNS) *lo justo para integración*.
- **Nivel 4 — Producción empresarial** (3): multi-account org (Organizations, SCPs, Control Tower, Identity Center), DevSecOps en AWS (OIDC desde GHA, IRSA, rotación de secretos, Inspector/ECR scanning, firma de artefactos), platform / FinOps / Well-Architected (landing zones, Config/GuardDuty/Security Hub, Backup/DR, cost mgmt).

## 4. Entregables del curso

- Cuenta AWS con **MFA** y usuario administrativo con mínimo privilegio.
- VPC multi-AZ reproducible por Terraform (subnets públicas/privadas, NAT, endpoints VPC).
- Aplicación en ECS/Fargate detrás de ALB con TLS (ACM) y Route 53.
- Mismo workload portado a **EKS** usando **IRSA** o **Pod Identity**.
- Pipeline GHA → AWS vía OIDC (sin keys) con despliegue a dev y staging.
- Baseline multi-cuenta con Organizations + SCPs mínimos + IAM Identity Center.
- Dashboard de costos y presupuesto con alertas; ADR Well-Architected para el workload.

## 5. Evaluación

- **Conceptual**: explicar el modelo de evaluación de IAM (Allow/Deny, resource-based, SCPs, permission boundaries, session policies); diferenciar SG vs NACL; cuándo IRSA vs Pod Identity; cuándo Secrets Manager vs Parameter Store; qué garantiza una AZ.
- **Operativa**: diseñar y provisionar una VPC con endpoints; desplegar un workload containerizado en ECS y EKS; configurar OIDC GHA→AWS; recuperar un bucket S3 con versioning; investigar un gasto inesperado.
- **Arquitectónica**: diseñar una landing zone multi-cuenta; política de permisos para una org; criterios de elección ECS vs EKS vs Lambda; estrategia multi-región para un workload crítico.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial AWS (`docs.aws.amazon.com`) y Well-Architected Framework.
- Pricing calculator (`calculator.aws`) y Billing & Cost Management.
- AWS Security Reference Architecture.
- Service Authorization Reference (actions/condition keys por servicio).
- `terraform-aws-modules` (`github.com/terraform-aws-modules`) y `cloudposse/*`.
- GuardDuty, Inspector, Config, Security Hub guides.
- AWS re:Invent talks relevantes (filtrar por año reciente).

**Nota de costos**: este curso usa recursos reales. Cada laboratorio con costo potencial lleva estimación y procedimiento de limpieza. Se recomienda cuenta dedicada, presupuesto con alertas y uso de Free Tier siempre que sea posible.
