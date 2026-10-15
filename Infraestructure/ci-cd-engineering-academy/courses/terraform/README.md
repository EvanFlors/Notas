# Curso: Terraform

Roadmap especializado #4. Infrastructure as Code declarativa, principal herramienta de aprovisionamiento del programa. OpenTofu se trata como fork compatible en el Nivel 4.

## 1. Introducción

### Qué es

**Terraform** es una herramienta de **Infrastructure as Code (IaC)** declarativa, multi-proveedor y basada en estado. El usuario describe el *estado deseado* de la infraestructura en archivos **HCL** (HashiCorp Configuration Language); Terraform compara ese estado deseado con el **state file** (su registro del estado real conocido), consulta a los **providers** (plugins que hablan con APIs cloud/SaaS), construye un **grafo de dependencias**, calcula un **plan** (diff de operaciones) y lo ejecuta en **apply**.

Es importante distinguir cuatro cosas:

- **HCL** — el lenguaje (declarativo, con expresiones y funciones).
- **Terraform core** — binario que lee HCL, mantiene el state, calcula el grafo y orquesta a los providers.
- **Providers** — plugins versionados (AWS, Google, Azure, Kubernetes, GitHub, Datadog…). Son los que hacen las llamadas reales a cada API.
- **State** — representación JSON del estado real conocido; es la fuente de verdad operacional de Terraform.

### Historia (síntesis)

- **2014** — HashiCorp libera Terraform 0.1 como herramienta multi-cloud declarativa.
- **2017–2019** — Explosión del ecosistema de providers y módulos (Registry público).
- **2021** — Terraform 1.0: compromiso de estabilidad del lenguaje.
- **2022** — Backend HTTP para GitLab/GitHub como alternativa a S3.
- **2023** — HashiCorp cambia la licencia a **BUSL** (Business Source License). La Linux Foundation adopta el fork **OpenTofu** (apache 2.0), continuación comunitaria con el mismo lenguaje y compatibilidad de providers y state.
- **2024+** — Convergencia funcional entre ambos; divergencias puntuales (p. ej. `removed` blocks, state encryption nativa, provider-defined functions).

### Problemas que resuelve

- **Reproducibilidad** del aprovisionamiento (prod ≡ staging ≡ dev salvo variables).
- **Code review** sobre cambios de infraestructura.
- **Diff explícito** (plan) antes de aplicar — "what-you-see-is-what-you-get".
- **Multi-cloud y multi-API** con un único modelo mental.
- **Fuente de verdad versionada** (en Git) frente a cambios manuales por consola.

### Casos de uso

- Aprovisionar redes, compute, DB, LB, IAM, DNS, buckets, etc.
- Gestionar recursos SaaS (GitHub repos y rulesets, Datadog monitors, PagerDuty schedules).
- Base para GitOps de infra (plan automático en PR, apply en merge).
- Fundamento para **plataformas internas**: módulos "golden" expuestos a developers.

### Arquitectura general

```
┌───────────────────────────────────────────┐
│ Archivos .tf (HCL)                        │
│   providers, resources, data, modules,    │
│   vars, outputs, locals, backend          │
└───────────────────────────────────────────┘
                │ terraform init
                ▼
┌───────────────────────────────────────────┐
│ Terraform Core                            │
│   - parse HCL                             │
│   - carga providers (.terraform/)         │
│   - lee state (local o remote backend)    │
│   - construye grafo de dependencias       │
│   - plan: diff state vs deseado           │
│   - apply: ejecuta ops en orden grafo     │
└───────────────────────────────────────────┘
                │ gRPC
                ▼
┌───────────────────────────────────────────┐
│ Providers (plugins)                       │
│   - mapean HCL ↔ API del servicio         │
│   - CRUD de recursos                      │
└───────────────────────────────────────────┘
                │ HTTP APIs
                ▼
┌───────────────────────────────────────────┐
│ Cloud / SaaS APIs                         │
└───────────────────────────────────────────┘
```

### Alternativas

