# Ejercicio arquitectónico — Migración "AcmeHealth" de AWS a Azure

**Tiempo sugerido:** 25–30 min dentro del examen.

**Entregable:** un documento `architectural/decisiones.md` que escribirá el candidato con: diagrama, tabla de decisiones con trade-offs, un ADR y el mapeo AWS → Azure. **No se evalúa contra Azure real** — es un ejercicio en papel.

---

## Contexto

**AcmeHealth** es una scale-up de telemedicina con 180 ingenieros. Actualmente opera en AWS con la siguiente topología:

- **Multi-cuenta** en AWS Organizations: `management`, `log-archive`, `security-tools`, `prod`, `stg`, `dev`, `sandbox`.
- **SCPs** en Organizations: `deny-leave-org`, `deny-disable-logging`, `deny-regions` (sólo `eu-west-1` y `eu-central-1` por GDPR), `deny-root-user`.
- **Compute**:
  - API pública (FastAPI, ~500 rps p99 120 ms) en **ECS Fargate** detrás de **ALB** + **CloudFront**.
  - Procesadores de colas de audio médico en **EKS** (necesitan GPU para transcripción + sidecar `envoy` custom con mTLS).
  - Lambdas pequeñas para webhooks de proveedores de laboratorio.
- **Datos**:
  - **RDS Postgres Multi-AZ** (datos clínicos — GDPR, cifrado KMS CMK, en VPC privada vía VPC endpoint).
  - **DynamoDB** global tables (sesiones de usuario, lectura <10 ms desde cualquier región).
  - **S3** (grabaciones de audio, lifecycle a Glacier a los 90 días, SSE-KMS CMK, Block Public Access).
- **Identidad**: **IAM Identity Center** (SSO) + **IRSA** para workloads en EKS + **task roles** en ECS.
- **Pipeline**: GitHub Actions → OIDC → IAM role en cada cuenta (sub pinneado a `environment:prod`), build en runners self-hosted, push a **ECR** con escaneo + **cosign keyless** + verificación en admisión con `policy-controller`.
- **Observabilidad**: **ADOT** (OpenTelemetry Collector) → **CloudWatch** + **Managed Prometheus** + **Managed Grafana**. CloudTrail multi-cuenta centralizado en `log-archive`.
- **Factura mensual AWS actual**: ~$48,000. Las palancas conocidas: NAT Gateway en 3 AZ ($900/mes), CloudWatch Logs ingestion ($6,500/mes), data egress inter-AZ EKS ($2,100/mes).

**El board aprueba una migración a Azure** por tres razones:

1. Un cliente estratégico (una aseguradora alemana) exige **soberanía de datos en Alemania** y requiere evidencia de guardrails jerárquicos y audit trail unificado — su equipo de compliance lee Azure Policy mejor que SCPs.
2. **Microsoft Defender for Cloud** cubriría CSPM + CWPP + Defender for SQL + Defender for Containers en un solo producto, eliminando contratos con dos vendors terceros (Wiz, Sysdig) que hoy cuestan $18,000/mes combinados.
3. La aseguradora ya tiene un **Enterprise Agreement** con Microsoft y ofrece un descuento por consumo.

**Restricciones no negociables:**

- **GDPR + ISO 27001**: todos los datos clínicos y audios deben residir físicamente en Alemania (`germanywestcentral` o `germanynorth`).
- **Zero secrets managed by humans** en los pipelines (ninguna password, token o key en un secret store accesible por un humano — todo OIDC o Managed Identity).
- **SLA**: API pública 99.9 % uptime mensual, pérdida de datos clínicos aceptable = 0 (RPO = 0).
- **Blast radius**: un operador que borre un RG no puede derribar más que un ambiente de un workload.
- **Budget**: el objetivo es no superar los **$42,000/mes** en Azure (los $6k de ahorro vs AWS vienen de descontinuar Wiz/Sysdig + descuento EA).

**Restricciones de equipo:**

- Dos SREs con experiencia profunda en AWS/EKS, cero experiencia operativa en AKS.
- Un ingeniero senior platform con experiencia en Terraform (no en Bicep).
- El equipo de aplicación quiere mantener la misma imagen OCI, el mismo FastAPI, los mismos manifests de K8s "sabor vanilla" sin reescribir a Dapr.

