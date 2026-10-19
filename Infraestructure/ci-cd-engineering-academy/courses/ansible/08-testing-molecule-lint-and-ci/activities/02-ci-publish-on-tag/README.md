# Actividad 02 — Workflow CI con matriz y publicación en Galaxy on tag

## 1. Identificación

- **ID:** `ans-08-02-ci-publish-on-tag`
- **Tecnología:** `ansible`
- **Módulo:** `ans-08-testing-molecule-lint-and-ci`
- **Dificultad:** advanced
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu role ya tiene Molecule y linters (actividad 01 u otro equivalente). Ahora falta el **CI**. Debes escribir un workflow de GitHub Actions que:

1. **Lint** (gate rápido).
2. **Molecule** sobre una **matriz** razonable (3 distros × 2 versiones de `ansible-core`), con `fail-fast: false`.
3. **Publicación** del role a **Ansible Galaxy** **solo** cuando se taggea un release SemVer (`vX.Y.Z`), usando `secrets.GALAXY_API_KEY`.

No vas a correr el workflow (no hay repo con GH Actions). El entregable es el **archivo YAML del workflow** y un **README justificando** las decisiones de diseño.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un workflow con tres jobs encadenados (`needs:`).
- Diseñar una matriz pequeña y legible (`strategy.matrix`).
- Condicionar un job a tags (`if: startsWith(github.ref, 'refs/tags/v')`).
- Consumir un secreto del repo (`${{ secrets.GALAXY_API_KEY }}`) sin exponerlo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §8 y `../../examples/03-gha-matrix-role-ci/`.
- Herramientas: `bash`, `python3` (si quieres parsear YAML localmente). Un editor.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-08-02/.github/workflows
cd /tmp/ans-08-02
```

### 5.2 Archivos a producir

```
/tmp/ans-08-02/
├── .github/workflows/role-ci.yml
└── CI-DESIGN.md
```

### 5.3 `role-ci.yml` — requisitos mínimos (validador)

- Clave `name:` presente.
- `on:` dispara en `push`, `pull_request` y `tags` que empiezan por `v`.
- Tres jobs: `lint`, `molecule`, `publish`.
- `molecule` tiene `needs: lint`.
- `publish` tiene `needs: molecule` **y** `if: startsWith(github.ref, 'refs/tags/v')`.
- `molecule` declara `strategy.matrix` con **al menos 3 entradas** en `distro:` **y al menos 2** en `ansible-core:`.
- `fail-fast: false`.
- `publish` usa `secrets.GALAXY_API_KEY` (sin exponerlo como `env` global).
- Se usa `actions/checkout@v4` y `actions/setup-python@v5` al menos una vez.

### 5.4 `CI-DESIGN.md` — requisitos mínimos

Secciones:

- `## Matriz` — qué distros y versiones elegiste y por qué.
- `## Gate de publicación` — por qué el tag SemVer y no cada push a `main`.
- `## Secretos` — cómo se gestiona `GALAXY_API_KEY` y por qué nunca va en el YAML.
- `## Caché` — qué cacheas (o por qué no cacheas) y por qué.

### 5.5 Entregable

```
/tmp/ans-08-02/.github/workflows/role-ci.yml
/tmp/ans-08-02/CI-DESIGN.md
```

## 6. Resultado esperado

- `bash tests/validate.sh /tmp/ans-08-02` reporta `0 issue(s)`.
- Un ingeniero externo lee tu `CI-DESIGN.md` y entiende por qué 3×2 y no 5×4.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: workflow parseable como YAML; secreto consumido correctamente.
- **Reproducibilidad**: cualquier role similar puede copiar este workflow con cambios mínimos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-08-02
```

El validador comprueba **estructura y claves mínimas** del workflow (no lo ejecuta — no hay runner).

## 9. Preguntas de reflexión

1. ¿Por qué `fail-fast: false` es casi obligatorio en una matriz de Molecule?
2. ¿Qué perderías si publicaras en cada push a `main` en vez de tras tag SemVer?
3. ¿Dónde pondrías el gate de "aprobación manual" si tu org lo pide para releases?
4. ¿Cómo probarías el workflow sin romper tu Galaxy real?
5. ¿Qué pasa si el `GALAXY_API_KEY` rota mientras hay un run en vuelo?

## 10. Extensiones

- Añade un job `release-notes` que lea el changelog y lo publique en el GH Release.
- Añade `environments:` con `required_reviewers` al job `publish`.
- Añade una celda extra de matriz con `ansible-core` nightly y márcala como `continue-on-error: true`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-08-02
```
