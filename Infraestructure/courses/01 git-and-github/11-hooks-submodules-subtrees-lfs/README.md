# gh-11 — Hooks, submódulos, subtrees y LFS

## Identificación

- **ID:** `gh-11-hooks-submodules-subtrees-lfs`
- **Curso:** `git-and-github`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gh-09-git-internals`.

## Objetivo

**Extender Git** con hooks (locales y de servidor) y **manejar casos especiales**: dependencias de código entre repos (submódulos vs subtrees vs monorepo) y archivos grandes/binarios (Git LFS, partial clone, sparse-checkout). Al terminar, deberías poder instrumentar un repo con `pre-commit`, elegir con criterio entre submodule/subtree/monorepo, y configurar LFS correctamente.

## Alcance

- **Hooks locales**: `pre-commit`, `commit-msg`, `pre-push` nativos en `.git/hooks/`.
- **Framework `pre-commit`** (Python package): por qué resuelve el problema de versionar hooks y cómo integrarlo (ruff, black, trufflehog, hooks nativos).
- **Hooks del servidor**: `pre-receive`, `update`, `post-receive` (concepto; GitHub los expone vía Actions/Rulesets, no se instalan a mano en SaaS).
- **Submódulos** (`git submodule`): qué es un gitlink, UX dura, cuándo usarlos.
- **Subtrees** (`git subtree`): merge estrategia, menos fricción para el consumidor, más historia local.
- **Monorepo** como tercera opción.
- **Git LFS**: filter clean/smudge, punteros vs blobs, `.gitattributes` con `filter=lfs`.
- **Sparse-checkout** y **partial clone** (`--filter=blob:none`) para repos enormes.
- **`git bundle`** para transporte offline.
- **`git maintenance` / Scalar** para repos grandes.

Lo que **no** cubre (va en otros módulos):
- Firma de commits y supply-chain security → `gh-13`.
- Branch protection / Rulesets → `gh-12`.
- CI con GitHub Actions como "hook del servidor" moderno → `gh-12`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-pre-commit-hook/` — hook nativo en `.git/hooks/pre-commit` que bloquea commits si hay `TODO` sin owner.
  - `02-submodule-vs-subtree/` — mismo "repo upstream" integrado dos formas, demo lado a lado.
- **`activities/`**:
  - `01-pre-commit-framework/` — **guided-lab**: instalar el framework y configurar 3 hooks útiles.
  - `02-submodule-vs-subtree-tradeoffs/` — **independent (architecture)**: construir ambos y escribir un ADR comparando.
  - `03-lfs-setup/` — **guided-lab**: configurar Git LFS para `*.bin` y verificar que el objeto committed es un puntero.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `.git/hooks/` no se versiona por default y cómo `pre-commit` lo soluciona (hooks declarativos en `.pre-commit-config.yaml`). Entender qué es un **gitlink** (entrada mode `160000` apuntando a un SHA de otro repo). Explicar la diferencia conceptual entre un submódulo (puntero externo) y un subtree (contenido copiado + historia opcional). Describir cómo LFS reemplaza blobs grandes con **punteros** usando los filtros `smudge`/`clean`. |
| Operativa | Escribir un `pre-commit` nativo y configurar el framework con 3+ hooks (ruff, black o similar). Añadir, actualizar y clonar un repo con submódulos sin romper nada. Hacer `git subtree add/pull`. Instalar y configurar Git LFS para un patrón de archivos. Usar `--filter=blob:none` + sparse-checkout en repos grandes. |
| Arquitectónica | Elegir entre **submodule / subtree / monorepo** justificando con el eje acoplamiento × velocidad × herramientas. Decidir qué archivos ir a LFS vs qué sacar del repo entero (releases, artifact store). Diseñar un conjunto de hooks que capturen errores locales **antes** del CI. |

## Criterios de evaluación

- Repo con `.pre-commit-config.yaml` corriendo ≥ 3 hooks (uno de ellos no trivial, p.ej. formateador o detector de secretos).
- ADR documentando la elección submodule/subtree/monorepo para un escenario específico.
- Repo con LFS configurado, `.gitattributes` correcto, un archivo binario commiteado como puntero (verificable con `git cat-file -p HEAD:<archivo>`).
- Respuesta argumentada a las 7 preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-pre-commit-hook/`.
3. Haz `activities/01-pre-commit-framework/` (guided).
4. Reproduce `examples/02-submodule-vs-subtree/`.
5. Haz `activities/02-submodule-vs-subtree-tradeoffs/` (independent — redacta el ADR).
6. Haz `activities/03-lfs-setup/` (guided). Si no tienes `git-lfs` instalado, el validador te lo dirá y puedes saltarlo o instalarlo.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `gh-12-github-governance-and-automation`.
