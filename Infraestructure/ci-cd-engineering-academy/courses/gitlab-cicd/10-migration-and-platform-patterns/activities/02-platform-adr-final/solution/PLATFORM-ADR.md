# ADR 011 — GitLab como plataforma de CI/CD de la org

## Estado

Propuesto (Fase 3). Objetivo: Aceptado tras revisión Platform + Security + Finance.

## Contexto

- 300 ingenieros, 120 repos en GitLab (Premium, SaaS).
- Migración piloto `my-org/api-checkout` completada (ADR 010).
- La dirección pide un plan de operación continuo: catálogo, runners, observabilidad y frontera con Argo CD.
- Constraints:
  - Costes de minutos SaaS crecientes (~40k minutos/mes).
  - Compliance Framework obligatorio para 20 proyectos regulados.
  - Despliegue a K8s vía Argo CD aprobado; no se re-abre.
  - Platform son 4 personas; no puede operar un catálogo cerrado con 120 clientes.

## Decisión

### 1. CI/CD Catalog interno (inner-source)

- Grupo `platform/ci-catalog/*`: un repo por componente (`node-test`, `python-test`, `aws-oidc`, `cosign-sign`, `trivy-scan`, `terraform-plan`).
- **Code Owners** por componente (Node→@frontend-platform, AWS→@cloud-platform, security→@security).
- Contribución inner-source: Issue → RFC → MR → Code Owner aprueba (2 aprobaciones para componente nuevo; 1 para patch).
- **SemVer** vía tag Git. Breaking change exige bump mayor.
- **Deprecation policy**: `@deprecated` en `spec:inputs:` + aviso 90 días en Slack `#platform-ci` + eliminación en siguiente major.
- Métricas de adopción: job diario que `grep -r "include:.*component:.*ci-catalog"` en los 120 repos; componente con 0 uso en 90 días → `@deprecated`.

Contrato ejemplo:

```yaml
spec:
  inputs:
    role_arn:  { type: string }
    region:    { type: string, default: eu-west-1 }
    duration:  { type: number, default: 900 }
```

### 2. Runners y cost control

Decisión: **modelo híbrido**.

| Tramo de uso | Runner | Razón |
|--------------|--------|-------|
| <2.000 min/mes (90/120 repos) | **SaaS runners** | Overhead no se amortiza. |
| >5.000 min/mes (10/120) + red privada | **K8s + Fleeting** en AWS | Coste nodo-hora amortiza; cache local; VPC privada. |
| 2.000–5.000 min/mes (20/120) | SaaS por defecto, migrar si crecen | Umbral automático. |

Punto de equilibrio ~10.000 min/mes/proyecto. El modelo híbrido reduce ~35% la factura a 12 meses con ~0.4 FTE adicional en Platform.

### 3. Observabilidad del CI/CD

Las **4 métricas** mínimas del dashboard:

1. **Pipeline duration** (p50, p95) — por proyecto, 7d.
2. **Job success rate** — por job, 7d.
3. **Queue time** (pending→running) — por runner tag.
4. **Minutos consumidos** — por grupo, 7d.

Fuentes: Prometheus exporter (`gitlab_runner_*`) + GraphQL para históricos. Grafana con 4 paneles, 1 pantalla.

Ejemplo PromQL (p95 duración de job):

```promql
histogram_quantile(0.95,
  sum(rate(gitlab_runner_job_duration_seconds_bucket[15m])) by (le, instance))
```

Alertas:

- `queue_time_p95 > 60s` durante 10 min ⇒ page Platform on-call.
- `success_rate < 0.9` por proyecto durante 1h ⇒ ticket al owner.

### 4. Frontera CI/CD con Argo CD

- **GitLab construye y publica**: tests, scanners nativos, build, firma cosign (ID Token keyless), push al Container Registry, bump de versión en repo de manifiestos.
- **Argo CD aplica**: observa `platform/manifests/*` y sincroniza con el cluster.
- No se usa `gitlab deploy to k8s` en prod. Razones: blast-radius acotado por repo de manifiestos; audit via Git; rollback = `git revert`; permisos separados (GitLab sin credenciales kube; Argo sin credenciales registry).

### 5. Compliance Framework

- Grupo `regulated/*` lleva el framework `pci-light-2026`.
- Compliance pipeline incluye: Secret Detection + Container Scanning + SAST + firma cosign + approval rule 2+ en MRs a prod.
- 20 proyectos regulados heredan sin trabajo adicional.
- Audit events exportados a SIEM semanalmente.

### 6. GHA vs GitLab por tipo de organización

| Org | Elección | Criterio |
|-----|----------|----------|
| **Startup 20 personas** | GHA (si ya está en GitHub) | Fricción cero, marketplace, foco en producto. GitLab solo si Compliance Framework es *must* desde día 0. |
| **Scaleup 300 personas** (nuestro caso) | **GitLab** | Catálogo versionado, Compliance Framework, grupos anidables, Container Registry integrado. |
| **Enterprise 5000 personas** | GitLab Self-Managed / Dedicated o GHE | Depende de política de aislamiento, red privada, SSO/SCIM. |

### 7. Roadmap 12 meses

- Q1: catálogo con 3 componentes; dashboards Grafana.
- Q2: runners propios piloto; migración de los 10 proyectos grandes.
- Q3: Compliance Framework GA para los 20 regulados; Argo CD en 50 servicios.
- Q4: SLOs públicos (p95 duration, success rate, queue time).

## Consecuencias

### Positivas

- Catálogo inner-source escala con 300 ingenieros sin cuellos en Platform.
- Modelo híbrido optimiza coste sin perder SaaS para proyectos pequeños.
- Observabilidad desde día 1 permite negociar capacidad con datos.
- Frontera con Argo CD evita acoplar CI con despliegue.
- Compliance heredado desde el grupo; sin disciplina por repo.

### Negativas

- Operar cluster de runners añade ~0.4 FTE a Platform. Mitigación: chart oficial + alertas.
- Inner-source requiere Code Owners mantenidos. Mitigación: 2 owners mínimo por componente.
- Dashboard Prometheus con cardinalidad explosiva si no se agrega bien. Mitigación: agregar por proyecto, no por job name.
- Dependencia de dos planos (GitLab + Argo). Mitigación: documentación de la frontera + runbook conjunto.

## Alternativas descartadas

### Alt A — Catálogo "cerrado" (solo Platform escribe)

1. Platform mantiene todos los componentes como código propietario.
2. Rechazada: Platform son 4 personas; con 120 repos no escala. PRs se bloquean y los equipos *forkean* para desbloquearse.

### Alt B — 100% runners propios desde el día 1

1. Apagar SaaS runners para todos los proyectos.
2. Rechazada: los 90 proyectos con <2.000 min/mes no amortizan el coste de operación.

### Alt C — Desplegar a K8s directamente desde GitLab (sin Argo)

- Rechazada: acopla CI con despliegue y pierde audit por Git. Decisión ya tomada en `argo-cd`.

### Alt D — Operar sin observabilidad formal

- Rechazada: sin métricas no se puede negociar capacidad ni detectar flakies.
