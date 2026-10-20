# REFERENCE — plat-12-01-governance-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección 1 — Contexto

AcmeCorp opera una plataforma interna con 180 ingenieros, 8 equipos de producto, 120 servicios en 3 clusters K8s regionales y un cluster no-prod. Backstage lleva 10 meses en producción con un **70 % del catalog** cubierto. El scaffolder expone 12 templates, de los cuales 3 están deprecated **de facto** pero siguen publicados. Argo CD opera con un único `default` AppProject (antipatrón). No existen SLOs formales de la propia plataforma, por lo que las quejas por lentitud del scaffolder no se pueden contrastar con un objetivo. El platform team son 4 personas y no habrá contratación en 2 trimestres.

Este ADR fija las reglas de operación de la plataforma para el próximo año: **modelo multi-tenant** explícito en los 4 planos (K8s, cloud, Argo CD, Backstage), **deprecation policy** formal, **4 SLOs** publicados y defendidos, **release cadence** mixta (continuo + trimestral), **versionado SemVer** de contratos y un **modelo inner-source** que permita escalar sin crecer linealmente. El ADR es público interno y revisable cada 6 meses.

## Sección 2 — Decisión: multi-tenancy

### 2.1 Decisión (plano K8s)

- **Un namespace por servicio por entorno**: patrón `<team>-<service>-<env>` (p. ej. `checkout-order-api-prod`).
- `ResourceQuota` y `LimitRange` por namespace, con default conservador que cada equipo puede negociar al alza vía ticket.
- `NetworkPolicy` por defecto **deny-all east-west**; el equipo abre explícitamente lo que necesita.
- Clusters por **región**, no por tenant. Un tenant puede estar en varios clusters si opera multi-región.

### 2.2 Decisión (plano cloud)

- **Un GCP project por entorno y por dominio**: `acme-checkout-prod`, `acme-checkout-staging`, etc. 8 dominios × 3 entornos = 24 projects base.
- Jerarquía de **Folders** por dominio para heredar Organization Policies.
- **Service Control Policies** no negociables: solo regiones permitidas, no buckets públicos, enforcement de encryption at rest.
- Billing export centralizado para asignación por project.

### 2.3 Decisión (plano Argo CD)

- **Un `AppProject` por equipo** (8 total). Fin del `default` AppProject (migración en 30 días).
- Cada AppProject declara: `sourceRepos` (whitelist), `destinations` (namespaces del equipo), `namespaceResourceWhitelist`.
- Roles por AppProject: `developer` (sync + get), `approver` (sync + override, 2 personas por equipo), `admin` (platform team only).

### 2.4 Decisión (plano Backstage permissions)

- **Permission framework activado** con policy basada en `spec.owner` del catalog.
- Templates: ejecutables solo por miembros del equipo owner, lectura global.
- Catalog: lectura global, edición solo por owners + maintainers (grupo configurable).
- Admin de templates y plugin config: solo platform team.
- Precondición: **auditoría del catalog** antes de activar policies (si la ownership no está limpia, las policies rompen flujos legítimos). Semana 1-2 del Q1.

## Sección 3 — Decisión: deprecation policy

### 3.1 Los 3 estados

- **Supported**: versión recomendada. Features + bugs + roadmap + SLO completo.
- **Maintenance**: versión anterior aún disponible. Solo bugs críticos y security. No features. SLO reducido.
- **Legacy**: en ciclo de retirada activo. Solo security. Sin SLO. Fecha de hard-remove pública.

Transición obligatoria: **supported → maintenance → legacy**. No se puede saltar directamente a legacy.

### 3.2 TTLs explícitos

| Tipo de pieza | Anuncio → warn | Warn → soft | Soft → hard | Total mínimo |
|---------------|----------------|-------------|-------------|--------------|
| Template Backstage | 30 d | 30 d | 30 d | 90 d |
| XRD de Crossplane | 60 d | 60 d | 60 d | 180 d |
| API interna | 90 d | 90 d | 180 d | 360 d |
| Librería compartida | 60 d | 90 d | 180 d | 330 d |
| Golden path mayor | 90 d | 90 d | 180 d | 360 d |

### 3.3 Cadencia de comunicación

- Changelog en el repo + Slack `#platform-announcements` en cada transición.
- Email semanal automático a owners con "piezas deprecated que usas y próxima fecha".
- Office hour mensual que repasa deprecations activas.

### 3.4 Hard-remove con consumidor pendiente

Si al llegar a hard-remove queda un servicio usando la pieza: **incident ticket**. Platform team asiste en migración de emergencia en < 48 h. Si la hard-remove tuvo que extenderse, es **postmortem obligatorio** por fallo de comunicación en fases previas.

## Sección 4 — Decisión: platform SLOs

