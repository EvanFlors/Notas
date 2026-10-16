# Recursos — helm-06

## Documentación oficial

- **Chart dependencies** — <https://helm.sh/docs/topics/charts/#chart-dependencies>
- **`helm dependency`** (comando) — <https://helm.sh/docs/helm/helm_dependency/>
- **`helm dependency update`** — <https://helm.sh/docs/helm/helm_dependency_update/>
- **`helm dependency build`** — <https://helm.sh/docs/helm/helm_dependency_build/>
- **`Chart.yaml` reference (apiVersion v2)** — <https://helm.sh/docs/topics/charts/#the-chartyaml-file>
- **Subcharts and global values** — <https://helm.sh/docs/chart_template_guide/subcharts_and_globals/>
- **Chart Best Practices — dependencies** — <https://helm.sh/docs/chart_best_practices/dependencies/>

## Charts upstream usados en los ejemplos

- **Bitnami charts (índice público)** — <https://charts.bitnami.com/bitnami>
- **`bitnami/postgresql`** (Artifact Hub) — <https://artifacthub.io/packages/helm/bitnami/postgresql>
- **`bitnami/redis`** (referencia para extensiones) — <https://artifacthub.io/packages/helm/bitnami/redis>

> Nota: Bitnami cambió su política de distribución de imágenes a finales de 2024/2025. Verifica al consumir que el `tag` de las imágenes referenciadas por el chart está disponible en el registry que uses (Docker Hub público vs mirror interno vs Bitnami Secure Images). Para prod, considera mirroring interno con `global.imageRegistry`.

## Umbrella vs chart per app

- **Helm — Umbrella Charts (chart organization patterns)** — <https://helm.sh/docs/howto/charts_tips_and_tricks/>
- **Argo CD + Helm (patrón `Application` por componente)** — <https://argo-cd.readthedocs.io/en/stable/user-guide/helm/>
- **Flux `HelmRelease` v2** — <https://fluxcd.io/flux/components/helm/helmreleases/>

## Decisiones arquitectónicas (ADR)

- **ADR GitHub organization** (índice de prácticas) — <https://adr.github.io/>
- **Michael Nygard — "Documenting Architecture Decisions"** (el post seminal) — <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>
- **MADR template** (uno de los formatos ADR más usados) — <https://adr.github.io/madr/>

## SemVer y lockfiles

- **Semantic Versioning 2.0.0** — <https://semver.org/spec/v2.0.0.html>
- **Renovate (bump controlado de dependencias Helm)** — <https://docs.renovatebot.com/modules/manager/helmv3/>
- **Dependabot (soporte para `Chart.yaml`)** — <https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#package-ecosystem>

## Complementario

- **Artifact Hub** (índice público de charts) — <https://artifacthub.io/>
- **`chart-testing` (`ct`)** — <https://github.com/helm/chart-testing>
- **CloudNativePG** (operador — alternativa a Postgres como subchart) — <https://cloudnative-pg.io/>

## Nota de verificación

Última verificación de enlaces: **2026-10-15**. Dominios oficiales de proyectos CNCF/Helm/Argo/Flux/Bitnami. Reverifica cadencia y disponibilidad al momento de impartir el módulo.
