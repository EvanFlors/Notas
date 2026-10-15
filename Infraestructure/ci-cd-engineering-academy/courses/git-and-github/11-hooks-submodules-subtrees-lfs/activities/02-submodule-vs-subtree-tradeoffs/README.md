# Actividad 02 — Submodule vs Subtree: trade-offs + ADR

## 1. Identificación

- **ID:** `gh-11-02-submodule-vs-subtree-tradeoffs`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-11-hooks-submodules-subtrees-lfs`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent (architecture)

## 2. Contexto

Tu equipo mantiene `super-app` y depende de una librería interna `libgreet` (en un repo aparte). Debes:

1. **Construir** dos integraciones funcionales de `libgreet` en `super-app`:
   - Una versión con **submódulo**.
   - Una versión con **subtree**.
2. **Experimentar** con cada una: cómo se actualiza, cómo se clona, cómo se ve en `git ls-tree` y `git log`.
3. **Escribir un ADR** (`ADR.md`) comparando y recomendando una opción para un escenario concreto.

Es una actividad **independent (architecture)**: el valor está en el ADR argumentado, no en commands específicos.

## 3. Objetivos

Al terminar:
- Puedes crear un submódulo y un subtree desde cero sin consultar.
- Observas en vivo las diferencias de UX (`clone`, update, `ls-tree`, `log`).
- Produces un **ADR real** con decisión + consecuencias + alternativas descartadas.
- Puedes defender la recomendación en 2 minutos.

## 4. Prerrequisitos

- Git ≥ 2.30 con `git subtree` instalado (default en Git recientes).
- Haber leído `theory/lesson.md` secciones 2.2, 2.3, 4.3, 4.4, 8.2.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar el escenario base

```bash
bash starter/build-scenario.sh /tmp/adr-sub-vs-tree
cd /tmp/adr-sub-vs-tree
```

El script crea:
- `upstream/` → repo con `libgreet` (3 commits).
- `scratch/` → directorio donde harás tus dos super-repos.

### 5.2 Construir el super-repo con **submódulo**

```bash
cd /tmp/adr-sub-vs-tree/scratch
mkdir super-sub && cd super-sub
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
git -c user.name=You -c user.email=you@example.com add . && \
git -c user.name=You -c user.email=you@example.com commit -q -m "init: super"

git -c protocol.file.allow=always submodule add /tmp/adr-sub-vs-tree/upstream vendor/libgreet
git -c user.name=You -c user.email=you@example.com commit -q -m "chore: add libgreet as submodule"

# experimentos
git ls-tree HEAD vendor/
cat .gitmodules
git log --oneline
```

Experimentos sugeridos (anotalos en tu ADR):

- **A1**. Clona `super-sub` a `scratch/sub-reclone-naive` sin `--recurse-submodules`. ¿Qué pasa con `vendor/libgreet/`?
- **A2**. Haz un cambio en `upstream` (editar `greet.py`, commit allí). Vuelve a `super-sub`, haz `cd vendor/libgreet && git fetch && git checkout origin/main && cd ../.. && git add vendor/libgreet && git commit -m "bump"`. Mira el diff del commit.

### 5.3 Construir el super-repo con **subtree**

```bash
cd /tmp/adr-sub-vs-tree/scratch
mkdir super-tree && cd super-tree
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
git -c user.name=You -c user.email=you@example.com add . && \
git -c user.name=You -c user.email=you@example.com commit -q -m "init: super"

git subtree add --prefix=vendor/libgreet /tmp/adr-sub-vs-tree/upstream main --squash

git ls-tree HEAD vendor/
ls .gitmodules 2>&1    # debe decir "No such file"
git log --oneline
```

Experimentos sugeridos:
- **B1**. Clona `super-tree` a `scratch/tree-reclone`. ¿Qué pasa con `vendor/libgreet/`?
- **B2**. Haz otro cambio en `upstream` y propágalo con `git subtree pull --prefix=vendor/libgreet /tmp/adr-sub-vs-tree/upstream main --squash`.

### 5.4 Escribir el ADR

Crea `/tmp/adr-sub-vs-tree/ADR.md` siguiendo el formato de abajo. Debe tener **al menos estas secciones** (cada una, no vacía). El validador verifica que existan los encabezados y que el documento no sea trivial (≥ 1500 bytes útiles). También verifica que la decisión final esté marcada.

Formato requerido (encabezados exactos):

```markdown
# ADR-001: Submodule vs Subtree para libgreet

