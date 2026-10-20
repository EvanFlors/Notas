# Ejercicio arquitectónico — "Acme Fintech" migra a GitLab y necesita golden path

**Peso en el examen:** 25 % · **Formato:** ADR en `entrega/answers.md` bajo `## ADR — <título>` · **Tiempo sugerido:** 25–35 min.

---

## Contexto

Acme Fintech es una empresa de ~400 ingenieros con la siguiente realidad:

- **~120 repositorios** hoy en **GitHub Enterprise + GHA**, organizados en una Org con 8 equipos.
- Catálogo compartido: **9 reusable workflows** (build Node, build Go, build Python, publish OCI, scan, release, docs, infra plan, infra apply) y **4 composite actions**.
- **AWS** multi-cuenta (shared services + dev + stg + prod). Hoy se autentican con **OIDC desde GHA** → `AssumeRoleWithWebIdentity`, con `sub` pinneado a `repo:acme/*:ref:refs/heads/main` por entorno.
- **Compliance:** auditoría ISO 27001 anual. Hoy un «required workflow» a nivel org inyecta: SAST, Secret Detection, SBOM, firma cosign.
- **Despliegue continuo:** **Argo CD** aplica a EKS. GHA **solo construye y publica** imágenes + manifiestos a `env/` branches; Argo CD toma de ahí.
- Dolores concretos:
  - **Coste GHA**: ~70 % del gasto proviene de 15 pipelines monolíticas de QA que corren matrix 6×4 cada MR.
  - **Governance**: el required workflow no permite `inputs` tipados; los equipos lo copian y mutan.
  - **Visibilidad de seguridad**: findings dispersos entre 120 repos.
- Dirección decidió **migrar a GitLab Ultimate SaaS** (`gitlab.com` + Group `acme`) en 9 meses. Argo CD se queda como está.

## Lo que te piden

Diseñar la **plataforma CI/CD en GitLab** para Acme y escribir el **ADR** que la respalde. El ADR debe cubrir **todos** los puntos siguientes y es la base de puntuación (ver rúbrica en `EXAM.md` § C).

### Preguntas que el ADR debe responder

1. **Jerarquía y catálogo**
   - ¿Qué estructura **Group / Subgroup** proponés? ¿Dónde vive el **CI/CD Catalog interno** (en qué subgroup)?
   - ¿Cómo mapeás los 9 reusable workflows a **CI/CD Components** vs `include:project:` vs `extends:`? Justificá al menos **una** elección donde `extends:` siga siendo mejor que un Component.

2. **Runners**
   - ¿**SaaS runners** de GitLab o **self-hosted** en EKS (chart) con **Fleeting** para picos? Dar criterio por workload: builds OCI, tests pesados, infra apply, docs.
   - ¿Cómo migrás de **registration tokens** (deprecated) a **authentication tokens** sin downtime?

3. **OIDC / ID Tokens a AWS**
   - La trust policy actual acepta `token.actions.githubusercontent.com`. Rediseñá la trust policy para aceptar también `gitlab.com` como issuer **sin ampliar el blast radius**.
   - Mostrá el **patrón de `sub` claim** de GitLab que pinnearías por entorno (`dev`/`stg`/`prod`), y explicá qué pasa si solo pinnearas `project_path`.
   - Plan de **dual-run** (GHA y GitLab asumiendo el mismo rol temporalmente): ¿qué controles compensás?

4. **Compliance Pipeline**
   - Diseñá un **Compliance Framework** aplicado al group `acme` que inyecte: SAST + Secret Detection + Dependency Scanning + Container Scanning + firma cosign keyless.
   - ¿Qué pasa si un equipo redefine un job con el mismo nombre que el inyectado? ¿Cómo evitás que lo neutralicen con `allow_failure: true` global?
   - Explicitá qué **no** cubre el framework y necesita **MR approval rules + Code Owners** adicionales.

5. **Frontera CI vs CD con Argo CD**
   - Dibujá dónde **termina** GitLab (publicar imagen firmada + manifiesto bump) y dónde **empieza** Argo CD.
   - ¿Usarías **GitLab Agent for Kubernetes** / GitOps mode como refuerzo, o lo descartás? Justificá.
   - ¿Qué pasa con los environments de GitLab (`review/*`, `staging`, `production`) si Argo CD es quien aplica? ¿Son redundantes, complementarios?

6. **Migración y rollout**
   - Plan **dual-run** por fases (3–4 fases). ¿Qué repos migrás primero y por qué?
   - **Métricas de éxito** (job duration p95, success rate, queue time, coste/mes, nº de incidentes relacionados).
   - **Criterio de rollback** por fase.

7. **Coste**
   - Dado el dolor del 70 % de gasto en matrix QA, ¿qué cambia en GitLab? (hint: `parallel: matrix:` + sharding + `needs:` + self-hosted en EKS para esos jobs).
   - ¿Dónde **no** vale la pena self-host (jobs ligeros, bursty)?

## Restricciones (no son opcionales)

- Argo CD **no cambia**. Si tu diseño lo reemplaza por GitLab Agent GitOps, debés justificarlo como *alternativa descartada* con razón explícita (coste de migración, lock-in, madurez).
- **Cero credenciales de larga vida** nuevas. Todo cloud-auth va por **ID Tokens**.
- Compliance Pipeline debe ser **inextensible por el equipo del project** en sus jobs obligatorios (puede añadir, no quitar).
- **Golden path** debe estar en el Catalog con **SemVer** y `spec: inputs:` tipados.

## Entregable

En `entrega/answers.md`, sección `## ADR — Plataforma CI/CD GitLab en Acme Fintech`, con:

- **Contexto** (resumen propio, 5–10 líneas).
- **Decisión** (párrafo-tesis + bullets de componentes).
- **Alternativas consideradas** (mínimo 3, con **trade-offs reales**, no «el otro es peor»). Al menos **una** debe estar descartada con razón explícita.
- **Trade-offs** de la decisión elegida.
- **Consecuencias** (operativas, de coste, de seguridad, de migración).
- **Plan de revisión** (métrica + umbral + fecha de reevaluación).
- Diagrama ASCII opcional pero valorado para la frontera CI/CD.

### No-goals permitidos

- Diseñar la pipeline de un repo concreto (eso lo cubre la sección operativa).
- Elegir el framework de tests o la base image (no cambia por la migración).
- Rediseñar Argo CD.

## Rúbrica aplicada (recordatorio)

Ver `EXAM.md` § C para los 5 criterios × 4 niveles. Mínimo **50 %** para aprobar la sección. **Red flags** que invalidan el ADR:

- Trust policy OIDC que acepta cualquier project (`sub` sin pinning).
- Reintroducir keys estáticas «para la fase dual-run».
- Compliance Pipeline «opcional» o evadible vía fork.
- Reemplazar Argo CD sin justificarlo como alternativa descartada.
- `cosign verify` deshabilitado en el consumidor.

## Preguntas de seguimiento (live, instructor-only)

- «Si el auditor pregunta cómo garantizás que `main` de `payments-core` solo despliega desde pipelines de GitLab y no desde la laptop de alguien, ¿qué le mostrás concretamente?»
- «Un equipo propone saltarse el Compliance Framework porque "retrasa el time-to-market". ¿Qué controles técnicos hacen que no sea negociable?»
- «Si Argo CD cae 2 h, ¿tu pipeline de GitLab sigue siendo útil o se bloquea? ¿Por qué?»
- «¿Cómo cambia tu trust policy OIDC si tenés también GitLab Self-Managed on-prem para un subset de repos regulados?»
