# ADR-0023: Platform IaC Contract for Acme Payments

Date: 2026-10-15
Author: Staff Platform Engineer
Reviewers: VP Platform, Head of Security, Finance Ops, Tech Leads council

## Status

proposed

## Context

Acme Payments opera ~60 microservicios en AWS con Terraform ≥ 1.5 desde hace dos años, pero sin un contrato de plataforma. Hay tres copias semi-equivalentes de "módulo VPC", un golden module heredado y desatendido, y drift detectado en 20 de 60 stacks sin owner claro. En el último trimestre un bump manual del provider AWS en prod causó un incidente P1 que afectó a stacks vecinos; un bucket S3 quedó público 4 días; el onboarding de un microservicio tarda 3 semanas. Security pide policy-as-code demostrable en PRs y Finance pide tags obligatorios de `cost-center` y `owner`. No hay presupuesto para HCP Terraform.

El objetivo de este ADR es fijar el contrato mínimo viable: registry, SemVer, qué expone el golden module, respuesta operativa al drift y gobernanza del apply en prod.

## Decisions

### Decision 1: Internal registry via Git tags, self-hosted

Cada módulo golden vive en su propio repo bajo la organización `acme-platform/terraform-module-*`. Se publica con tags SemVer (`vX.Y.Z`) por un workflow release-please. Los consumers referencian por `source = "git::https://github.com/acme-platform/terraform-module-eks-service.git?ref=v1.4.2"`. No se usa HCP ni Artifactory en 2026 (presupuesto); se re-evalúa en 2027 si el número de módulos pasa de 15.

### Decision 2: SemVer estricto y tags inmutables

MAJOR = breaking (variable borrada/renombrada sin alias, cambio de default que mueve el plan de consumers existentes, change en el tipo del recurso). MINOR = feature backward-compat. PATCH = bugfix sin cambio de contrato. **Un tag publicado no se mueve nunca**; si hay bug, se publica un patch. CI del módulo exige CHANGELOG.md actualizado con la clasificación.

### Decision 3: Golden module `microservice-eks` opinionado pero mínimo

El módulo expone **8 variables obligatorias** (`service_name`, `image`, `cpu`, `memory`, `desired_count`, `environment`, `owner`, `cost_center`) y 4 opcionales (`healthcheck_path`, `env`, `secrets_ref`, `extra_policies`). Internamente fija: naming (`acme-${env}-${service}`), tags obligatorios, encryption, log retention 30d, políticas IAM mínimas, service account IRSA. **No** expone: elección de cluster, networking, DNS zone, políticas de red. Equipos que necesiten algo fuera del contrato abren issue; se evalúa como MINOR del módulo o se documenta por qué no.

### Decision 4: Respuesta al drift — tabla de decisión por tipo de recurso

Un job scheduled corre `terraform plan -refresh-only` cada 6 h sobre todos los stacks prod y abre un GitHub Issue si hay diff. Criterios:
- IAM, buckets S3, security groups → **revert** por default (son controles de seguridad).
- Autoscaling counts, `desired_count`, tags inyectados por SCPs → **ignore_changes** documentado en el módulo.
- Recursos aparecidos por consola → **adopt** vía `import {}` en PR, o **revert** destruyendo si no debía existir.
SLO: todo drift crítico cerrado en < 24 h.

### Decision 5: Apply en prod requiere dos aprobadores de `@acme-platform/approvers`

GitHub Environment `prod` con required reviewers: 2 personas del team `platform-approvers` (rotación semanal). Branch protection en `main`. CODEOWNERS exige review del equipo dueño del repo. Toda aprobación queda en el audit log de GitHub por 400 días. Developers hacen PR y mergean; **nadie dispara apply en prod directamente**.

## Trade-offs

