# REFERENCE — gl-10-02-platform-adr-final

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 011 — GitLab como plataforma de CI/CD de la org

## Estado

Propuesto (Fase 3). Objetivo: Aceptado tras revisión Platform + Security + Finance. Materialización por fases (ver roadmap en §7).

## Contexto

- 300 ingenieros, 120 repos en GitLab (Premium, SaaS).
- Migración piloto `my-org/api-checkout` completada (ADR 010).
- La org pide un plan de operación continuo: catálogo, runners, observabilidad y frontera con Argo CD.
- Constraints:
  - **Costes de minutos SaaS** empiezan a dolerle a Finance (~40k minutos/mes y creciendo).
  - **Compliance Framework** obligatorio para 20 proyectos regulados.
  - **Deploy a K8s** vía Argo CD ya aprobado en el curso `argo-cd`; no se re-abre esa decisión.
  - **Platform** son 4 personas; no puede operar un catálogo cerrado con 120 clientes.

## Decisión

### 1. CI/CD Catalog interno (inner-source)

- **Repo**: grupo `platform/ci-catalog/*` con un repo por componente (`node-test`, `python-test`, `aws-oidc`, `cosign-sign`, `trivy-scan`, `terraform-plan`).
- **Code Owners** por componente (dominio: Node→@frontend-platform, AWS→@cloud-platform, security→@security).
- **Contribución inner-source**: cualquier dev abre Issue → RFC (si componente nuevo o breaking) → MR → Code Owner aprueba. 2 aprobaciones para componente nuevo; 1 para patch.
- **SemVer** vía tag Git. Platform (release manager) hace el `tag`. Breaking change exige bump mayor.
- **Deprecation policy**: `@deprecated` en `spec:inputs:` + aviso 90 días en Slack `#platform-ci` + eliminación en siguiente major.
- **Métricas de adopción**: job diario que `grep -r "include:.*component:.*ci-catalog"` en los 120 repos y publica dashboard. Componente con 0 uso en 90 días → candidato a `@deprecated`.

Ejemplo del contrato de un componente:

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
| Proyectos con <2.000 min/mes (90 de 120 repos) | **SaaS runners** | Overhead de operar runners no se amortiza. |
| Proyectos con >5.000 min/mes (10 de 120) + jobs con red privada | **K8s + Fleeting** en AWS (cluster `platform-runners`) | Coste por nodo-hora amortiza; acceso a VPC privada; cache local. |
| Proyectos entre 2.000–5.000 min/mes (20 de 120) | SaaS por defecto, migrar si crecen | Umbral automático. |

Estimación: pasar de 100% SaaS a híbrido reduce ~35% la factura de minutos a 12 meses, con un coste de operación de ~0.4 FTE de Platform (chart, alertas, actualizaciones). Punto de equilibrio ~10.000 min/mes/proyecto.

### 3. Observabilidad del CI/CD

Las **4 métricas mínimas** del dashboard de Platform:

1. **Pipeline duration** (p50, p95) — por proyecto, 7d.
2. **Job success rate** — por job, 7d. <95% consistente ⇒ *flaky*.
3. **Queue time** (pending→running) — por runner tag. p95 > 60 s ⇒ "falta capacidad".
4. **Minutos consumidos** — por grupo, para FinOps y para detectar *runaway*.

Fuentes:

- **Prometheus exporter** oficial (`gitlab_runner_*` metrics) + Grafana (4 paneles, 1 pantalla).
- **GraphQL API** para históricos > retención Prometheus.

Ejemplo PromQL (p95 de duración de job):

```promql
histogram_quantile(0.95,
  sum(rate(gitlab_runner_job_duration_seconds_bucket[15m])) by (le, instance))
```

**Alertas** (2 mínimas):

- `queue_time_p95 > 60s` durante 10 min ⇒ "falta capacidad" (page a Platform on-call).
- `success_rate < 0.9` por proyecto durante 1h ⇒ "proyecto flaky" (ticket al owner, no page).

### 4. Frontera CI/CD con Argo CD

- **GitLab construye y publica**: lint, tests, scanners nativos (SAST/DAST/Secret/Container/SCA), build de imagen, firma con cosign (ID Token keyless), push a Container Registry, bump de versión en repo de manifiestos.
- **Argo CD aplica**: observa `platform/manifests/*` y sincroniza con el cluster.
- **No** se usa `gitlab deploy to k8s` en prod. Razones:
  - Blast-radius acotado por repo de manifiestos.
  - Audit via Git: cada cambio en prod es un commit.
  - Rollback = `git revert`.
  - Permisos: GitLab sin credenciales kube; Argo sin credenciales registry.