## Status
Accepted | Proposed | Deprecated | Superseded

## Context
<describe el escenario: tamaño del equipo, cadencia de release, grado de modificación esperado del upstream>

## Decision
<una de: "Use submodule" | "Use subtree" | "Use monorepo">

## Rationale
<explica por qué, en términos de los experimentos que hiciste; cita observaciones concretas>

## Consequences
### Positive
<lista>

### Negative
<lista>

## Alternatives considered
### Submodule
<por qué sí/no>

### Subtree
<por qué sí/no>

### Monorepo
<por qué sí/no>

## References
- Enlaces a tus observaciones de los experimentos A1, A2, B1, B2.
- `theory/lesson.md` §8.2.
```

### 5.5 Verifica que ambos super-repos funcionan

Ambos deben:
- Tener `vendor/libgreet/greet.py` presente (en el working tree de los repos originales — en los reclones depende del flavor).
- `git log --oneline` muestra al menos 2 commits.

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/adr-sub-vs-tree
```

## 6. Resultado esperado

- `/tmp/adr-sub-vs-tree/scratch/super-sub/` existe y es un repo con submódulo (mode `160000` en `vendor/libgreet`, `.gitmodules` tracked).
- `/tmp/adr-sub-vs-tree/scratch/super-tree/` existe y es un repo con subtree (`vendor/libgreet` como tree normal, sin `.gitmodules`).
- `/tmp/adr-sub-vs-tree/ADR.md` existe con los encabezados requeridos.
- La decisión final del ADR es una de: `Use submodule`, `Use subtree`, `Use monorepo`.

## 7. Criterios de aceptación

- [ ] Funcionalidad: ambos super-repos construidos y commits presentes.
- [ ] Calidad: ADR con secciones completas, no trivial, con rationale concreto.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes defender la decisión en 2 minutos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/adr-sub-vs-tree
```

Chequea:
- `scratch/super-sub` es un repo Git con un gitlink (mode `160000`) en `vendor/libgreet` y `.gitmodules` tracked.
- `scratch/super-tree` es un repo Git con `vendor/libgreet/greet.py` committed como blob (no gitlink) y **sin** `.gitmodules`.
- `ADR.md` existe, ≥ 1500 bytes, con los encabezados `## Status`, `## Context`, `## Decision`, `## Rationale`, `## Consequences`, `## Alternatives considered`, `## References`.
- Decisión declarada: contiene exactamente una de `Use submodule`, `Use subtree`, `Use monorepo`.

## 9. Preguntas de reflexión

1. En el reclon sin `--recurse-submodules` ¿qué viste en `vendor/libgreet/`? ¿Es un bug de Git o diseño intencional?
2. Al cambiar el upstream y propagar en cada modelo, ¿cuál dio menos fricción?
3. ¿Qué pasó con la historia del super-repo subtree frente al super-repo submódulo? ¿Qué pasa con `git bisect` a través de la frontera?
4. Si el upstream es público y vive en otra organización, ¿cambia tu elección?
5. ¿Cómo sería la respuesta si en lugar de 1 dependencia fueran 15? ¿La elección escala?
6. ¿En qué escenario preferirías pasar a monorepo en vez de ambos modelos?

## 10. Extensiones (opcional)

- **E1** — Construye un tercer super-repo "monorepo-style" copiando `libgreet` como código normal (sin submodule ni subtree). Añade `libgreet` como paquete Python (`pyproject.toml`). Compara.
- **E2** — Investiga `git-filter-repo` para migrar la historia de `libgreet` dentro de super-tree conservando commits originales.
- **E3** — Investiga alternativas: Google-style monorepo, Nx, Turborepo, Bazel. Añade una sección "If we grow 10x" al ADR.

## 11. Limpieza

```bash
rm -rf /tmp/adr-sub-vs-tree
```
