# Ejemplo 03 — CI/CD Component: publicar y consumir

> Lectura y análisis. Objetivo: ver la **estructura obligatoria** de un componente, el bloque `spec:inputs:` y cómo lo consume otro pipeline.

## 1. Estructura del repositorio del componente

Repo imaginario: `platform/ci-components` (publicado al Catalog del grupo `platform`).

```
platform/ci-components/
├── README.md                           # metadatos para el Catalog
├── .gitlab-ci.yml                      # self-test del propio componente
└── templates/
    └── node-test/
        └── template.yml                # el componente propiamente dicho
```

Formatos aceptados por GitLab:

- `templates/<name>.yml` — componente simple.
- `templates/<name>/template.yml` — componente con archivos auxiliares (scripts, defaults).

Ambos exponen el componente como `<host>/<project-path>/<name>`.

## 2. El template con contrato (`spec:inputs:`)

`templates/node-test/template.yml`:

```yaml
spec:
  inputs:
    node_version:
      default: '20'
      description: 'Major de Node a usar (ej. 18, 20, 22).'
    coverage:
      type: boolean
      default: false
      description: 'Si true, exporta coverage/ como artifact.'
    stage:
      default: 'test'
      description: 'Stage en el que correr el job.'
    runner_tag:
      default: 'saas-linux-small-amd64'
      options:
        - 'saas-linux-small-amd64'
        - 'saas-linux-medium-amd64'
      description: 'Tag del runner.'
---
'node-test:$[[ inputs.node_version ]]':
  stage: $[[ inputs.stage ]]
  image: 'node:$[[ inputs.node_version ]]-alpine'
  tags: ['$[[ inputs.runner_tag ]]']
  before_script:
    - npm ci --cache .npm --prefer-offline
  script:
    - |
      if [ "$[[ inputs.coverage ]]" = "true" ]; then
        npm test -- --coverage
      else
        npm test
      fi
  artifacts:
    when: always
    paths:
      - coverage/
    expire_in: 7 days
```

Puntos clave:

1. **Dos documentos YAML** separados por `---`: el `spec:` arriba, el pipeline abajo.
2. **`$[[ inputs.X ]]`** se expande en el momento del `include:` (textualmente), no en runtime.
3. **Tipos**: `string` (default), `number`, `boolean`, `array`.
4. **`options:`** restringe a enum. **`regex:`** valida con patrón. **`default:`** hace el input opcional.
5. El `name` del job puede incluir inputs → útil para evitar colisiones en matrices.

## 3. `README.md` del componente (lo que verá el Catalog)

```markdown
# node-test

Componente que corre `npm test` sobre una imagen oficial de Node.

## Uso

\`\`\`yaml
include:
  - component: 'gitlab.example.com/platform/ci-components/node-test@~latest'
    inputs:
      node_version: '22'
      coverage: true
\`\`\`

## Inputs

| Nombre | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| node_version | string | '20' | Major de Node (18, 20, 22). |
| coverage | boolean | false | Exporta coverage/ como artifact. |
| stage | string | 'test' | Stage del job. |
| runner_tag | string | 'saas-linux-small-amd64' | Tag del runner. |

## Compatibilidad

- GitLab >= 16.6 (requiere componentes GA).
- Testeado contra Node 18, 20, 22.
```

## 4. Publicación al Catalog

Pasos operativos (los veremos a fondo en `gl-10`):

1. **Descripción** del proyecto (`Settings → General`).
2. **Marcar como CI/CD Catalog resource** (`Settings → CI/CD → CI/CD Catalog resources`).
3. **Tag SemVer**: `git tag v1.0.0 && git push --tags`.
4. GitLab indexa automáticamente; aparece en `https://<host>/explore/catalog`.

Importante:

- El tag **debe** empezar con `v` (`v1.0.0`, no `1.0.0`).
- Un componente privado del grupo requiere que el consumidor tenga permiso de lectura al proyecto del componente.

## 5. El consumidor

Repo `apps/web-frontend/.gitlab-ci.yml`:

```yaml
stages: [test, build]

include:
  - component: 'gitlab.example.com/platform/ci-components/node-test@v1.0.0'
    inputs:
      node_version: '22'
      coverage: true

build:
  stage: build
  image: node:22-alpine
  script: [npm run build]
  needs: ['node-test:22']
  artifacts:
    paths: [dist/]
```

Resultado: el pipeline tendrá `node-test:22` (del componente) + `build` (local), con `needs:` apuntando al nombre expandido del componente.

## 6. SemVer en vivo

| Cambio | Nueva versión | Por qué |
|--------|---------------|---------|
| Añadir input opcional `custom_registry` | `v1.1.0` | MINOR: no rompe consumidores. |
| Cambiar `node_version` default de `'20'` a `'22'` | `v2.0.0` | MAJOR: altera comportamiento silenciosamente. |
| Fix: `expire_in` pasa de `7 days` a `30 days` por typo | `v1.0.1` | PATCH: bug fix. |
| Quitar input `runner_tag` | `v2.0.0` | MAJOR: contrato roto. |

## 7. Diferencia con `include: project:`

Mismo YAML, dos mundos:

```yaml
# include: project — sin contrato, el consumidor "adivina" las variables
include:
  - project: 'platform/ci-components'
    ref: 'v1.0.0'
    file: '/templates/node-test/template.yml'
variables:
  NODE_VERSION: '22'    # ¿esta variable existe? ¿se llama así?

# include: component — contrato explícito, errores de input se detectan al parse
include:
  - component: 'gitlab.example.com/platform/ci-components/node-test@v1.0.0'
    inputs:
      node_version: '22'    # falla visible y clara si el input no existe
```

El componente **falla con error legible** si pasas un input que no existe, un tipo incorrecto o te saltas uno obligatorio. `include: project:` falla con un `undefined variable` 3 jobs después.

## 8. Qué leer después

- `../../activities/01-extract-component-from-pipeline/` — extraer un componente de un pipeline duplicado.
- `../../activities/02-adr-components-vs-includes/` — defender la elección por escrito.
- `gl-10` cubre gobernanza del Catalog como plataforma interna.