### 5. Compliance Framework

- Grupo `regulated/*` lleva el framework `pci-light-2026`.
- Compliance pipeline incluye: Secret Detection + Container Scanning + SAST obligatorios + firma cosign obligatoria + approval rule 2+ en MRs a prod.
- Los 20 proyectos regulados heredan el pipeline sin trabajo adicional.
- Audit events exportados a SIEM semanalmente.

### 6. GHA vs GitLab por tipo de organización

| Org | Elección | Criterio |
|-----|----------|----------|
| **Startup 20 personas** | GHA (si ya está en GitHub) | Fricción cero, marketplace, foco en producto. GitLab solo si Compliance Framework es *must-have* desde el día 0. |
| **Scaleup 300 personas (nuestro caso)** | **GitLab** | Catálogo versionado, Compliance Framework, grupos anidables, Container Registry integrado. GHA viable pero el modelo de permisos y la gestión multi-repo cuesta más. |
| **Enterprise 5000 personas** | GitLab (Self-Managed o Dedicated) o GHE | Depende de política de aislamiento, requisito de red privada, y de SSO/SCIM. GitLab Self-Managed gana cuando se exige control total del plano de control; GHE si la org ya es GitHub-first. |

### 7. Roadmap 12 meses (resumen)

- Q1: catálogo con 3 componentes (`node-test`, `aws-oidc`, `cosign-sign`); dashboards Grafana en pie.
- Q2: runners propios piloto (1 cluster), migración de los 10 proyectos grandes.
- Q3: Compliance Framework GA para los 20 regulados; integración Argo CD aplicada a 50 servicios.
- Q4: SLOs públicos de la plataforma CI/CD (p95 duration, success rate, queue time).

## Consecuencias

### Positivas

- Catálogo inner-source escala con 300 ingenieros sin cuellos de botella en Platform.
- Modelo híbrido de runners optimiza coste sin perder SaaS para proyectos pequeños.
- Observabilidad desde el día 1 permite negociar capacidad con datos.
- Frontera con Argo CD evita acoplar CI con despliegue.
- Compliance heredado desde el grupo; sin disciplina por repo.

### Negativas

- Operar cluster de runners añade 0.4 FTE a Platform. Mitigación: automatización con el chart oficial y alertas.
- Inner-source requiere Code Owners mantenidos; si un owner se va, el componente queda huérfano. Mitigación: política de "2 owners mínimo por componente".
- Dashboard Prometheus con cardinalidad explosiva si no se agrega bien. Mitigación: agregar por proyecto, no por job name.
- Dependencia de dos planos (GitLab + Argo). Mitigación: documentación clara de la frontera; runbook de incidentes conjunto.

## Alternativas descartadas

### Alt A — Catálogo "cerrado" (solo Platform escribe)

1. Platform mantiene todos los componentes como código propietario.
2. Rechazada: Platform son 4 personas; con 120 repos no escala. Las PRs se bloquean en Platform y los equipos acaban *forkeando* para desbloquearse (anti-patrón). Inner-source con Code Owners distribuye el ownership sin perder calidad.

### Alt B — 100% runners propios desde el día 1

1. Apagar SaaS runners para todos los proyectos.
2. Rechazada: los 90 proyectos con <2.000 min/mes no amortizan el coste de operación. Modelo híbrido tiene mejor ratio.

### Alt C — Desplegar a K8s directamente desde GitLab (sin Argo)

- Rechazada: acopla CI con despliegue, abre blast-radius y pierde audit por Git. Decisión ya tomada en el curso `argo-cd`.

### Alt D — Operar sin observabilidad formal (métricas ad-hoc)

- Rechazada: sin métricas no se puede negociar capacidad ni detectar flakies. 4 paneles cuestan 1 día de setup y rinden siempre.

---

## Nota final

Este ADR es el *baseline* del año. Se revisa trimestralmente contra métricas del dashboard y contra adopción del catálogo. Cualquier cambio sustantivo (apagar SaaS, cambiar modelo de inner-source) requiere un ADR nuevo que reemplace a éste.
