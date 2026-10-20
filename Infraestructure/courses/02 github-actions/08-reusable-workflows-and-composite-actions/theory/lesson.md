# Lección: Reusable workflows y composite actions

> **ID:** `gha-08-reusable-workflows-and-composite-actions` · **Nivel:** intermedio · **Duración:** 5 h
> **Prerrequisitos:** `gha-06-matrix-dependencies-outputs`.

---

## 1. Introducción intuitiva

Tienes **tres repos**. Los tres hacen una app Python y en los tres el workflow de CI empieza así:

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'
- run: pip install poetry
- run: poetry install --no-interaction --no-root
```

Mañana el equipo decide que Poetry pasa a versión 1.8 pinneada, que `pip` debería ser `pipx install`, y que hay que correr `poetry check` antes de `install`. Son **12 líneas** nuevas. Son **tres PRs** idénticas, en tres repos.

La próxima iteración son **ocho repos**. Y para ese entonces ya hay deriva: alguien actualizó dos de los ocho a Python 3.13 y "se olvidó" del resto.

Este módulo trata exactamente de ese problema. GitHub ofrece **dos mecanismos** para evitarlo:

1. **Composite actions** — empaquetas una secuencia de *steps* como una "action" propia (`action.yml`). El caller la invoca con `uses:`. Se **expande dentro del job** que la llama: comparte runner, env, filesystem.
2. **Reusable workflows** — defines un workflow completo con `on: workflow_call` que acepta `inputs`, `secrets` y expone `outputs`. El caller lo invoca como un *job* (`jobs.x.uses: owner/repo/.github/workflows/x.yml@v1`). Corre en **jobs propios con sus propios runners**.

No son intercambiables. Cuál usar depende de qué estás reutilizando, cuánta aislación necesitas, y cuánto coste de minutos estás dispuesto a pagar.

---

## 2. Fundamentos

### 2.1 El modelo mental: step vs job

Repasemos la jerarquía de un workflow:

```
workflow (archivo YAML)
  └── job (una VM = un runner)
        └── step (un comando o action)
```

Un **step** vive **dentro** de un job, en el mismo runner. Un **job** es la unidad de aislamiento: distinto runner, distinto filesystem, distinto proceso.

Esta jerarquía es la clave para entender la diferencia:

- **Composite action** = empaquetar varios *steps*. Vive **dentro de un job existente**.
- **Reusable workflow** = empaquetar uno o más *jobs*. Es un workflow entero invocado desde otro.

```
Caller workflow                           Caller workflow
┌──────────────────────────┐              ┌──────────────────────────┐
│ job: ci                  │              │ job: ci (uses reusable)  │
│   runner: ubuntu-latest  │              │   ...                    │
│   steps:                 │              │ job: deploy              │
│     ─ uses: ./my-comp    │  ───vs───    │   uses: shared/.../x@v1  │
│         (expands here:   │              │   with:                  │
│          step a          │              │     environment: prod    │
│          step b          │              │   secrets: inherit       │
│          step c)         │              │   (corre en OTRO runner) │
│     ─ run: tests         │              │                          │
└──────────────────────────┘              └──────────────────────────┘
```

### 2.2 Qué comparte y qué no

| Aspecto | Composite | Reusable workflow |
|---------|-----------|-------------------|
| Runner | Comparte con el job caller | Runner propio por cada job del reusable |
| Filesystem (checkout, caches) | Comparte | **No**: si el reusable necesita el repo, hace su propio `checkout` |
| Variables de entorno (`env:` del job) | Las ve | **No**: ambiente propio |
| `GITHUB_TOKEN` permissions | Las del job caller | Las declaradas en el reusable (y acotadas por el token del repo caller) |
| Secrets | Los del repo (contexto del job caller) | **Solo** los pasados explícitamente, o todos si `secrets: inherit` |
| Minutos consumidos | Cero adicionales (ya estás en el job) | Suma minutos de cada job del reusable |
| Logs en UI | Pasos del composite listados dentro del job caller | Jobs del reusable **separados** en la UI |

Esta tabla es la que debes memorizar antes de decidir cuál usar.

### 2.3 `uses:` tiene tres formas

Según qué estás invocando y desde dónde:

```yaml
# 1. Action del marketplace (público):
- uses: actions/checkout@v4