---

## Tu tarea

Escribe `architectural/decisiones.md` con:

### 1. Diagrama de topología

ASCII art o mermaid. Debe mostrar:

- Jerarquía Management Group (CAF LZ) y cómo mapea las 7 cuentas AWS a Subscriptions.
- VNets Hub-Spoke (ubicando el hub) con Private Endpoints a los servicios PaaS.
- Compute (dónde vive cada uno de los tres workloads actuales).
- Observability pipeline.

### 2. Tabla de decisiones con trade-offs

| Capa | Decisión | Alternativa descartada | Trade-off / cuándo cambiaría |
|------|----------|------------------------|------------------------------|
| Compute API pública | ? | ? | ? |
| Compute procesadores GPU + sidecar | ? | ? | ? |
| Compute webhooks | ? | ? | ? |
| Postgres clínico | ? | ? | ? |
| Sesiones low-latency | ? | ? | ? |
| Audios | ? | ? | ? |
| Identidad workload | ? | ? | ? |
| OIDC CI/CD | ? | ? | ? |
| Red egress a PaaS | ? | ? | ? |
| Guardrails | ? | ? | ? |
| Observabilidad | ? | ? | ? |
| Secrets | ? | ? | ? |
| Container registry | ? | ? | ? |
| DevSecOps / scanning | ? | ? | ? |

Cada celda **justificada**. "Elegimos X porque es nativo" no cuenta.

### 3. ADR

Un ADR en formato:

```
# ADR-NNN: <título>
Fecha: 2026-10-NN
Estado: Propuesto

## Contexto
...

## Decisión
...

## Alternativas consideradas
- A: ...
- B: ...

## Consecuencias
Positivas:
- ...
Negativas / costos:
- ...
Condiciones para revisar esta decisión:
- ...
```

Elige una decisión genuinamente contenciosa. Algunas que serían buenos candidatos:

- Container Apps vs AKS para la API pública (dado que el equipo no tiene experiencia AKS).
- Cosmos DB (session consistency) vs Azure Cache for Redis Enterprise para sesiones low-latency.
- Front Door vs App Gateway + CDN para el ingress público (regionalidad de WAF, latencia global).
- Mantener Postgres Flexible Server vs migrar a Azure SQL Database (requiere reescritura).
- Microsoft Sentinel vs seguir con Managed Grafana + alerting propio.

**No** elijas una decisión trivial ("elegimos Terraform sobre Bicep").

### 4. Mapeo AWS → Azure

Tabla con la equivalencia por capa. **Incluye explícitamente** dónde la analogía **no** es 1:1 (p. ej. "no hay un SCP equivalente directo — se cubre con Azure Policy `deny` scopeada al MG").

### 5. Checklist de red flags que verificaste no cometer

Lista corta: los diez que considerabas más probables en este escenario, y una línea por cada uno diciendo cómo tu diseño los evita.

---

## Rúbrica abreviada (el detalle completo está en `EXAM.md` §4.3)

- **30 pts totales**, mínimo 15 pts para aprobar el ejercicio.
- 8 pts — Alineación con restricciones (soberanía DE, cero secrets humanos, budget, blast radius, SLA).
- 8 pts — Decisiones con trade-offs explícitos (no listas de features).
- 7 pts — ADR completo con alternativas y condiciones de revisión.
- 4 pts — Mapeo AWS → Azure incluyendo los casos no-1:1.
- 3 pts — Checklist de red flags verificado.

## Preguntas de seguimiento que puede hacer el instructor (live)

- "Si en 6 meses la aseguradora alemana se cae del contrato, ¿cuánto de tu diseño sobra o se vuelve caro?"
- "Describe el flujo exacto desde que un ingeniero mergea a `main` hasta que un pod corre en AKS con una imagen firmada y con token de Entra ID — ¿cuántos secrets ven humanos?"
- "Un operador escribe `az group delete --name rg-exam-prod --yes` sin querer. ¿Qué cae y qué no? ¿Cómo lo mitigaste?"
- "¿Por qué no elegiste Dapr aunque Container Apps lo integra? Articula el no-elegir."
- "El equipo quiere mantener Managed Grafana. ¿Qué pierdes si descartas Sentinel por mantenerlo?"
