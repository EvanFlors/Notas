# gh-05 — GitHub: first contact

## Identificación

- **ID:** `gh-05-github-first-contact`
- **Curso:** `git-and-github`
- **Nivel:** fundamentos
- **Duración estimada:** 2–3 h
- **Prerrequisitos:** `gh-04-remotes-and-collaboration-basics`.

## Objetivo

Usar **GitHub** productivamente: crear cuenta y perfil, autenticarse (SSH / HTTPS+PAT / `gh auth`), crear repos (público/privado/interno), clonar, publicar un `README` y una licencia, y cortar un **release** etiquetado con artefactos opcionales. Al terminar deberías operar tus repos personales con higiene básica y poder justificar la elección entre los tres métodos de autenticación.

## Alcance

- Cuenta GitHub y higiene del perfil (nombre, email, 2FA).
- **Autenticación**: SSH keys (ed25519), Personal Access Tokens *classic* vs *fine-grained*, GitHub CLI `gh auth`.
- Crear repos: web UI y `gh repo create` (público, privado, interno).
- `clone` por SSH y por HTTPS.
- Licencias (`LICENSE`): MIT, Apache-2.0, GPL-3.0, Unlicense — cuándo elegir cuál.
- README y topics como "SEO" del repo.
- `.gitattributes` para corregir la detección de GitHub Linguist.
- Tags **ligeros** vs **anotados**; semver.
- GitHub **Releases**: qué son exactamente (un tag + metadata + artefactos opcionales), con `gh release create`.

Lo que **no** cubre (va después):
- Pull Requests y colaboración → `gh-07`.
- Branch protection, rulesets, environments → `gh-12`.
- Firma de commits/tags, OIDC, SBOM → `gh-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-ssh-setup/` — generar una ed25519, cargarla en GitHub y probar `ssh -T git@github.com`.
  - `02-first-release/` — tag anotado + `gh release create` con un asset.
- **`activities/`**:
  - `01-create-repo-and-push/` — guided-lab: crear repo (modo `live` con `gh` o `local` con bare remote), subir README + LICENSE + .gitignore.
  - `02-publish-first-release/` — guided-lab: etiquetar `v0.1.0` anotado, generar artefacto `.tar.gz`, publicarlo como release (modo `live` o `local`).
- **`resources/links.md`** — docs oficiales de GitHub.

## Modo `live` vs `local` en las actividades

Como este módulo **requiere GitHub** para la experiencia completa, cada actividad admite dos modos:

| Modo | Qué hace | Requiere |
|------|----------|----------|
| `MODE=live` (default) | Opera contra GitHub real con `gh` CLI | `gh auth status` OK |
| `MODE=local` | Simula el remoto con `--bare` y simula el release con un tag anotado + fichero de notas + artefacto en `releases/` | Nada (solo Git) |

Esto permite que el curso sea **ejecutable sin cuenta de GitHub** (ej. en CI) y a la vez enseñe la experiencia real cuando sí la hay.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar los tres métodos de auth (SSH / HTTPS+PAT / `gh`). Diferenciar PAT *classic* vs *fine-grained*. Describir qué es un release (tag + metadata + assets, no un commit "nuevo"). Explicar tag ligero vs anotado. |
| Operativa | Generar y cargar una SSH key `ed25519`. Crear un repo con `gh repo create` y con la UI. Clonar por SSH y HTTPS. Añadir LICENSE y README decente. Cortar un release anotado con `gh release create` y adjuntar assets. |
| Arquitectónica | Elegir y justificar un método de auth para cada contexto (dev humano, CI, bot). Elegir licencia OSS adecuada. Diseñar nombres y tags (`vMAJOR.MINOR.PATCH`) coherentes con *SemVer*. |

## Criterios de evaluación

- Un repo público en GitHub (o local, en modo `local`) con: `README.md` con secciones mínimas, `LICENSE` reconocible, `.gitignore`, al menos 1 commit "real".
- Un release etiquetado `v0.1.0` **anotado**, con release notes y al menos 1 asset `.tar.gz`.
- Respuesta argumentada a las 6–8 preguntas de evaluación de `theory/lesson.md`, incluyendo la elección SSH / HTTPS+PAT / `gh`.

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-ssh-setup/` (si tienes cuenta GitHub).
3. Haz `activities/01-create-repo-and-push/`.
4. Lee `examples/02-first-release/`.
5. Haz `activities/02-publish-first-release/`.
6. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `gh-06-rebase-vs-merge-and-interactive` (en paralelo también desbloquea `gh-07`).