# 2. Action/composite local al mismo repo (requiere actions/checkout antes):
- uses: ./.github/actions/setup-env

# 3. Action/composite en otro repo:
- uses: owner/repo@v1
- uses: owner/repo/path/to/action@abc1234...   # subdirectorio, pin SHA

# 4. Reusable workflow en otro repo (atención: formato distinto, nivel job):
jobs:
  call:
    uses: owner/repo/.github/workflows/deploy.yml@v1
```

Las formas 1–3 son `uses:` **a nivel step**. La forma 4 es `uses:` **a nivel job**, apunta a un archivo `.yml` dentro de `.github/workflows/`, y **no puede combinarse** con `steps:` en el mismo job.

---

## 3. Contexto histórico

- **2020** — Composite actions llegan en beta: solo podían ser otros `uses:`, no shell commands. Útil pero limitado.
- **2021 Q3** — Composite actions aceptan **`run:` steps nativos** (shell). Esto hace que una composite se vuelva una herramienta de verdad.
- **2021 Q4** — Reusable workflows (GA, octubre). `workflow_call` nace como primer-class citizen.
- **2022** — `secrets: inherit` (antes había que pasar cada secret manualmente, un dolor). Soporte para `outputs` entre reusable y caller.
- **2023** — Reusable workflows pueden llamar a otros reusable workflows, hasta **4 niveles de profundidad**. Starter workflows a nivel org.
- **2024** — `required workflows` evoluciona a repository rules / rulesets a nivel org (ver `gha-15`).

Antes de 2021, la única forma de reutilizar lógica entre repos era publicar una **JS action** o una **Docker action**, lo cual exigía setup real (Node, Dockerfile). Composite + reusable bajaron radicalmente la barrera.

---

## 4. Funcionamiento interno

### 4.1 Anatomía de una composite action

```yaml
# action.yml  (en la raíz de la action, o un subdir)
name: 'Setup Python + Poetry'
description: 'Install a given Python version plus Poetry with caching'

inputs:
  python-version:
    description: 'Python version'
    required: false
    default: '3.12'
  poetry-version:
    description: 'Poetry version'
    required: false
    default: '1.8.3'

outputs:
  venv-path:
    description: 'Path to the created virtualenv'
    value: ${{ steps.where.outputs.venv }}

runs:
  using: 'composite'                 # <-- clave: declara que es composite
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}
        cache: 'pip'

    - name: Install Poetry
      shell: bash                     # <-- OBLIGATORIO en cada run: dentro de composite
      run: |
        pip install "poetry==${{ inputs.poetry-version }}"
        poetry --version

    - name: Install deps
      shell: bash
      run: poetry install --no-interaction --no-root

    - id: where
      shell: bash
      run: echo "venv=$(poetry env info --path)" >> "$GITHUB_OUTPUT"
```

Claves no obvias:

- **`runs.using: 'composite'`** — sin esto, no es composite. Hay también `node20` (JS) y `docker` (ver `gha-12`).
- **`shell:` es obligatorio en cada `run:` dentro de un composite**. En un workflow normal, `shell: bash` es el default implícito; en composite, debes decirlo. Omitirlo falla el parse.
- **`inputs.*` se referencian con `${{ inputs.* }}`**, no `${{ github.event.inputs.* }}` (que es para `workflow_dispatch`).
- **`outputs` requieren un `value:`**, usualmente apuntando a un `steps.<id>.outputs.<name>`. El step que lo produce usa `echo "key=val" >> "$GITHUB_OUTPUT"` (patrón heredado de `gha-06`).
- **El job caller sigue dueño del runner, del `env:`, y de `permissions:`**. La composite no puede escalar permisos del `GITHUB_TOKEN` por sí sola.

### 4.2 Anatomía de un reusable workflow

```yaml
# .github/workflows/deploy.yml  (en el repo "shared")
name: Reusable deploy

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target env (staging | prod)'
        required: true
        type: string
      image-tag:
        description: 'Docker image tag to deploy'
        required: true
        type: string
      timeout-seconds:
        required: false
        type: number
        default: 300
    secrets:
      DEPLOY_TOKEN:
        description: 'Deploy API token'
        required: true
    outputs:
      deployment-url:
        description: 'URL of the resulting deployment'
        value: ${{ jobs.deploy.outputs.url }}

