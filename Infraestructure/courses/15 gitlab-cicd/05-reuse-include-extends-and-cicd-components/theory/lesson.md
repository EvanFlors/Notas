# gl-05 — Lección: reutilización en GitLab CI/CD

> Objetivo: internalizar los tres mecanismos de reutilización (`extends`, `include`, **CI/CD Components**) y el criterio para elegir entre ellos. Trabajamos sobre YAML real, con la mirada puesta en pasar de duplicación a un contrato versionado.

---

## 1. Por qué existen tres mecanismos (y no uno)

Un `.gitlab-ci.yml` crece así, en la práctica:

1. **Un job.** Un `script:` con 10 líneas.
2. **Tres jobs casi iguales.** Lint, test, build; todos con `before_script` idéntico. Nace la duplicación.
3. **Dos pipelines distintos** (web + api) en el mismo proyecto, con las mismas tres etapas. Duplicación entre archivos.
4. **Cinco proyectos** del mismo grupo necesitan el mismo pipeline. Duplicación entre repos.
5. **Toda la org** debería estandarizar "cómo se construye y firma una imagen". Duplicación organizacional.

GitLab resuelve cada paso con una herramienta distinta, y usar la equivocada es el principal síntoma de un repo "con mala higiene de CI":

| Paso | Mecanismo correcto | Dónde vive |
|------|--------------------|------------|
| 2 (jobs iguales en 1 archivo) | **`extends:` sobre hidden job (`.base`)** | Dentro del mismo `.gitlab-ci.yml`. |
| 3 (varios archivos en 1 repo) | **`include: local:`** | Dentro del mismo repo. |
| 4 (varios repos del mismo grupo) | **`include: project:`** o **CI/CD Component** | Repo compartido del grupo. |
| 5 (toda la org, versionado) | **CI/CD Component en Catalog** | Repo publicado como componente. |

Los dos primeros resuelven duplicación. Los dos últimos resuelven **contrato**: qué entradas acepta, qué outputs produce, qué versión estás usando.

---

## 2. `extends:` — herencia local sobre hidden jobs

Un **hidden job** es un job cuyo nombre empieza con `.` (ej. `.base-build`). GitLab no lo ejecuta — es solo una plantilla reutilizable dentro del archivo.

```yaml
.base-node:
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths: [.npm/]

lint:
  extends: .base-node
  stage: test
  script: [npm run lint]

test:
  extends: .base-node
  stage: test
  script: [npm test]
```

Reglas que vale la pena memorizar:

- **Merge recursivo**, no sobrescritura ciega: los `variables:` del hijo se **mezclan** con los del padre; las listas (`script:`, `tags:`) sí se reemplazan.
- `extends:` acepta **lista** (`extends: [.base-node, .with-coverage]`). El orden importa: el último gana en conflictos de clave escalar.
- Un `extends:` puede encadenarse hasta **11 niveles** (límite duro del parser). En la práctica, >2 es olor a diseño.
- El hidden job vive en el **mismo archivo** (o uno incluido via `include:` previo).

Cuándo usarlo: duplicación dentro de un pipeline. Cuándo no: cuando necesitas compartir con otro proyecto.

---

## 3. `include:` — las cuatro variantes

### 3.1 `include: local:`

Trae otro YAML del **mismo repositorio**:

```yaml
include:
  - local: .gitlab/ci/jobs-test.yml
  - local: .gitlab/ci/jobs-build.yml
```

Útil para partir un `.gitlab-ci.yml` que ya pesa 400 líneas en archivos por responsabilidad.

### 3.2 `include: project:`

Trae YAML de **otro repo** del mismo GitLab (requiere permiso de lectura):

```yaml
include:
  - project: 'platform/ci-shared'
    ref: 'v1.4.0'
    file: '/jobs/node-pipeline.yml'
```

Puntos finos:

- **`ref:`** puede ser branch, tag o SHA. **Pinnear a tag o SHA** es obligatorio en producción (si usas `main`, cualquier push al repo compartido rompe pipelines ajenos).
- No tiene **contrato** de entradas: el YAML incluido depende de `variables:` que el consumidor define *implícitamente*. Es la mayor causa de fragilidad.

### 3.3 `include: remote:`

Trae YAML por HTTP(S) desde cualquier URL pública:

