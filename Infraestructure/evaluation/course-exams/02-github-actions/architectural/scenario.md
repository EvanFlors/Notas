# Escenario arquitectónico — "Golden path" de CI/CD para una organización

## Contexto

Eres el nuevo *platform engineer* responsable de GitHub Actions en **Acme Corp**:

- 1 organización GitHub Enterprise Cloud.
- ~60 developers en 8 squads.
- ~45 repos activos, mayoría **servicios Python 3.12** (FastAPI) desplegados a
  **AWS EKS** vía manifiestos Kustomize; algunos repos frontend en Node 20.
- Despliegues: `dev` auto en push a `main`, `staging` tras merge con smoke tests,
  `production` con approval humano. Dos regiones AWS (`us-east-1`, `eu-west-1`).
- Un repo público de **SDK open source** acepta PRs de forks.
- Equipo de seguridad exige: cero credenciales de larga vida, imágenes firmadas,
  attestations verificables, y auditoría de qué pipeline produjo cada artefacto.
- Finanzas detectó que los minutos de Actions crecieron 4× en 6 meses; piden
  un presupuesto por repo y visibilidad p50/p95.
- Existe un cluster EKS "ci-runners" de 20 nodos m5.large underutilizado que
  los SREs quieren justificar o apagar.

## Requisitos (duros)

1. **Ningún secreto estático** de cloud en los repos.
2. **Required checks** aplicables org-wide sin que cada repo los pueda saltar.
3. Despliegue a `production` requiere **approval humano** y queda en el deployment record.
4. Imágenes publicadas a GHCR deben incluir **SBOM**, **build-provenance attestation**
   y **firma cosign keyless**; el consumidor debe poder verificar sin coordinación con el productor.
5. El SDK público debe aceptar PRs de forks **sin exponer secretos** y sin que un fork pueda
   publicar al registry.
6. Dashboard de costo con **p50/p95** de duración y minutos consumidos por repo.

## Restricciones

- Presupuesto: hasta USD 3k/mes en Actions + GHCR + larger runners.
- Equipo de plataforma: 2 personas. Nada que requiera > 1 semana/mes de mantenimiento.
- Prohibido Jenkins, GitLab u otro orquestador paralelo.
- Prohibido branch protection "classic" (debe usarse **repository rulesets**).

## Qué debes producir (entregable)

1. **Diagrama** (ASCII, mermaid o PNG) que muestre:
   - Repos: aplicación / reusable workflows / custom actions / infra.
   - Flujo PR → required checks → merge → dev → staging → prod.
   - Dónde actúan OIDC, environments, approvals, concurrency, cosign, Rekor.
   - Dónde corren jobs (hosted vs ARC) y por qué.

2. **ADR único** (`ADR-ci-platform.md`) con mínimo **5 decisiones**, cada una con
   contexto / opciones consideradas / decisión / consecuencias / cómo se revierte.
   Cubrir al menos:
   - Composite action vs reusable workflow para el "golden path".
   - Required workflows via rulesets vs starter workflows.
   - Hosted vs ARC en el cluster existente (incluir el cálculo de costo que justifica apagar o mantener).
   - Modelo de trust policy OIDC (claim de environment vs claim de ref).
   - Política de pinning (SHA + Dependabot) y respuesta a un incidente tipo `tj-actions/changed-files`.

3. **Tabla de trade-offs** cruzando *Developer Experience*, *Seguridad* y *Costo*
   para cada decisión mayor (al menos 5 filas).

4. **Métricas objetivo** (SLOs del pipeline): p50/p95 de duración por tipo de pipeline,
   tasa de éxito, tiempo de rollback, MTTR del pipeline mismo. Justificar los números.

5. **Plan de rollout en 6 semanas** con hitos verificables y criterios de rollback.

## Preguntas que el ADR debe responder explícitamente

- ¿Por qué el `sub` claim de la trust policy OIDC no puede ser `repo:acme/*:*`?
- ¿Qué pasa si GitHub.com está caído durante una ventana de release de producción?
- ¿Cómo evitas que un reusable workflow publicado como `@v1` sea manipulado por
  quien tenga permiso de mover el tag?
- ¿Por qué el repo público del SDK no debe usar self-hosted ni `pull_request_target` con checkout del head?
- ¿Cómo garantizas que el consumidor del SDK puede verificar la attestation sin acceso a la org Acme?

## Rúbrica resumida

Ver `../EXAM.md §5` (rúbrica detallada de 4 niveles por criterio: *correctness*,
*justificación*, *trade-offs*, *seguridad*, *operabilidad*, *coste*).

Umbral: **≥ 70% ponderado**, y ninguna red flag (ver `../competency-matrix.yaml:fail_regardless_of_score`).