### 4.1 SLO Backstage uptime

- **SLI**: `(2xx+3xx) / (2xx+3xx+5xx+429)` en ingress.
- **Objetivo**: 99.5 % sobre 30 d rodantes.
- **Error budget**: 3 h 36 min / mes.
- **Burn-rate**: fast burn 14.4× (1 h + 5 m) → page; slow burn 6× (6 h + 30 m) → ticket.

### 4.2 SLO scaffolder p95

- **SLI**: `count(latencia < 60s) / count(total)` entre task_started y task_finished.
- **Objetivo**: 95 % de ejecuciones < 60 s sobre 7 d.
- **Error budget**: 5 % de ejecuciones pueden exceder umbral.
- **Burn-rate**: alerta cuando p95 1 h > 60 s durante 15 min → ticket.

### 4.3 SLO catalog freshness

- **SLI**: `lag` entre `commit_push` y `catalog_entity_updated`.
- **Objetivo**: p99 < 5 min sobre 7 d.
- **Error budget**: 1 % de updates pueden tardar más.
- **Burn-rate**: p99 30 m > 5 min durante 10 min → ticket.

### 4.4 SLO MTTR

- **SLI**: tiempo entre `incident_declared` e `incident_resolved` para P1/P2 de componentes de la plataforma.
- **Objetivo**: p90 < 2 h trimestral.
- **Error budget**: 10 % de incidentes pueden exceder umbral.
- **Burn-rate**: no clásico; revisión al cierre de cada incidente + agregado trimestral.

### 4.5 Freeze por budget

Si cualquier SLO queda con **< 25 % budget restante** antes del día 20 del período: **feature freeze** del platform team. Se levanta cuando budget recupera > 50 %.

## Sección 5 — Decisión: release cadence

### 5.1 Cadencia continua con feature flags

Para: nuevos templates, nuevos checks de scorecards, bugfixes, mejoras aditivas no breaking, nuevas Compositions ya aprobadas, mejoras de docs.

- Merge-to-main despliega a producción en < 30 min.
- Todo cambio no trivial detrás de **feature flag** (LaunchDarkly interno), default `off`.
- Activación por tenant o canary. Kill switch documentado.

### 5.2 Cadencia trimestral (release train)

Para: nuevas versiones mayores de XRDs, cambios de modelo del catalog, migración de autenticación, nuevos plugins completos de Backstage.

- Release notes + migration guide publicados 2 semanas antes.
- Office hour dedicado a la release.
- Fecha fija: segundo martes del primer mes de trimestre.

### 5.3 Freeze por error budget

Ver §4.5. Durante freeze, solo bugfixes y security.

### 5.4 Criterios de elegibilidad

- **Breaking change** → siempre trimestral.
- **Afecta a > 50 % de servicios** → siempre trimestral.
- **Nuevo contrato público** (nuevo XRD, nueva API) → trimestral.
- Resto → continuo con flag.

## Sección 6 — Decisión: versionado de contratos

### 6.1 SemVer obligatorio

- **MAJOR**: breaking change. Migration guide obligatoria.
- **MINOR**: feature aditiva. Consumidor puede ignorar.
- **PATCH**: bugfix.

Aplica a: XRDs de Crossplane, templates del scaffolder (vía `template.v<n>.yaml`), APIs internas de plugins propios, librerías compartidas (`platform-sdk-*`).

### 6.2 Changelog obligatorio

Formato *Keep a Changelog*, actualizado **en el mismo PR** que introduce el cambio. CI falla si CHANGELOG.md no se tocó.

### 6.3 Convivencia durante breaking change

- **Dual-run** mínimo durante el TTL de deprecation (v1 y v2 vivas en paralelo).
- **Shim** cuando sea posible (CRD conversion webhook; template v1 que delega a v2 internamente).
- **Migration script** idempotente, provisto por el platform team.

### 6.4 Qué cuenta como contrato

- Spec de XRDs, Compositions published.
- `input` schema de templates.
- Endpoints de APIs internas documentadas.
- Firmas públicas de librerías compartidas.

No cuenta como contrato (y por tanto no sigue SemVer): scripts internos, dashboards de Grafana, naming interno de ConfigMaps privados.

## Sección 7 — Decisión: inner-source

### 7.1 Qué aceptamos

Nuevos templates para lenguajes/frameworks no cubiertos, nuevas Compositions de XRDs aprobadas, mejoras no breaking, nuevos checks de scorecards, bugfixes, docs, tests.

### 7.2 Qué no aceptamos sin ADR

Nuevos XRDs, breaking changes, nuevos plugins Backstage, cambios al modelo del catalog, cambios al SLO o a esta deprecation policy.

### 7.3 CODEOWNERS

