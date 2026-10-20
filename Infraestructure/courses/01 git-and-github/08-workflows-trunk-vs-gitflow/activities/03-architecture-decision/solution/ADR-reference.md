# ADR-001: Branching Strategy

## Status

Accepted.

Fecha: 2026-04-01.
Autor(es): Equipo plataforma + SRE.

## Context

Equipo de 11 ingenieros (8 backend, 3 frontend) + 1 SRE part-time, construyendo un SaaS multi-tenant B2B
desplegado en Kubernetes. ~200 clientes empresa; no hay despliegues on-premise. El objetivo del negocio es
pasar de 1 release por semana (jueves, *release train* manual) a al menos 1 release diaria, manteniendo
cumplimiento SOC 2 Type II. Herramientas disponibles: GitHub Enterprise Cloud, GitHub Actions, Unleash
(flags) self-hosted, Datadog, PagerDuty.

Dolor actual medible: PRs con vida p50 ≥ 5 días; merge conflicts semanales con costo humano significativo;
cada "release train" acumula 20+ PRs y uno malo obliga a revertir todo el tren o a buscar el culpable bajo
presión. Es un caso de libro de ramas largas + batching alto.

## Decision

**We will adopt trunk-based development** sobre `main`, con feature flags obligatorios para cualquier cambio
no trivial, PRs < 400 líneas, vida de rama < 1 día, y despliegue a producción al menos una vez al día tras
*main* pasar CI y aprobación de 1 revisor con CODEOWNERS.

Pilares:

- **Una sola rama larga: `main`**. Todas las demás son efímeras (`feat/*`, `fix/*`, `chore/*`).
- **Feature flags en Unleash** para desacoplar deploy de release; defaults OFF en todos los entornos
  excepto por rollouts planeados.
- **Branch protection**: PR obligatoria, status checks verdes, 1 revisor con CODEOWNERS, prohibición de
  push directo y de force-push a `main`.
- **Releases por tag `vYYYY.MM.DD-rev`** sobre `main`. Despliegue continuo automatizado a staging; a prod,
  con approval del on-call via GitHub Environments.
- **Hotfix = PR sobre `main`** con el label `hotfix`, mismo pipeline, fast-tracked en revisión.
- **SOC 2**: la trazabilidad vive en commits + PRs + aprobaciones (todo auditable en GitHub) + Actions logs
  retenidos. No se requiere rama `release/*` para "congelar QA".

## Alternatives Considered

- **GitFlow (con `develop`, `release/*`, `hotfix/*`)**: descartado. No hay múltiples versiones mayores en
  soporte simultáneo (es SaaS); el doble merge y la latencia dev→usuario agravarían el dolor actual en vez
  de mitigarlo.
- **GitHub Flow puro (sin flags)**: descartado. Un tamaño de equipo de 11 con ambición de deploy diario
  necesita flags para desacoplar deploy de release y permitir rollouts graduales; sin flags, cada merge a
  `main` desplegaría cambios visibles al 100 % de clientes de inmediato, incompatible con la gestión de
  riesgo del on-call.
- **GitLab Flow con *environment branches* `staging`/`prod`**: descartado. Introduce cherry-picks o
  divergencias entre entornos; con nuestro deploy ya gestionado por Argo CD + Kubernetes, el estado por
  entorno vive en el cluster, no en una rama Git. Añadir ramas de entorno sería duplicar la fuente de
  verdad.

## Consequences

- **Positiva** — lead time se reduce esperadamente de ≥5 días a < 1 día; merge conflicts caen
  cuadráticamente al bajar la vida de rama.
- **Positiva** — rollback granular por flag en segundos sin re-deploy, mejorando MTTR.
- **Positiva** — historia en `main` lineal, fácil de bisectar.
- **Negativa / costo** — exige disciplina de PRs chicas; probablemente requiere formación interna 1–2
  semanas y un *champion* por squad.
- **Negativa / deuda** — flags no retirados se acumulan como deuda técnica; mitigado abajo.
- **Negativa / cambio cultural** — adiós al *release train* como "ritual" semanal; algunos stakeholders no
  técnicos pedirán un cambio de comunicación.

## Risks and Mitigations

- **Risk 1 — Deuda de flags**: flags "ganadores" permanentemente ON contaminan el código. **Mitigation:**
  cada flag abre un issue de retirada con fecha máxima de 30 días post-100 %; dashboard de flags abiertos;
  revisión mensual.
- **Risk 2 — Degradación a "GitHub Flow lento"**: PRs crecen y vuelven las ramas de 1 semana.
  **Mitigation:** medir *branch lifetime* y *PR size* en un dashboard; alertar al TL cuando p50 excede 2
  días o 400 líneas; retro mensual con esos números.
- **Risk 3 — SOC 2 auditor pide "rama de release congelada"**: posible malentendido del control.
  **Mitigation:** documentar en el *Change Management* del SOC 2 cómo los PRs + CODEOWNERS + status checks
  + GitHub Environments satisfacen el control, con evidencias (screenshots de rulesets, logs de approvals).

## Review Triggers

- Lead time (first commit → prod) p50 > 2 días durante 1 mes consecutivo.
- Change failure rate > 15 % durante un trimestre.
- Deuda de flags > 25 flags activos simultáneamente sin plan de retiro.
- Cambio de modelo de negocio (p.ej. pasar a vender versiones on-premise con soporte paralelo).

## References

- Lección `gh-08-workflows-trunk-vs-gitflow/theory/lesson.md`.
- Hammant, *Trunk-Based Development* — <https://trunkbaseddevelopment.com/>.
- Fowler, *Patterns for Managing Source Code Branches*.
- Fowler, *Feature Toggles*.
- DORA / Accelerate (Forsgren, Humble, Kim).
- OpenFeature spec — <https://openfeature.dev/>.
