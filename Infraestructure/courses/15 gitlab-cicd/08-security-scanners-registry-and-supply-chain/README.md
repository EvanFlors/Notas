# gl-08 — Scanners de seguridad, Container Registry y cadena de suministro

## Identificación

- **ID:** `gl-08-security-scanners-registry-and-supply-chain`
- **Curso:** `gitlab-cicd`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gl-02` (anatomía de `.gitlab-ci.yml` y runners), curso **devsecops** ≥ Nivel 2 (SAST/DAST/SCA, firma de imágenes, OIDC).

## Objetivo

Interiorizar la **cadena de suministro nativa de GitLab**: scanners de seguridad incluidos como templates oficiales (`Jobs/SAST.gitlab-ci.yml`, `Jobs/Secret-Detection.gitlab-ci.yml`, etc.), **Container Registry** como OCI por project, **Package Registry** multi-formato, generación de **SBOM**, estado parcial de **SLSA provenance**, y firma keyless de imágenes con **cosign** usando **ID Tokens** de GitLab como issuer OIDC. Al terminar deberías poder habilitar 5+ scanners, leer el **Security Dashboard**, triagear hallazgos desde el **widget de MR**, publicar imágenes al Container Registry con **cleanup policies**, y firmar una imagen sin claves de larga vida.

## Alcance

Este módulo cubre:

- Templates oficiales de scanners: **SAST**, **Secret-Detection**, **Dependency-Scanning**, **Container-Scanning** (Trivy bajo el capó en versiones recientes), **DAST**, **IaC-Scanning**, **License-Scanning**, **Fuzz-Testing**; cuáles son Free y cuáles **Ultimate-only**.
- **Security Dashboard**: findings agregados, triage (`dismiss`, `confirm`, `resolve`), vulnerability report.
- **Merge Request security widget**: cómo bloquear merges por severidad y por vulnerabilidades introducidas en la MR.
- **Container Registry**: estructura `registry.gitlab.com/<group>/<project>/<image>`, auth con `$CI_REGISTRY_USER`/`$CI_REGISTRY_PASSWORD`, **cleanup policies** por tag regex, **dependency proxy** para esquivar el rate limit de Docker Hub.
- **Package Registry**: PyPI, npm, Maven, Composer, NuGet, Go, Helm, Conan.
- **Supply chain**: **SBOM** (CycloneDX nativo desde los scanners), **SLSA provenance** (estado parcial — verificar en Fase 4), **cosign keyless** con `id_tokens:` y `aud:` apuntando a Sigstore (`sigstore`).
- Patrón de pipeline mínimo *build → scan → sign → push → verify*.

Lo que **no** cubre (se verá después):

- Compliance Pipelines y approval rules de MR (gobernanza) → `gl-09`.
- Migración entre GHA y GitLab y catálogo CI/CD como golden path → `gl-10`.
- Infraestructura de un registry externo (Harbor, ECR) — este módulo se queda en el Registry nativo.

Este módulo es **mayoritariamente lectura + edición de YAML + validación estructural local**. No se ejecuta ningún pipeline en `gitlab.com`. Las dos actividades son independientes y validables sin red: la primera arma el `.gitlab-ci.yml` con los scanners, la segunda arma un pipeline de build/sign/push y lo documenta.

## Materiales

- **`theory/lesson.md`** — lección con 8 secciones (scanners, dashboard, widget, registry, package registry, SBOM, SLSA, cosign).
- **`examples/`** — tres ejemplos demostrativos (lectura; `include:template:` referencia a plantillas oficiales):
  - `01-enable-all-security-templates/` — `.gitlab-ci.yml` que habilita los 5+ templates oficiales con el *stage* `test` y variables mínimas.
  - `02-container-registry-push-and-cleanup/` — build con **Kaniko** (sin DinD), push a `$CI_REGISTRY_IMAGE`, y manifiesto de **cleanup policy** por tag regex.
  - `03-cosign-keyless-with-gitlab-oidc/` — firma de la imagen con `cosign sign --yes` usando `id_tokens:` con `aud: sigstore`, y verificación en un job posterior con `--certificate-identity`.
- **`activities/`** — dos actividades **independientes**:
  - `01-pipeline-with-scanners/` — produce `.gitlab-ci.yml` con 5+ `include:template:` de scanners nativos, stages consistentes y `rules:` para MR.
  - `02-sign-and-publish/` — produce `.gitlab-ci.yml` con jobs `build`, `sign` (cosign keyless + `id_tokens:`), `verify` y `README-INTENT.md` justificando SBOM/provenance.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre un *scanner job* (consume minutos) y una *managed app*; por qué el `include:template:` desacopla versión del scanner y del pipeline; qué garantiza *keyless* vs *key-based* en cosign. |
| Operativa | Habilitar 5+ scanners con 10 líneas de YAML; triagear 10 vulnerabilidades del Dashboard; configurar cleanup policy para `pr-*`. |
| Arquitectónica | Decidir qué scanners van *required* y cuáles *advisory*; dónde cortar en severidad para bloquear MR; cómo pinnar `project_path`+`ref` en la claim del ID Token para evitar impersonation. |

## Criterios de evaluación

- Dado un `.gitlab-ci.yml`, identificar qué scanners están activos y qué templates están incluidos.
- Leer un reporte SAST (CycloneDX / GitLab vulnerability report JSON) y explicar severidad y confianza.
- Justificar por qué `cosign` keyless con **ID Token** elimina credenciales de larga vida (no hay `COSIGN_KEY` que rotar).
- Nombrar al menos 5 scanners nativos y qué cubre cada uno.
- Entregar las dos actividades con el validador estructural en verde.

## Entregables

- `.gitlab-ci.yml` con 5+ scanners nativos (`gl-08-01`).
- `.gitlab-ci.yml` con pipeline *build → sign → push → verify* y `README-INTENT.md` (`gl-08-02`).

## Costos

**Ninguno** en Fase 3. Todo el módulo se desarrolla en local contra YAML y JSON. En una ejecución real:

- **gitlab.com SaaS runners**: cada job de scanner consume minutos del plan (Free da 400 min/mes, Premium 10 000, Ultimate 50 000 al momento de escribir — verificar vigencia).
- **Container Registry**: incluido con storage limitado por plan.
- **cosign keyless + Sigstore**: gratis (Sigstore es un servicio público; GitLab emite el ID Token sin coste).
- **Scanners Ultimate-only** (DAST, Fuzz, License Compliance con dashboard completo, SLSA provenance avanzada): requieren plan **Ultimate**.

## Siguiente módulo

→ `gl-09-compliance-approvals-and-governance` — Compliance Pipelines, approval rules de MR y audit events sobre esta base.