```yaml
include:
  - remote: 'https://example.com/ci/node.yml'
```

**Prácticamente deprecado para uso serio**: sin pin de versión, sin contrato, sin control de disponibilidad. Legado histórico que los CI/CD Components reemplazan.

### 3.4 `include: template:`

Trae templates oficiales que ship GitLab (lista en `lib/gitlab/ci/templates/`):

```yaml
include:
  - template: Jobs/Build.gitlab-ci.yml
  - template: Security/SAST.gitlab-ci.yml
```

Es el mecanismo que usan los scanners nativos (`gl-08`). Mantenidos por GitLab, versionados con la plataforma, no requieren pin.

### 3.5 Límites globales

- Máximo **150 includes** por pipeline (incluyendo transitivos).
- **100 KB** por archivo incluido tras expansion.
- Los `include:` se resuelven **antes** de evaluar `rules:` → no puedes "incluir condicionalmente" en función de variables del job.

---

## 4. CI/CD Components — el estándar moderno

Un **componente** es un repositorio GitLab que exporta uno o más templates versionados con un contrato explícito.

### 4.1 Estructura obligatoria del repo

```
my-component/
├── README.md                     # obligatorio (metadatos para Catalog)
├── templates/
│   ├── build.yml                 # 1 componente = 1 archivo .yml ...
│   └── scan/
│       └── template.yml          # ... o 1 componente = 1 directorio con template.yml
└── .gitlab-ci.yml                # pipeline de self-testing (recomendado)
```

Reglas:

- Un componente **debe** vivir en `templates/<nombre>.yml` o `templates/<nombre>/template.yml`.
- El `README.md` del repo es lo que verás en el CI/CD Catalog.
- Para publicar al **CI/CD Catalog**, el repo debe:
  - Tener descripción (`Project settings → General → Description`).
  - Estar marcado como **CI/CD Catalog resource** (`Settings → CI/CD → CI/CD Catalog resources`).
  - Haber publicado al menos un **tag SemVer** (`v1.0.0`, no `1.0.0`).

### 4.2 El contrato: `spec:inputs:`

```yaml
spec:
  inputs:
    image_tag:
      default: '20-alpine'
      description: 'Tag de la imagen node a usar.'
    coverage:
      type: boolean
      default: false
      description: 'Si true, exporta coverage report.'
    stage:
      default: 'test'
      options: ['test', 'quality']
---
'test-$[[ inputs.image_tag ]]':
  stage: $[[ inputs.stage ]]
  image: 'node:$[[ inputs.image_tag ]]'
  script:
    - npm ci
    - npm test
```

Puntos clave:

- El `spec:` va en un **primer documento YAML** (separado por `---`); el pipeline va en el segundo.
- Tipos soportados: `string` (default), `number`, `boolean`, `array`.
- `options:` fuerza enum. `regex:` valida por patrón. `description:` sale en el Catalog UI.
- Las referencias dentro del template se escriben **`$[[ inputs.X ]]`** (doble corchete, intercambio **en tiempo de include**, no en runtime como `$VAR`).

### 4.3 Consumo

```yaml
include:
  - component: 'gitlab.example.com/platform/ci-components/node-test@~latest'
    inputs:
      image_tag: '20'
      coverage: true
```

Formato del identificador:
```
<host>/<project-path>/<component-name>@<version>
```

Versiones aceptadas:

| Ref | Semántica | Cuándo usar |
|-----|-----------|-------------|
| `v1.2.3` | Tag SemVer inmutable | **Producción.** |
| `~latest` | Último tag SemVer publicado (no `main`) | Equipos que aceptan actualizaciones automáticas de patch/minor con pruebas. |
| `main` | `HEAD` de `main` | **Solo desarrollo del propio componente.** |
| SHA | Commit exacto | Debugging. |

---

## 5. SemVer para componentes

Reglas pragmáticas, no filosóficas:

- **MAJOR** (`v1 → v2`): cambios en `spec:inputs:` que rompen consumidores (quitar un input, cambiar el `type`, cambiar un `default` cuando el input no es obligatorio).
- **MINOR** (`v1.0 → v1.1`): nuevos inputs opcionales, nuevos jobs expuestos.
- **PATCH** (`v1.1.0 → v1.1.1`): fix de un bug sin cambiar el contrato.