- Default: platform team.
- `/templates/python/`: platform team + trusted committers Python.
- `/templates/golang/`: platform team + trusted committers Go.
- `/crossplane/compositions/`: platform team + trusted committers por dominio.
- `/governance/`, `CHANGELOG.md`, `SLO.md`: **platform team only**.

### 7.4 SLA de review

- Primer feedback: ≤ 3 días hábiles tras asignación de reviewer.
- Decisión final: ≤ 7 días hábiles.
- Ping en `#platform-help` si se incumple — es la señal operativa, no una ofensa.

### 7.5 Escala trusted committer

- **Contributor**: default. Puede abrir PRs.
- **Trusted committer**: 5+ PRs merged en el área (6 m), 2+ reviews útiles, nominación por owner.
- **Maintainer**: 6+ meses como trusted committer, historial de scope correcto, nominación por platform team.

Revisión semestral. Inactividad 6 m → vuelve a contributor.

### 7.6 Qué retiene platform team

Visión del producto plataforma, veto por SLO/seguridad/contrato, oncall de todos los componentes, decisiones de arquitectura mayor.

## Sección 8 — Consecuencias

### 8.1 Positivas

1. **Fronteras explícitas** en los 4 planos reducen el blast radius de un error humano o de seguridad.
2. **Deprecations controladas** permiten quitar deuda sin romper equipos vivos.
3. **SLOs públicos** convierten "la plataforma va lenta" en una conversación cuantitativa.
4. **Inner-source** desbloquea el throughput sin esperar a hiring (crítico dado el freeze de 2 trimestres).

### 8.2 Negativas / costes

1. La **migración del `default` AppProject** a 8 AppProjects separados es 2-3 semanas de trabajo del platform team.
2. **Instrumentar SLOs** desde cero (Prometheus + rules + runbooks) es 3-4 semanas más.
3. El modelo inner-source **requiere escribir y mantener** CONTRIBUTING.md, PR templates, onboarding — ~1 semana inicial + mantenimiento continuo.
4. Communicate-everything implica que **al menos 20 %** del tiempo del platform team va a changelog, Slack, office hours. No es "overhead": es el trabajo.

### 8.3 Riesgos

1. Si los **owners del catalog** no están limpios, Backstage permissions rompe flujos legítimos. Mitigación: auditoría previa en Q1.
2. **Trusted committers** pueden tardar más de un trimestre en aparecer — hasta entonces, review sigue cuellode-botella en platform team.
3. SLO 99.5 % Backstage puede ser **demasiado ambicioso** con equipo de 4 y oncall rotatorio. Revisión obligatoria a los 60 d con decisión de bajar al 99 % si procede.

### 8.4 Impacto operacional inmediato (próximas 2 semanas)

- Anuncio del ADR en all-hands de ingeniería.
- Pin del ADR en `#platform-announcements`.
- Issue tracker para la migración `default → 8 AppProjects`.
- Office hour especial dedicado a Q&A del ADR.

## Sección 9 — Alternativas consideradas

1. **Mantener `default` AppProject** (statu quo).
   - *Pro:* cero coste de migración.
   - *Contra:* un error de permisos afecta a 8 equipos; no hay granularidad para restringir repos ni destinations. Descartada: el coste de un incidente supera con creces las 3 semanas de migración.

2. **Namespace por equipo (en vez de por servicio)**.
   - *Pro:* menos namespaces, menos overhead administrativo.
   - *Contra:* ResourceQuotas conjuntos entre servicios distintos; blast radius entre servicios del mismo equipo; difícil medir consumo por servicio. Descartada: el servicio es la unidad natural de operación en nuestro contexto.

3. **99.9 % uptime para Backstage**.
   - *Pro:* promesa fuerte a los consumidores.
   - *Contra:* requiere oncall 24/7, SRE dedicado, infra multi-AZ redundante. No viable con 4 personas y 1 presupuesto. Descartada en favor de 99.5 % defendible.

4. **Release-train trimestral puro, sin cadencia continua**.
   - *Pro:* comunicación simple, releases "grandes".
   - *Contra:* un bugfix urgente tarda 3 meses; equipos empiezan a forkear piezas de plataforma. Descartada: mantenemos cadencia mixta con criterio de elegibilidad explícito.

5. **No inner-source — plataforma es solo del platform team**.
   - *Pro:* control total, menos variabilidad.
   - *Contra:* escala linealmente con el equipo; con hiring freeze, condena al backlog eterno. Descartada: inner-source es la única palanca sin coste de hiring.

## Resumen (tweet-length)

> AcmeCorp: 4 planos multi-tenant explícitos, 4 SLOs públicos con error budget, deprecation con TTL por tipo, release continuo+trimestral con freeze por budget, SemVer+changelog en contratos, inner-source con trusted committers. Revisión del ADR cada 6 meses.