permissions:
  contents: read            # scope del GITHUB_TOKEN que recibe este reusable

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.push.outputs.url }}
    steps:
      - id: push
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}
          IMAGE: ${{ inputs.image-tag }}
          ENV:   ${{ inputs.environment }}
        run: |
          # (demo) imprime y publica una URL ficticia como output
          url="https://${ENV}.example.com/releases/${IMAGE}"
          echo "Deploying $IMAGE to $ENV using token ***"
          echo "url=$url" >> "$GITHUB_OUTPUT"
```

Y el caller:

```yaml
# .github/workflows/ci.yml  (en el repo "client")
name: CI
on: [push]

jobs:
  call-deploy:
    uses: my-org/shared-workflows/.github/workflows/deploy.yml@v1
    with:
      environment: staging
      image-tag: sha-${{ github.sha }}
    secrets:
      DEPLOY_TOKEN: ${{ secrets.STAGING_DEPLOY_TOKEN }}

  announce:
    needs: call-deploy
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deployed to ${{ needs.call-deploy.outputs.deployment-url }}"
```

Claves no obvias:

- **`inputs.*.type` es obligatorio** en reusable workflows (no así en composite). Tipos: `string`, `number`, `boolean`.
- **`secrets.*` se declaran** en el reusable y se **pasan explícitamente** en el caller. Alternativa: `secrets: inherit` en el caller (pasa todos los secrets del repo caller al reusable — útil pero amplio).
- **Los `outputs` del reusable** se propagan desde un `outputs:` a nivel job, que a su vez viene de un `$GITHUB_OUTPUT` de un step. Es una cadena de dos saltos.
- **`uses:` a nivel job no admite `steps:`** en el mismo job. Para hacer algo antes/después, usa jobs separados con `needs:`.

### 4.3 Resolución de la referencia `@ref`

El `@ref` en `uses: owner/repo/...@ref` puede ser:

- Un **tag** (`@v1`, `@v1.2.3`): mutable (los tags son refs; se pueden reescribir — el riesgo que vimos en `gha-04`).
- Una **rama** (`@main`): extremadamente mutable, mala práctica para producción.
- Un **commit SHA** (`@abc1234...56`, los 40 caracteres o un prefijo largo): inmutable. Patrón recomendado para seguridad.

Convención común:

- Para consumo **interno** de confianza (misma org): `@v1` que avanza. Buena ergonomía.
- Para consumo **cross-org / supply chain crítica**: `@<SHA>` con comentario `# v1.2.3`.