Dos recomendaciones operativas:

1. **Publica el `vMAJOR` como alias** (`v1`) además del tag completo. Los consumidores que quieran "último compatible" apuntan a `v1`.
2. **No publiques breaking changes como PATCH jamás** — rompes a todo el que use `~latest`.

---

## 6. GitLab vs GitHub Actions — mapping del dominio

| GHA | GitLab |
|-----|--------|
| Composite Action | `extends:` + hidden job (local). Para cross-repo: componente. |
| Reusable Workflow (`uses: org/repo/.github/workflows/x.yml@v1`) | **CI/CD Component** (`include: component: host/path/name@v1`). |
| `workflow_call.inputs` | `spec:inputs:` (con tipos, `options`, `regex`). |
| Marketplace de GitHub Actions | **CI/CD Catalog** (interno al grupo o público). |
| Pin por SHA en una action pública | Pin por **tag SemVer** en un componente (los componentes públicos del Catalog **no permiten** pin por SHA desde el Catalog UI, aunque el `include:` sí). |

Diferencias que suelen sorprender:

- En GHA, `inputs.foo` se evalúa en runtime del workflow; en GitLab, `$[[ inputs.foo ]]` se **sustituye textualmente** al resolver el `include:`. No puedes usar expresiones runtime en el valor del input.
- Un componente **no puede** llamar a otro componente en cadena transitiva arbitrariamente (el límite de 150 includes aplica, pero además hay cuidado con los ciclos — GitLab aborta).
- No existe un `secrets:` block que se pase al componente como en GHA — los secretos se leen del contexto del proyecto consumidor (variables de grupo/proyecto, Vault via ID Token).

---

## 7. Árbol de decisión en 30 segundos

```
¿Duplicación dentro del mismo .gitlab-ci.yml?
└── Sí → extends: sobre hidden job.
¿Duplicación entre archivos del mismo repo?
└── Sí → include: local:
¿Duplicación entre proyectos del mismo grupo, pocos consumidores (<5)?
└── Sí → include: project: con ref: fijo a tag.
¿>5 consumidores o quieres cross-grupo o quieres contrato tipado?
└── Sí → CI/CD Component con spec:inputs: en el Catalog.
¿Scanner oficial de GitLab?
└── Siempre → include: template:
```

---

## 8. Olores comunes

1. **`include: remote:` con `main`**: fragilidad total. Migrar a componente o `include: project:` con tag.
2. **`extends:` de 5 niveles**: el lector no entiende qué hereda cada job. Aplanar o convertir a componente.
3. **Componente sin `spec:inputs:`**: no es un contrato, es un `include:project:` con pasos extra. Degrada a `include:project:` o añade inputs reales.
4. **Consumer que apunta a `main` del componente**: cualquier merge rompe builds ajenos. Pin a tag o `~latest`.
5. **Componente que depende de variables de entorno "mágicas" no documentadas** (`$CI_REGISTRY_IMAGE` usado sin advertencia): o lo documentas, o lo mueves a `inputs`.

---

## 9. Checklist antes de merge

- [ ] Si duplico un job dentro del mismo archivo, ¿puedo usar `extends:`?
- [ ] Si uso `include: project:`, ¿tengo `ref:` fijado a un tag inmutable?
- [ ] Si expongo un componente, ¿tiene `spec:inputs:` con `description:` y defaults razonables?
- [ ] ¿El componente tiene un `README.md` que explica qué hace y un ejemplo de uso?
- [ ] ¿Publiqué al menos un tag SemVer (`v1.0.0`), no un número suelto (`1.0.0`)?
- [ ] ¿El `~latest` apunta al último SemVer y no a un pre-release?

---

## 10. Referencias cruzadas

- `../examples/01-extends-hidden-job/` — refactor local con `extends:`.
- `../examples/02-include-local-vs-project/` — las 4 variantes de `include:` lado a lado.
- `../examples/03-cicd-component-publish-and-consume/` — anatomía del componente + consumer.
- `../activities/01-extract-component-from-pipeline/` — refactor de pipeline duplicado a componente.
- `../activities/02-adr-components-vs-includes/` — ADR comparativo para 3 escenarios.
- `gl-10` cubre la **gobernanza** del Catalog interno como plataforma.
