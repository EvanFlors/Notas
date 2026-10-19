# Ejemplo 01 — `extends:` sobre hidden jobs

> Lectura y análisis. Sin ejecución. Objetivo: ver un pipeline **antes** y **después** de aplicar `extends:` y entender el merge recursivo.

## 1. El pipeline duplicado (antes)

```yaml
# .gitlab-ci.yml (antes)
stages: [test, build]

lint:
  stage: test
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths: [.npm/]
  script: [npm run lint]

unit:
  stage: test
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths: [.npm/]
  script: [npm test -- --coverage]

build:
  stage: build
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths: [.npm/]
  script: [npm run build]
```

Los tres jobs comparten `image`, `before_script` y `cache`. 24 líneas, 12 de ruido.

## 2. El pipeline refactorizado (después)

```yaml
# .gitlab-ci.yml (después)
stages: [test, build]

.base-node:
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths: [.npm/]

lint:
  extends: .base-node
  stage: test
  script: [npm run lint]

unit:
  extends: .base-node
  stage: test
  script: [npm test -- --coverage]

build:
  extends: .base-node
  stage: build
  script: [npm run build]
```

16 líneas. La intención ("estos jobs son node") se expresa en el nombre `.base-node`.

## 3. Qué fusiona `extends:` y qué no

| Clave | Comportamiento |
|-------|----------------|
| `image`, `stage`, `tags` (escalares/listas simples) | El hijo **reemplaza** al padre si lo redefine. |
| `variables:` (mapping) | **Merge** clave a clave; el hijo gana en conflicto. |
| `cache:`, `artifacts:`, `rules:`, `before_script:` | **Reemplazo** completo si el hijo los define — el hijo no "amplía" la lista del padre. |

Error típico: pensar que `before_script:` del hijo se concatena al del padre. **No se concatena.** Si quieres añadir pasos, redefines el `before_script:` completo (copiando los del padre) o separas los pasos comunes a un script externo.

## 4. Encadenar con lista

```yaml
.with-coverage:
  variables:
    COVERAGE: "true"
  artifacts:
    paths: [coverage/]

unit:
  extends: [.base-node, .with-coverage]
  stage: test
  script: [npm test -- --coverage]
```

Orden de la lista = orden de aplicación. En conflictos de clave escalar, **el último gana**.

## 5. Límites

- Profundidad máxima: 11 niveles de `extends:` encadenados.
- Un hidden job solo es "hidden" si empieza con `.`; cualquier otro nombre lo lanza como job real.
- Un hidden job referenciado por `extends:` **debe** existir en el mismo YAML tras resolver los `include:`.

## 6. Cuándo NO usar `extends:`

- Si la plantilla la necesita **otro proyecto**: salta a componente o `include: project:`.
- Si el `.base-node` ya tiene `rules:` y 3 hijos lo redefinen, pierdes legibilidad; mejor dos hidden jobs distintos (`.base-node-mr`, `.base-node-main`).
- Si el `.base-*` tiene lógica condicional compleja: el merge recursivo no interpreta condicionales, solo mezcla claves.

## 7. Qué leer después

- `../02-include-local-vs-project/` — qué cambia cuando el hidden job ya no cabe en un solo archivo.
- `../03-cicd-component-publish-and-consume/` — qué cambia cuando el hidden job tiene que vivir en otro repo con contrato.