El trabajo de mantener `@v1` apuntando al último SHA de la major se automatiza con la action [`actions/publish-action`](https://github.com/actions/publish-action) o con un workflow propio (ver `gha-12`).

### 4.4 Límites duros (importantes)

- **Profundidad máxima de reusable workflows**: 4 niveles. Es decir, `A` llama a `B` llama a `C` llama a `D` está bien; agregar un `E` falla.
- **Composite dentro de composite**: también limitado a profundidad 10 (más generoso, en la práctica no suele dolerte).
- **Máximo 10 inputs y 10 outputs por reusable workflow / composite action**. Si llegas, probablemente la abstracción está mal diseñada (una "action god").
- **`matrix:` no se puede aplicar al nivel de un reusable workflow caller directamente**, pero sí al job que lo invoca (sí, es consistente aunque confunda al principio).
- **`env:` del caller no se propaga al reusable**. Debes pasar como `inputs:` lo que necesites.
- **El `GITHUB_TOKEN` del reusable** está acotado por los permisos del workflow caller: nunca puede ser *más* amplio que `permissions:` del caller.

### 4.5 `secrets: inherit` vs lista explícita

```yaml
# Explícito (preferible — explica qué necesita):
jobs:
  deploy:
    uses: my-org/shared/.github/workflows/deploy.yml@v1
    secrets:
      DEPLOY_TOKEN: ${{ secrets.STAGING_DEPLOY_TOKEN }}
      API_KEY:      ${{ secrets.STAGING_API_KEY }}

# Inherit (cómodo, pero poco auditable):
jobs:
  deploy:
    uses: my-org/shared/.github/workflows/deploy.yml@v1
    secrets: inherit
```

`inherit` pasa **todos** los secrets del repo caller al reusable. Dos riesgos:

1. **Supply-chain**: si el reusable es de otra org y comprometen esa org, el reusable comprometido tiene acceso a todos tus secrets.
2. **Auditoría**: nadie que mire el caller sabe qué secrets realmente consume el reusable.

Usa `inherit` solo cuando: (a) el reusable es tuyo o de tu propia org con control estricto; (b) la cantidad de secrets a pasar es inmanejable; (c) hay revisión de código obligatoria para cambios al reusable.

---

## 5. Ejemplo mínimo

Vamos a construir ambas cosas en 20 líneas cada una.

### 5.1 Composite action local

```bash
mkdir -p /tmp/comp-demo/.github/actions/greet
cd /tmp/comp-demo
cat > .github/actions/greet/action.yml <<'EOF'
name: 'Greet'
description: 'Prints a greeting'
inputs:
  who:
    required: false
    default: 'world'
outputs:
  message:
    value: ${{ steps.g.outputs.msg }}
runs:
  using: 'composite'
  steps:
    - id: g
      shell: bash
      run: |
        msg="Hello, ${{ inputs.who }}!"
        echo "$msg"
        echo "msg=$msg" >> "$GITHUB_OUTPUT"
EOF

mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: [push]
jobs:
  hello:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - id: g
        uses: ./.github/actions/greet
        with:
          who: Evan
      - run: echo "Captured output = ${{ steps.g.outputs.message }}"
EOF
```

Observaciones:

- `uses: ./.github/actions/greet` requiere **`actions/checkout` antes** — sin repo clonado, no hay `action.yml` que leer.
- La composite se expande *dentro* del job `hello`: en los logs verás los steps del composite listados.

### 5.2 Reusable workflow

```bash
mkdir -p /tmp/reuse-demo/.github/workflows
cd /tmp/reuse-demo

cat > .github/workflows/lint.yml <<'EOF'
name: Reusable lint
on:
  workflow_call:
    inputs:
      python-version:
        required: false
        type: string
        default: '3.12'
    outputs:
      ruff-version:
        value: ${{ jobs.lint.outputs.v }}

jobs:
  lint:
    runs-on: ubuntu-latest
    outputs:
      v: ${{ steps.r.outputs.v }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ inputs.python-version }}
      - id: r
        run: |
          pip install ruff
          v="$(ruff --version | awk '{print $2}')"
          echo "ruff=$v"
          echo "v=$v" >> "$GITHUB_OUTPUT"
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: [push]
jobs:
  call-lint:
    uses: ./.github/workflows/lint.yml
    with:
      python-version: '3.12'
  after:
    needs: call-lint
    runs-on: ubuntu-latest
    steps:
      - run: echo "Ruff was ${{ needs.call-lint.outputs.ruff-version }}"
EOF
```

Observaciones:

- `uses: ./.github/workflows/lint.yml` — forma **local** del reusable (mismo repo).
- No necesita `actions/checkout` *para invocarlo*: GitHub resuelve el archivo directamente. El checkout va dentro del reusable, en sus propios jobs.
- `needs:` entre caller y reusable: `needs.call-lint.outputs.ruff-version` funciona porque el `outputs` del job que invoca al reusable mapea los outputs del reusable 1:1.

---

## 6. Implementación progresiva

### 6.1 Decidir composite o reusable

Un árbol de decisión que funciona en el 90% de los casos:

```
¿Lo que quieres reutilizar es…
├── una secuencia de setup o checks dentro de UN job existente?
│   → composite action.
├── un pipeline completo (uno o más jobs, con sus runners)?
│   → reusable workflow.
└── algo que necesita correr en runners/condiciones diferentes del caller
    (p. ej. deploy en self-hosted mientras el caller está en hosted)?
    → reusable workflow.
```

Preguntas sueltas que apuntan a **reusable**:

- "Quiero poder requerirlo como check obligatorio a nivel org" → reusable (`required workflows`, ver `gha-15`).
- "Necesita su propio `environment:` con approvals" → reusable (los environments son por job).
- "Debe correr en una matriz distinta al caller" → reusable.

Preguntas sueltas que apuntan a **composite**:

- "Es un bloque de 3–8 pasos antes del test" → composite.
- "Necesito que vea el filesystem y el cache ya montado por el caller" → composite.
- "Es puramente setup (sin lógica de negocio ni secretos)" → composite.

### 6.2 Convención de versionado

La más usada:

- Cada release crea un tag `vX.Y.Z` **inmutable** (`v1.2.3`, p. ej.).
- Un tag `vX` (`v1`) **móvil**, se reescribe en cada release para apuntar al último SHA de la major.
- Opcionalmente, un tag `vX.Y` también móvil.
- Los consumidores *conservadores* pinnean a **SHA** y bump por Dependabot. Los *pragmáticos* pinnean a `@v1`.

Workflow de release de la propia composite / reusable:

```bash
# 1. commit + tag inmutable
git tag -a v1.2.3 -m "v1.2.3"
git push origin v1.2.3

# 2. mover el major tag
git tag -fa v1 -m "latest v1 (1.2.3)"
git push origin v1 --force
```

Hay una action oficial que hace exactamente esto: `actions/publish-action` — pero el patrón manual es suficiente para empezar.

### 6.3 Starter workflows (introducción)

Un **starter workflow** es un archivo `.yml` que GitHub propone al usuario al crear un workflow en la UI del repo. Vive en un repo especial de la org llamado `.github` bajo `workflow-templates/`. **No es** un reusable — es solo una plantilla que se copia al repo del usuario.

```
my-org/.github/
└── workflow-templates/
    ├── python-ci.yml                 # el workflow sugerido
    ├── python-ci.properties.json     # metadata (nombre, descripción, iconName)
    └── icons/python.svg
```

Diferencia clave:

- Starter: **se copia** al repo. El usuario edita libremente. Deriva inmediata.
- Reusable: **se invoca por referencia**. El upstream sigue siendo el single source of truth.

Usa starter cuando quieres **ergonomía inicial** y aceptas la deriva. Usa reusable cuando quieres **gobierno continuo**. En `gha-15` combinamos ambos: starter que ya referencia un reusable (así "ergonomía + gobierno").

---

## 7. Aplicación profesional

### 7.1 Qué va en un repo compartido

Un patrón sano es tener en la org un repo `shared-workflows` (o `.github` combinado con workflow templates) que contenga:

```
.github/
├── workflows/
│   ├── deploy.yml           # reusable deploy
│   ├── docker-build.yml     # reusable: build + push a GHCR
│   ├── terraform-plan.yml   # reusable: terraform init + plan + comment
│   └── scorecard.yml        # reusable: supply-chain scorecard
├── actions/
│   ├── setup-python-plus-poetry/
│   │   └── action.yml       # composite
│   └── setup-node-plus-pnpm/
│       └── action.yml       # composite
└── workflow-templates/      # starters
    ├── python-ci.yml
    └── python-ci.properties.json
README.md                    # catálogo + convenciones de versionado
```

Convenciones típicas:

- **Un README que lista** composites y reusables con su contract (inputs/outputs/secrets).
- **Tags `vX` móviles** por cada mayor.
- **CODEOWNERS** sobre `.github/workflows/*` para que un equipo plataforma sea reviewer obligatorio.
- **Branch protection** sobre `main` del repo compartido (es ahora código de producción de *todos* los repos de la org).
- **Changelog** por release (puedes automatizarlo con `release-please`).

### 7.2 Permisos: lo que debes mirar siempre

Un bug sutil frecuente: el reusable **necesita** `permissions: packages: write` para publicar a GHCR, pero el workflow caller declara `permissions: contents: read` y nada más. El reusable **no puede subir** su `GITHUB_TOKEN` por encima del caller.

Fix: documenta en el reusable qué `permissions:` necesita el **caller**, y haz que el caller los declare:

```yaml
# caller
permissions:
  contents: read
  packages: write      # requerido por shared/docker-build.yml

jobs:
  build:
    uses: my-org/shared/.github/workflows/docker-build.yml@v1
    with:
      image: my-app
```

### 7.3 Costo (minutos de runner)

**Un reusable workflow suma minutos**. Si el reusable corre 3 jobs y cada uno dura 2 minutos, son 6 minutos **por invocación** adicionales a los del caller. Si cambias de "composite inline" a "reusable" y multiplicas por 50 repos consumidores x 20 PRs/día = ~1000 invocaciones diarias.

Composite = 0 minutos adicionales (los pasos corren en el job que ya pagaste). Esto no es excusa para abusar de composite, pero sí para no "reusable-izar" todo por puro reflejo.

### 7.4 Debugging

- **"Where did this step come from?"** La UI de Actions muestra composite steps anidados y jobs del reusable como *jobs separados*. Si no estás seguro, mira el badge "Called by" en el run del reusable.
- **"My reusable's secret is empty"**: olvidaste declararlo en `on: workflow_call.secrets:` o olvidaste pasarlo en el caller. **Error silencioso**: el secret se evalúa a `''` sin fallar.
- **"Permissions denied in my reusable"**: revisa `permissions:` del **caller**, no del reusable.
- **"My composite's `run:` fails parsing"**: olvidaste `shell: bash`.

---

## 8. Trade-offs

### 8.1 Composite vs reusable (el único trade-off que importa)

| Dimensión | Composite | Reusable |
|-----------|-----------|----------|
| Overhead de minutos | 0 | +N (un runner por job del reusable) |
| Aislación | Nula (comparte todo) | Máxima (runner propio) |
| Granularidad | Grupo de steps | Pipeline completo |
| Puede requerirse a nivel org | No | **Sí** (`required workflows` / rulesets) |
| Puede usar `environment:` con approvals | No (es a nivel job) | **Sí** |
| Puede tener matrix propia | No | **Sí** |
| Puede llamar a otras actions | **Sí** | Sí (vía sus jobs) |
| Puede llamar a otros reusables | No | **Sí**, hasta 4 niveles |
| Tiempo de ejecución | Igual al step inline | Mayor (startup del runner) |

### 8.2 Composite action vs script `.sh` versionado

A veces lo que quieres es solo correr un script bash propio en varios repos. Dos caminos:

- **Composite action**: pros = contract explícito (inputs/outputs), integración con `uses:`. Contras = más boilerplate que un script.
- **Script versionado**: `curl` el `.sh` de un release y `bash` lo. Pros = simplísimo. Contras = no hay tipos, el pin es por SHA del release pero el flujo de ejecutar código remoto es más opaco.

Preferencia: si vas a reusarlo >2 veces y hay inputs no triviales, haz composite.

### 8.3 Reusable workflow vs JS action propia

Para la lógica de orquestación (coordinar steps/jobs), reusable gana (no requiere JS, no requiere publicarse al Marketplace). Para lógica *computacional* propia (parsear YAML, llamar APIs, formatear outputs), una JS action gana. Ver `gha-12` para JS actions.

### 8.4 `secrets: inherit` vs explícito

Ya vista en §4.5. Trade-off = seguridad/auditoría vs comodidad.

### 8.5 `@v1` móvil vs `@<SHA>`

- `@v1`: ergonomía, upgrades automáticos de parches. Riesgo: upstream puede reescribir el tag.
- `@<SHA>`: seguridad, reproducibilidad. Costo: Dependabot debe gestionarlo o pierdes updates.

Regla cómoda: SHA para actions de tercero no auditado; `@v1` para actions oficiales y para el repo compartido de tu propia org.

---

## 9. Errores frecuentes

### 9.1 "Mi composite falla con `shell` is not valid"

```yaml
# MAL (composite)
runs:
  using: 'composite'
  steps:
    - run: echo "hi"             # falta shell: bash
```

Fix: añadir `shell: bash` a cada step `run:`.

### 9.2 "El reusable no ve mis secrets"

```yaml
# caller — mal
jobs:
  deploy:
    uses: ./.github/workflows/deploy.yml@v1
    # falta: secrets: ... o secrets: inherit
```

Si el reusable declara `secrets.DEPLOY_TOKEN.required: true`, el parse falla. Si lo declara como `required: false` o no lo declara en absoluto, el secret se evalúa a `''` **silenciosamente**. Resultado: deploy "funciona" pero con token vacío, falla a mitad del step con un `401`.

Fix: siempre declara los secrets en `on: workflow_call.secrets:` y márcalos `required: true` cuando lo son.

### 9.3 "Puse `uses:` y `steps:` en el mismo job"

```yaml
# MAL
jobs:
  deploy:
    uses: ./.github/workflows/deploy.yml@v1
    steps:                       # ← no se puede
      - run: echo "pre"
```

Fix: dos jobs con `needs:`.

```yaml
jobs:
  pre:
    runs-on: ubuntu-latest
    steps:
      - run: echo "pre"
  deploy:
    needs: pre
    uses: ./.github/workflows/deploy.yml@v1
```

### 9.4 "Composite local — `uses: ./...` da `Can't find action.yml`"

Olvidaste `actions/checkout` antes. Sin checkout, el runner no tiene el archivo en disco.

### 9.5 "Mi reusable tiene `permissions: write-all` pero el `GITHUB_TOKEN` sigue sin poder escribir"

Causa: el caller tiene `permissions: contents: read`. El reusable no puede *elevar*. Fix: elevar en el caller.

### 9.6 "Mover el tag `v1` rompió todos los consumidores que pinnean a SHA"

No los rompió: siguen anclados al SHA. Lo que ya no reciben son los updates. Es el trade-off esperado del pin a SHA.

### 9.7 "`matrix` en el caller no funciona"

```yaml
# Esto NO expande el matrix dentro del reusable:
jobs:
  call:
    strategy:
      matrix:
        env: [staging, prod]
    uses: ./.github/workflows/deploy.yml@v1
    with:
      environment: ${{ matrix.env }}   # ← esto SÍ funciona
```

De hecho el ejemplo anterior **sí** funciona: `matrix` aplicado al job que invoca al reusable crea *N* ejecuciones del reusable, cada una con su `environment:` distinto. Lo que **no** se puede es poner `strategy.matrix` *dentro* del reusable y pedir que el caller lo parametrice sin volver a declararlo.

### 9.8 "Llegué al límite de profundidad 4"

Reusable `A` → `B` → `C` → `D` → `E` (quinto nivel) falla el parse. Si llegaste, refactoriza aplanando: haz que `A` llame directo a `D` y pase los inputs necesarios.

---

## 10. Buenas prácticas

- **Composite para setup, reusable para pipelines**: regla heurística que resuelve el 80% de las decisiones.
- **Tipa los inputs del reusable** (`type: string | number | boolean`). Documéntalos.
- **Declara explícitamente los secrets** que el reusable necesita; evita `inherit` salvo justificado.
- **Versiona con `vX` móvil + `vX.Y.Z` inmutables**. Mantén un CHANGELOG.
- **Pin a SHA** para reusables/actions de terceros no auditados.
- **CODEOWNERS** sobre el repo compartido: nunca sea editable por cualquiera.
- **Documenta en el README** los `permissions:` que el caller debe declarar para que el reusable funcione.
- **Composite: `shell: bash` siempre.**
- **Limita inputs a 10 — si necesitas más, probablemente la abstracción está mal**: parte en dos.
- **Observabilidad del uso**: periódicamente, `gh search code 'uses: my-org/shared/.github/workflows/'` para saber quién consume qué.
- **No pongas lógica de negocio compleja en composite**: si tiene >50 líneas de bash, considera una JS action (`gha-12`).

---

## 11. Ejercicios recomendados

1. **`activities/01-extract-composite-action/`** — guided-lab: tienes un workflow con 3 jobs y cada uno repite 4 pasos. Extráelo en una composite action local y refactoriza el workflow.
2. **`activities/02-publish-reusable-workflow/`** — independent (dos repos simulados): publicas un reusable workflow en un repo "shared" versionado con `v1`, y lo consumes desde un repo "client" con el `uses: owner/shared/.github/workflows/x.yml@v1`.

---

## 12. Evaluación

Responde sin consultar. Las **P1–P3** son conceptuales; **P4–P5** son operativas; **P6** es el ejercicio integrador y **P7** es la rúbrica del entregable del módulo.

**P1.** Diferencia **en una frase cada una** entre:
- Composite action
- Reusable workflow
- Starter workflow
- JS action

**P2.** Explica por qué un `run:` dentro de una composite **requiere `shell:`** cuando en un workflow normal no.

**P3.** Verdadero / falso:
- [ ] Un reusable workflow puede llamar a otro reusable workflow (hasta 4 niveles).
- [ ] `secrets: inherit` pasa solo los secrets listados en el `with:` del caller.
- [ ] Si el caller declara `permissions: contents: read`, el reusable **no puede** escribir a `packages`.
- [ ] En un job con `uses:` a un reusable, puedes añadir `steps:` adicionales.
- [ ] `matrix` aplicada al job caller de un reusable crea N invocaciones del reusable.
- [ ] Una composite action puede tener su propio `runs-on:`.

**P4.** Escribe un `action.yml` de composite action que acepte un input `name` (default `"world"`) y exponga un output `greeting` con el texto `"Hello, <name>!"`. 20 líneas máx.

**P5.** Dado un reusable workflow con `on: workflow_call.secrets.DEPLOY_TOKEN.required: true`, escribe el caller mínimo que lo invoque pasando el secret `STAGING_DEPLOY_TOKEN` del repo como `DEPLOY_TOKEN`.

**P6.** **Justifica composite vs reusable para los 3 casos siguientes** (una frase por caso, criterio decisivo):
- (a) Un bloque de 5 pasos: `checkout` + `setup-python` + `pip install -r requirements.txt` + `ruff check` + `pytest`. Lo quieren usar 8 repos distintos de la misma org.
- (b) Un pipeline de 3 jobs: `build` → `scan-sbom` → `publish-to-ghcr`, cada uno con sus permisos distintos, debe ser **obligatorio** para todos los repos de la org que publican imágenes.
- (c) Un paso que descarga una herramienta `.tar.gz` desde un release de GitHub y la pone en el PATH del runner (misma versión en todos los jobs del caller).

**P7.** Diseña la convención de versionado y el `README.md` del repo `shared-workflows` de tu org (3 reusables, 2 composites). Debe cubrir: estructura de carpetas, tags, cómo pinnear, quién revisa cambios, qué pasa cuando se publica un `vX+1` breaking.

---

## Referencias

- *Reusing workflows* (docs oficiales). <https://docs.github.com/en/actions/sharing-automations/reusing-workflows>
- *Creating a composite action* (docs oficiales). <https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action>
- *Metadata syntax for GitHub Actions* (`action.yml`). <https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions>
- *Workflow syntax — `on.workflow_call`*. <https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#onworkflow_call>
- *Avoiding duplication* (reusable patterns). <https://docs.github.com/en/actions/sharing-automations/avoiding-duplication>
- *Creating starter workflows for your organization*. <https://docs.github.com/en/actions/sharing-automations/creating-workflow-templates-for-your-organization>
- *Automatic token authentication* (`GITHUB_TOKEN` scoping). <https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication>
- *Security hardening for GitHub Actions* (sección "Reusing third-party workflows"). <https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>
