# Solution — plat-07-02-docs-minimum-standard-adr

Esta referencia muestra **una** manera defendible de redactar el ADR. **No es la única**; tu versión puede diferir en los niveles, los artefactos y el enforcement si el razonamiento es coherente.

---

# ADR — Documentation Minimum Standard for Services

## Status

accepted · 2026-03-01 · owner: team-platform

## Context

La organización pasó por tres patologías observadas en la última encuesta de DX:

- 62 % de los servicios tienen el runbook desactualizado > 6 meses.
- 48 % de los oncall arrancan buscando en Slack porque no encuentran el runbook.
- 7 equipos mantienen una página Confluence paralela que contradice el repo.

El dolor es consistente, cross-equipo, y claramente ligado a la ausencia de un **estándar** y a la ausencia de un **enforcement suave**. TechDocs ya está desplegado (modo *centralized*, S3). Falta decir **qué** se exige.

## Decision

### 1. Artefactos obligatorios

| Artefacto | Ruta canónica | Obligatorio desde | Rol |
|-----------|---------------|-------------------|-----|
| **README / index** | `docs/index.md` | Q2 2026 | Puerta de entrada. Link a runbook, oncall, dashboards. |
| **ADRs** | `docs/adr/NNNN-titulo.md` | Q2 2026 | Decisiones arquitectónicas con fecha y status. ≥ 1 ADR para servicios nuevos. |
| **Runbook de deploy/rollback** | `docs/runbook/deploy-and-rollback.md` | Q2 2026 | Procedimiento operativo mínimo. |
| **Runbook de incident response** | `docs/runbook/incident-*.md` | Q3 2026 | ≥ 1 escenario documentado. |
| **API reference** | `docs/api/reference.md` (+ `openapi.yaml` si aplica) | Q3 2026 | Autogen desde contract OpenAPI/AsyncAPI. |
| **Contactos y oncall** | `docs/contact.md` | Q2 2026 | Owner team, Slack, PagerDuty, oncall. |
| **SLOs** | `docs/slo.md` | Q4 2026 (tier gold Q3) | SLIs, objetivos, ventana. Enlace al burn rate dashboard. |

### 2. Modo TechDocs

Adoptamos **modo centralized** (pipeline CI publica a S3). Razones:

- Escala: Backstage no soporta hacer `mkdocs build` por request para los 180+ Components previstos.
- Auditabilidad: cada bundle es un artefacto versionado en el bucket (versioning encendido).
- Credenciales: OIDC federado desde GitHub Actions al rol `techdocs-publisher` → cero long-lived keys.

El modo in-situ queda **solo** en la instancia de `backstage-dev` para iteración local; no se activa en prod.

### 3. Ownership

Regla en CODEOWNERS del repo del servicio:

```
/docs/ @org/<team>
```

Cada equipo dueño del servicio es también dueño de sus docs. PRs que toquen `docs/` requieren review del team. Esto es **mandatorio** desde Q2 2026 y se chequea con un fact del TechInsights.

Además, cada `catalog-info.yaml` del servicio debe tener la anotación `backstage.io/techdocs-ref: dir:.` (o `dir:<subcarpeta>`) para que Backstage descubra el sitio. Un fact del TechInsights valida que la anotación existe.

### 4. Enforcement

Modelo escalonado:

| Tier | Qué se exige | Qué pasa si no cumple |
|------|--------------|----------------------|
| **Bronze** | README/index + Contactos + CODEOWNERS para `/docs/` | Soft fail en PR (warning, no bloquea). |
| **Silver** | Lo de Bronze + Runbook deploy/rollback + ≥ 1 ADR | Warning rojo en el EntityPage del catálogo. |
| **Gold** | Lo de Silver + API ref + SLOs + Runbook incidente | Bloqueo de deploy a prod si el fact falla, salvo *waiver* firmado por el lead de plataforma con TTL ≤ 90 días. |

Los tiers son **opt-in** salvo para servicios "customer-facing" que son automáticamente **Silver mínimo** desde Q3 2026 y **Gold mínimo** desde Q1 2027.

### 5. Métricas de adopción

Dashboard "docs health" en Grafana, alimentado por facts del TechInsights:

- **% de servicios con tier Bronze/Silver/Gold** (lagging).
- **% de PRs que tocan `src/` y también `docs/`** (leading — indica si docs se mantienen al ritmo del código).
- **Edad mediana del runbook** por servicio (lagging — si crece, drift).
- **# de "doc requests" en Slack `#platform-support`** (contra-indicador — si crece, el estándar no está funcionando).

**No** medimos "número de líneas de docs" ni "número de páginas". Son métricas trivialmente gameables (Goodhart's Law).

## Consequences

- **Positivas:** reducción esperada de MTTR en incidentes (runbook presente); reducción de "doc requests" en Slack; onboarding de nuevos devs más rápido (search en Backstage encuentra).
- **Negativas:** carga inicial para los equipos de servicios legacy (~2 días/servicio para alcanzar Bronze); 2 roles nuevos de IAM en AWS por cuenta; dependencia de que los CODEOWNERS estén actualizados.

## Alternatives considered

- **Mantener Confluence oficial.** Descartado: el drift crónico es la razón por la que estamos redactando este ADR.
- **Repo central `/platform-docs` donde cualquiera abre PR.** Descartado: incentivos; los equipos de producto no sienten ownership sobre un repo que no es "suyo".
- **Hacer el estándar aspiracional (no measurable).** Descartado: lo probamos en 2024, no se adoptó más allá de 3 servicios piloto.

## Antipatterns a evitar

- **README monolítico de 2000 líneas** que mezcla setup, arquitectura, runbook y FAQ. Partir en artefactos separados.
- **Wiki paralelo "oficial"** en Confluence. Dejar Confluence para notas de reunión, no documentación técnica.
- **Docs sin owner** en CODEOWNERS. Convierte el estándar en folclore.
- **Scorecards que miden "# de páginas"** → stubs vacíos para pasar el check. Medir el *outcome* (edad del runbook, correlación PR-src/PR-docs), no el *output*.

---

## Notas sobre esta referencia

- La tabla de tiers es un ejemplo defendible, no la única configuración razonable. Un ADR equivalente podría tener solo 2 tiers o 4, o renombrarlos (`required/recommended/optional`). Lo que importa es que haya **progresión** y que el enforcement escale con el tier.
- Las fechas de "obligatorio desde" son concretas a propósito. Un ADR sin fechas se vuelve aspiracional; con fechas, el platform team y los stream-aligned teams pueden calendarizar el trabajo.
- El fact/check del TechInsights no se implementa aquí — se cubre en `plat-10`. Este ADR solo **declara** que se medirá.