- **Autonomía del dev vs control de seguridad.** El golden module no deja elegir ciertos atributos (p. ej. encryption off). Un equipo con un caso válido debe pedir una MINOR al módulo o justificar un stack "escape hatch" revisado por Security. Preferimos la fricción explícita a la foot-gun implícita.
- **Velocidad de delivery vs auditabilidad.** Dos aprobadores en prod añaden latencia de minutos a horas. Compensamos con una on-call de platform-approvers 24/7 y pre-apply en staging automático. Si la latencia excede el SLO, se re-abre el ADR.
- **Uniformidad vs flexibilidad.** El módulo golden no cubre todos los casos; preferimos cubrir el 80% de microservicios perfectamente y dejar el 20% como "stacks custom" con policy-as-code *más estricta* (Rego) en vez de inflar el módulo con flags.
- **Costo humano del release del módulo vs flexibilidad.** Publicar cada MINOR exige CHANGELOG + review; es caro. Pero sin eso, el módulo degenera.

## SLOs and metrics

- **Time-to-prod de un nuevo microservicio (p95): < 2 días** desde PR inicial hasta tráfico en prod. Medido con GHA + Datadog.
- **Stacks sin drift abierto: > 95%** en cualquier momento. Dashboard de drift semanal.
- **MTTR de drift crítico (IAM/S3/SG): < 24 h.** Alerta a #platform-oncall.
- **Adopción del golden module: ≥ 80% de microservicios en EKS** antes de Q3 2027. Métrica: `terraform state pull` + grep del `source` del módulo.
- **Policy violations en PR: < 5% de PRs**. Medido por `conftest` + GHA.

## Consequences

- La platform team debe sostener el ciclo de releases del golden module: owner nombrado, SLA de 2 días para PRs externos.
- Security recupera observabilidad: todo PR a infra pasa por `conftest` sobre el plan JSON, con biblioteca Rego versionada en `acme-platform/terraform-policies`.
- Developers deberán refactorizar los 60 microservicios a lo largo de 2 trimestres; se asigna un *platform liaison* por equipo durante la migración.
- Finance obtiene reports mensuales por `cost-center` tag (ya emitidos por AWS Cost Explorer).
- Riesgo: equipos "rebeldes" que no quieran el golden module. Mitigación: Security Review *obligatorio* para stacks fuera del contrato.

## Alternatives considered

- **HCP Terraform**: descartado por presupuesto 2026; re-evaluar en 2027. Habría dado workspaces + policy-as-code nativos + run management, pero el costo por workspace * 60 era prohibitivo.
- **Monorepo único de infra**: descartado; acopla todos los apply, destruye blast-radius isolation, y mezcla ownership.
- **Pulumi**: descartado; cambio de lenguaje y re-training de 180 ingenieros, sin beneficio proporcional sobre el problema real (organizacional, no de HCL).
- **Dejarlo como está + solo policy-as-code**: no resuelve la duplicación de módulos ni la gobernanza del apply en prod.

## Defense Q&A

**Q1:** ¿Por qué los equipos no pueden usar el provider AWS directamente, con policy-as-code que valide lo mismo?
**A1:** Podrían, y el ADR no lo prohíbe para stacks fuera del golden path. Pero cada equipo que escribe su propia VPC + IAM re-descubre los mismos bugs que ya resolvimos en el módulo. El golden path reduce *costo cognitivo repetido*, no solo riesgo de seguridad.

**Q2:** ¿Qué pasa si Security exige un control nuevo (p. ej. KMS CMK por servicio) que el módulo golden no soporta todavía?
**A2:** Se abre un issue en el módulo con prioridad P1. El SLA de la platform team para P1 es 48 h. Mientras tanto, Security puede imponer el control vía Rego policy sobre todos los stacks (afectando también los no-golden), lo que crea presión organizacional para adoptar la nueva versión del módulo.

**Q3:** ¿Por qué el ADR no obliga a HCP Terraform? Resolvería varios de los problemas enumerados.
**A3:** Resolvería workspaces y gestión de runs, pero no el problema de fondo: módulos duplicados y ausencia de contrato. HCP sin golden module sería "mismo caos, UI más bonita". Primero fijamos contrato con Git tags + GHA; HCP se evalúa en 2027 cuando el contrato esté interiorizado y el costo justifique.