- **OpenTofu** — fork drop-in; mismo HCL, mismos providers.
- **Pulumi** — IaC con lenguajes generales (TS/Python/Go/C#); estado y modelo mental similares.
- **AWS CDK / CDK for Terraform (CDKTF)** — generar HCL/CloudFormation desde código.
- **Crossplane** — IaC como *control plane de Kubernetes* (reconciliación continua, no plan/apply discreto).
- **CloudFormation / ARM / Deployment Manager** — IaC propietarios de cada cloud.
- **Ansible** — Configuration Management (modelo imperativo con idempotencia, no es IaC primariamente, se usa a veces como ersatz).

### Ventajas / limitaciones

**Ventajas**: ecosistema (centenares de providers oficiales y verificados), lenguaje estable desde 1.0, HCL legible, modelo plan/apply con dry-run real, módulos como mecanismo de reutilización, ampliamente comprendido por el mercado.

**Limitaciones / riesgos**:
- El **state es sensible**: contiene valores reales, incluidos secretos de salida — se protege por acceso al backend y encriptación.
- **Drift**: cambios manuales fuera de Terraform rompen la correspondencia con el state.
- Imports y refactors históricamente han sido ásperos (mejorado con `moved`, `import` blocks y `removed`).
- No sustituye a **Configuration Management** dentro de la VM (ahí entra Ansible, cloud-init o AMIs preconstruidas).
- La licencia **BUSL** de HashiCorp restringe uso competitivo; motivo principal del fork OpenTofu.

### Relación con el programa

- Base del aprovisionamiento del **capstone** (VPC, DB, cluster EKS/GKE, DNS, etc.).
- Se integra con **GitHub Actions** (D5) vía **OIDC a cloud** y pipeline de plan/apply.
- Fundamento para **GitOps de infra** y para **DevSecOps** (policy-as-code con OPA/Rego/Sentinel).
- Precondición práctica para **Kubernetes** (se usará para provisionar el cluster).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **git-and-github** ≥ Nivel 2. T-7.1 (modelos cloud, al menos conceptual). JSON y YAML a nivel de lectura. |
| Recomendados | Al menos haber usado una vez una consola cloud (AWS/GCP/Azure). T-3 Networking básico. |
| Complementarios | Curso **github-actions** para los módulos de CI/CD de Terraform (Nivel 4). |

## 3. Organización (4 niveles)

El curso tiene **14 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5): modelo mental y plan/apply, HCL y primer provider, resources vs data sources, variables/outputs/locals, state (qué es, por qué importa).
- **Nivel 2 — Intermedio** (4): módulos, expresiones y meta-arguments (`for_each`, `count`, `dynamic`), ambientes (workspaces vs directorios separados), providers avanzados y lifecycle.
- **Nivel 3 — Avanzado** (3): internals (grafo, refresh, algoritmo del plan), remote backends (S3+DynamoDB, HTTP, HCP Terraform), testing + policy-as-code.
- **Nivel 4 — Producción empresarial** (2): CI/CD de Terraform (OIDC, PR plan + merge apply) y **OpenTofu**; platform patterns (module registry, golden modules, drift management, import/refactoring a escala).

## 4. Entregables del curso

- Módulo propio reutilizable (p. ej. "VPC con subnets públicas/privadas y endpoints").
- Repositorio multi-ambiente (dev/stg/prod) con backend remoto y locking.
- Pipeline GHA que: en PR hace `fmt`, `validate`, `plan`, publica plan como comentario; en merge a `main` hace `apply` con approval.
- ADR comparando workspaces vs directorios separados por ambiente.
- Importación de un recurso creado por consola al state sin recrearlo.
- Documento de evaluación OpenTofu vs Terraform con criterio de elección para la organización.

## 5. Evaluación

- **Conceptual**: explicar paso a paso qué hace `terraform plan` (refresh, graph walk, diff); diferenciar `data` vs `resource`; qué guarda el state y por qué es sensible; qué garantiza `terraform init` que no garantiza `apply`.
- **Operativa**: refactorizar código con `moved`; importar recursos existentes; recuperar state corrupto; resolver drift con `-refresh-only`; configurar un backend remoto con locking.
- **Arquitectónica**: diseñar estructura de módulos y de ambientes para una org; política de versionado de módulos; decisión Terraform vs OpenTofu; política de secretos en state.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial Terraform y OpenTofu.
- Terraform Registry (`registry.terraform.io`) y OpenTofu Registry (`search.opentofu.org`).
- `terraform-aws-modules` y `cloudposse` (ejemplos de módulos comunitarios maduros).
- Guías de "best practices" de HashiCorp y de Gruntwork.
- Checkov, tflint, Terrascan, Trivy (IaC scanning).
- OPA/Conftest y Sentinel para policy-as-code.
