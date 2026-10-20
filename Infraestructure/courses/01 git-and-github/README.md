# Curso: Git & GitHub

Roadmap especializado #1 del programa. Base indispensable para todos los cursos posteriores de CI/CD.

## 1. Introducción

### Qué es

**Git** es un sistema de control de versiones distribuido (DVCS) orientado a contenido: no versiona archivos, versiona *snapshots inmutables* de árboles de archivos identificados por el hash SHA-1 (SHA-256 opcional desde 2020) de su contenido. Toda la historia vive en un **grafo acíclico dirigido (DAG)** de commits, y cada clon es un repositorio completo con historia íntegra.

**GitHub** es una plataforma SaaS construida sobre Git que añade: hosting de repositorios, colaboración social (pull requests, issues, discussions), control de acceso, CI/CD (GitHub Actions), paquetes (GHCR), gestión de identidades (SSO, SAML), seguridad (Dependabot, code scanning, secret scanning) y automatización (API REST/GraphQL, webhooks, Apps).

Son dos cosas distintas: **puedes usar Git sin GitHub** (GitLab, Bitbucket, Gitea, Forgejo, servidor propio) y aprender a distinguirlas conceptualmente es parte del curso.

### Historia (síntesis)

- **2005** — Linus Torvalds crea Git tras la ruptura entre el kernel de Linux y BitKeeper. Diseñado para: velocidad, operación distribuida, integridad criptográfica, soporte de workflows no-lineales.
- **2008** — GitHub lanza como hosting Git centrado en comunidad (Pull Request como primitiva social).
- **2018** — Microsoft adquiere GitHub.
- **2019+** — GitHub Actions (CI/CD nativo), Codespaces, Copilot, etc.
- **2020** — Git introduce soporte experimental para SHA-256 como función hash.

### Problemas que resuelve

- **Historia reproducible y auditable** del código.
- **Colaboración concurrente** sin bloqueos pesimistas.
- **Branching barato** que habilita trunk-based development, feature flags, release branches.
- **Trazabilidad**: cada cambio ligado a autor, fecha, mensaje y padres.
- **Integridad**: cualquier modificación de la historia cambia los hashes y es detectable.

### Casos de uso

- Repositorio fuente de código, infraestructura (IaC), documentación y configuración.
- Fuente de verdad para GitOps.
- Mecanismo de distribución (`go get`, Terraform modules, Helm charts vía OCI, etc.).
- Automatización reactiva a eventos (push, PR, release) vía webhooks → CI.

### Arquitectura general

Git tiene **tres áreas lógicas** (`working tree` → `index`/staging → `repository`) y una base de datos de objetos tipada:

- `blob` — contenido de archivo.
- `tree` — directorio (nombres + modos + hashes).
- `commit` — snapshot (apunta a un tree) + metadatos + padres.
- `tag` — referencia anotada con metadata.

Las **refs** (`refs/heads/<branch>`, `refs/tags/<tag>`, `refs/remotes/<remote>/<branch>`, `HEAD`) son punteros móviles al grafo. El **packfile** comprime y deltas los objetos para eficiencia.

GitHub añade sobre esto: una capa de identidad, políticas (branch protection, rulesets), objetos sociales (issues, PRs, reviews, projects) y un plano de automatización (Actions, Apps, webhooks).

### Alternativas

- **DVCS**: Mercurial (en declive), Fossil, Pijul (teoría de parches), Jujutsu (`jj`, frontend de Git más moderno).
- **Hosting**: GitLab (self-host competitivo, CI integrado), Bitbucket, Gitea/Forgejo (ligeros, auto-hospedables), AWS CodeCommit (deprecado para nuevos clientes).

### Ventajas / limitaciones

**Ventajas**: ubicuidad, ecosistema, operación offline, modelo mental consistente, integridad criptográfica.

**Limitaciones y trampas**:
- Rendimiento con binarios grandes y repos muy grandes (mitigado por **Git LFS**, partial/sparse clone, **Scalar**).
- La UX de la CLI es inconsistente histórica (razón de la existencia de `jj` y otros frontends).
- Submódulos tienen UX áspera; alternativas: subtrees o monorepos.
- SHA-1 ya no se considera seguro criptográficamente pero sigue siendo el default; mitigación con detección anti-colisión (`sha1dc`) y migración incremental a SHA-256.

### Relación con el programa

- Fundamento directo de **D5 (CI/CD)**: todo pipeline reacciona a eventos Git.
- Fundamento de **GitOps** (D8): el repo Git es la fuente de verdad de la infraestructura.
- Pieza de la **supply chain security** (D9): firma de commits y tags, provenance.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Nociones básicas de línea de comandos (navegación, edición de texto). Un editor de código. |
| Recomendados | T-2.6 (Bash básico), T-1.1 (SDLC). |
| Complementarios | T-2.4 (permisos y filesystem) para entender hooks y permisos en `.git/`. |

## 3. Organización (4 niveles)

El curso tiene **13 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5 módulos): instalación, modelo mental, uso diario local, branching básico, remotos.
- **Nivel 2 — Intermedio** (3 módulos): colaboración (PRs, review), rebase vs merge, workflows (trunk-based, GitHub Flow).
- **Nivel 3 — Avanzado** (3 módulos): internals (objetos, refs, packfiles), recuperación (reflog, bisect), hooks, submódulos/subtrees, LFS, sparse/partial clone.
- **Nivel 4 — Producción empresarial** (2 módulos): gobernanza en GitHub (branch protection, rulesets, CODEOWNERS, environments, SSO/SAML), seguridad (firma de commits, Dependabot, code/secret scanning, OIDC para CI, SBOM/attestations).

## 4. Entregables del curso

- Repositorio personal con historia limpia que ilustra cada técnica.
- Un repositorio-sandbox roto donde practicar `reflog`, `bisect`, `cherry-pick`, resolución de conflictos.
- Un repositorio en GitHub con: branch protection configurado, CODEOWNERS, PR template, Dependabot, secret scanning, firma de commits con SSH key, environment con approval.
- Documento de decisión personal: qué workflow (trunk-based / GitHub Flow / release branches) elegirías para distintos escenarios y por qué.

## 5. Evaluación

- **Conceptual**: explicar qué es un commit, por qué `git rebase` reescribe historia, qué hace `git reset --soft/--mixed/--hard`, qué diferencia a `fetch` de `pull`, por qué el push de una historia reescrita puede ser destructivo.
- **Operativa**: recuperar commits "perdidos" con `reflog`, encontrar el commit que introduce un bug con `bisect`, resolver un conflicto complejo, hacer un rebase interactivo con `fixup` y `squash`.
- **Arquitectónica**: elegir y justificar un modelo de ramas y de release para un equipo dado, diseñar una política de branch protection coherente con el flujo de release, decidir cuándo introducir submódulos, subtrees o monorepo.

## 6. Recursos

A verificar y referenciar en Fase 4; aquí la lista base:

- *Pro Git* (Scott Chacon, Ben Straub) — libro oficial, 2.ª ed.
- Documentación oficial: `git-scm.com/doc` y `docs.github.com`.
- *Git Internals* (ch. 10 de Pro Git) para el modelo de objetos.
- Reference de GitHub Rulesets y branch protection.
- Especificación de SemVer: `semver.org`.
