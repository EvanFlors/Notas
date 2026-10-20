# Lección: Eventos y triggers en GitHub Actions

> **ID:** `gha-03-events-and-triggers` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `gha-02-syntax-expressions-and-contexts`.

---

## 1. Introducción intuitiva

Un workflow de GitHub Actions no "corre siempre". Corre **cuando algo ocurre**: alguien hace push, abre un pull request, publica un release, pulsa un botón en la UI, se cumple una hora programada, otro workflow termina… cada uno de esos "algos" es un **evento**. La sección `on:` de tu YAML dice *qué* eventos te interesan y *con qué filtros*.

Esto suena trivial — "¿para qué una lección entera sobre `on:`?" — pero el 80 % de los problemas reales que vas a ver en pipelines ajenos vienen de aquí: pipelines que corren el doble de veces de lo necesario, deploys que no disparan porque el filtro de `paths` está mal escrito, bots que fallan silenciosamente en PRs de forks, y — el clásico — un `pull_request_target` con `actions/checkout` del head del PR que convierte el repo en una máquina de ejecutar código arbitrario *con los secretos de producción*.

Elegir trigger es, en el fondo, una decisión de **superficie**: superficie de ejecución (¿cuánto corre?), superficie de permisos (¿qué secretos ve?) y superficie de ataque (¿qué puede abusarse?).

---

## 2. Fundamentos

### 2.1 Qué es un evento

Un evento es un mensaje estructurado que GitHub emite cuando ocurre algo en un repositorio o en la plataforma. Cada evento tiene:

- un **nombre** (`push`, `pull_request`, `release`, …),
- opcionalmente una **actividad** o `type` (`opened`, `synchronize`, `closed`, `published`, …),
- un **payload** JSON con el estado relevante en el momento del evento.

Cuando declaras `on: push`, le dices a GitHub: "cuando se emita un evento `push` para este repo, instancia este workflow con ese payload". El payload llega a tu workflow como el contexto `github.event` y como el fichero `$GITHUB_EVENT_PATH` (JSON completo en disco del runner).

### 2.2 De evento a run

```
Evento (push / PR / cron / dispatch / ...)
        │
        ▼
GitHub scheduler
  - resuelve qué workflows aplican (match de on:, filtros, SHA/ref)
  - resuelve qué permisos tendrá GITHUB_TOKEN
  - resuelve qué secretos están disponibles
        │
        ▼
Workflow run  (una instancia del archivo .yml)
        │
        ├── job A (runner 1)  → steps secuenciales
        └── job B (runner 2)  → steps secuenciales
```

Un mismo evento puede disparar **varios workflows** del repo si cada uno lo declara en su `on:`. Y un mismo workflow puede declarar **varios eventos** (`on: [push, pull_request]`).

### 2.3 Dónde se evalúan los filtros

Los filtros (`branches`, `tags`, `paths`, `types`) se evalúan **en GitHub, antes de encolar el run**. Si no hay match, no se crea ni siquiera un run skipped — directamente no pasa nada. Esto importa porque:

- No hay forma de "detectar desde dentro" por qué un workflow no corrió: hay que mirar el YAML y el evento.
- La UI de Actions **no muestra** workflows que ni siquiera fueron encolados.

### 2.4 Qué define el ref y el SHA del run

| Evento | `GITHUB_REF` del run | `GITHUB_SHA` del run | Checkout por defecto |
|--------|----------------------|----------------------|----------------------|
| `push` | `refs/heads/<branch>` o `refs/tags/<tag>` | SHA del push | el mismo commit |
| `pull_request` | `refs/pull/<N>/merge` | merge commit *efímero* base + head | el merge commit (código del PR) |
| `pull_request_target` | `refs/heads/<base>` | HEAD del base | **el base** (código ya en main) |
| `workflow_dispatch` | el ref que elijas en la UI/`gh` | HEAD de ese ref | ese ref |
| `schedule` | default branch | HEAD del default | default branch |
| `workflow_run` | default branch | HEAD del default | **default branch, siempre** |
| `release` | el tag del release | commit del tag | el commit del tag |

La diferencia entre `pull_request` y `pull_request_target` en esta tabla es el **origen de la Lección 7**. No la olvides.

---

## 3. Anatomía: el bloque `on:` en todas sus formas

Tres formas sintácticas, de menos a más expresiva:

```yaml
# a) Un solo evento, sin filtros
on: push

# b) Varios eventos, sin filtros
on: [push, pull_request, workflow_dispatch]

# c) Mapa con filtros (lo que vas a usar en la práctica)
on:
  push:
    branches: [main, 'release/**']
    paths:
      - 'src/**'
      - '!src/**/*.md'
      - '.github/workflows/ci.yml'
    tags: ['v*.*.*']
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    branches: [main]
    paths:
      - 'src/**'
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, staging, prod]
        default: dev
  schedule:
    - cron: '0 3 * * *'   # 03:00 UTC diario
```

Reglas:

- Listas en YAML aceptan patrones **glob** (`**` = cualquier profundidad; `*` = un segmento; `!` = negación — y la negación se evalúa por orden).
- `branches` y `branches-ignore` **son mutuamente excluyentes** en el mismo evento. Lo mismo `paths` / `paths-ignore` y `tags` / `tags-ignore`.
- Para `pull_request`, si no declaras `types`, el default es `[opened, synchronize, reopened]`. Para `release` el default incluye `published`.

---

## 4. Catálogo de triggers (lo que vas a elegir)

### 4.1 `push`

Dispara en cada push a un ref. Dentro del repo (sin forks). Si el push incluye varios commits, el run es **uno solo** por el último commit.

**Úsalo para:** CI del default branch, deploy en tag, build en ramas de release.

```yaml
on:
  push:
    branches: [main]
    tags: ['v*.*.*']
```

### 4.2 `pull_request`

Dispara en acciones sobre PRs. Trae el **merge commit efímero** (base + head aplicados), por lo que corres contra el estado "si se mergeara ahora mismo".

**En PRs desde forks**:

- El `GITHUB_TOKEN` es **de solo lectura**.
- Los **secretos del repo no se exponen** (ni los del environment).
- El workflow puede fallar silenciosamente si asume que tiene permisos de escritura.

Tipos útiles además del default:

- `ready_for_review` (dispara cuando se saca un PR de draft).
- `labeled` / `unlabeled` (dispara cuando se añade/quita una etiqueta — útil para `label: run-e2e`).
- `closed` (dispara al cerrar; combínalo con `if: github.event.pull_request.merged == true` para "al mergear").

### 4.3 `pull_request_target`

Mismo evento que `pull_request` pero:

- Se ejecuta en el contexto del **base** (default branch, o la rama destino): código ya auditado.
- `GITHUB_TOKEN` tiene **permisos de escritura**.
- Los **secretos sí se exponen**.

**Para qué sirve legítimamente:** labelear PRs automáticamente, comentar con bots, aplicar triage. **Todo lo que no requiera ejecutar el código del PR.**

**Trampa mortal** — Lección 7 entera.

### 4.4 `workflow_dispatch`

Dispara manualmente desde la UI, `gh workflow run` o la API. Admite **inputs tipados**:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        required: true
        options: [dev, staging, prod]
      dry_run:
        type: boolean
        default: true
      tag:
        type: string
        required: true
```

Los inputs llegan al workflow como `${{ inputs.environment }}`. Hasta 10 inputs por workflow.

**Úsalo para:** deploys manuales, replays, operaciones destructivas gated con approval.

### 4.5 `schedule`

Dispara en expresiones cron en **UTC** (no en la zona del repo ni del usuario):

```yaml
on:
  schedule:
    - cron: '0 3 * * *'      # 03:00 UTC cada día
    - cron: '*/30 * * * 1-5' # cada 30 min, lunes a viernes
```

Notas:

- Resolución mínima: **5 minutos**. Workflows muy frecuentes pueden ser rechazados o des-priorizados.
- Si el default branch no tiene ese workflow activo durante **60 días**, GitHub lo deshabilita automáticamente para repos privados sin actividad.
- Un schedule que caiga en un momento de alta carga puede retrasarse varios minutos.

**Úsalo para:** limpieza nocturna, sync de datos, chequeos periódicos de dependencias.

### 4.6 `workflow_call`

Convierte el workflow en **reutilizable**. Otros workflows lo invocan con `uses:`:

```yaml
on:
  workflow_call:
    inputs:
      ref:
        type: string
        required: true
    secrets:
      REGISTRY_TOKEN:
        required: true
    outputs:
      image_digest:
        value: ${{ jobs.build.outputs.digest }}
```

Se cubre a fondo en `gha-08`. Aquí solo nómbralo.

### 4.7 `workflow_run`

Dispara cuando **otro** workflow del mismo repo termina (o se solicita, cancela…).

```yaml
on:
  workflow_run:
    workflows: ['CI']
    types: [completed]
    branches: [main]
```

Reglas no obvias y críticas:

- Siempre se ejecuta con el **YAML del default branch** y contra el default branch (independientemente del branch del workflow origen).
- `GITHUB_TOKEN` tiene permisos del default; secretos del repo disponibles.
- Es el "lugar seguro" para **procesar resultados** de un workflow de `pull_request` que corrió sin secretos (ver Lección 7).

### 4.8 `release`

Dispara cuando cambia un release. Tipos: `published`, `created`, `edited`, `deleted`, `prereleased`, `released`.

```yaml
on:
  release:
    types: [published]
```

Trae `github.event.release.*` con tag, URL, assets.

**Úsalo para:** publicar artefactos a package registries, generar changelog, firmar imágenes.

### 4.9 `issues` e `issue_comment`

Reactivos al ciclo de vida de issues y a comentarios (en issues **y** en PRs — un PR es un issue por detrás).

```yaml
on:
  issue_comment:
    types: [created]
```

**Patrón ChatOps:** reaccionar a `/deploy` o `/retest` en comentarios. Como `issue_comment` también se dispara en PRs, puedes filtrar: `if: github.event.issue.pull_request`.

### 4.10 `repository_dispatch`

Un **webhook de entrada**: un sistema externo (otro CI, un servicio) te hace `POST` y dispara un workflow con un payload custom.

```yaml
on:
  repository_dispatch:
    types: [infra-updated]
```

**Úsalo para:** federar pipelines entre repos sin exponer tokens de larga vida (quien dispara autentica con un PAT o GitHub App; el workflow corre con los secretos del repo que recibe).

---

## 5. Filtros a profundidad

### 5.1 `branches` / `branches-ignore`

Globs sobre nombres de rama (sin el prefijo `refs/heads/`).

```yaml
on:
  push:
    branches:
      - main
      - 'release/**'
      - '!release/legacy-*'  # negación: orden importa
```

Si usas `tags:` junto con `branches:`, un push a una rama **o** a un tag que matchee dispara (es OR). No puedes combinar `branches` y `branches-ignore` para el **mismo** evento.

### 5.2 `paths` / `paths-ignore`

Globs sobre rutas de archivos modificados por el push/PR.

```yaml
on:
  pull_request:
    paths:
      - 'src/**'
      - '!src/**/*.md'
      - '.github/workflows/ci.yml'
```

Qué "modificados" significa:

- `push`: archivos cambiados por los commits del push.
- `pull_request`: archivos del diff entre base y head del PR.

**Trampa:** si usas `paths` como *required check* en branch protection, los PRs que no tocan `src/**` nunca producirán el check → la protección se bloquea esperando algo que no va a venir. Solución: workflow "paths-filter" con un job dummy que siempre reporta success si no hay cambios relevantes (patrón "workflow should pass without doing work").

### 5.3 `types`

Lista de actividades del evento. Qué actividades existen depende de cada evento (ver docs oficiales). Mencionados arriba:

- `pull_request`: `opened`, `synchronize`, `reopened`, `ready_for_review`, `labeled`, `closed`, …
- `issues`: `opened`, `edited`, `labeled`, `assigned`, `closed`, …
- `release`: `published`, `created`, `prereleased`, `released`, …

### 5.4 Combinando filtros con `if:` a nivel job

Los filtros de `on:` deciden si el run se **crea**. Si necesitas condiciones más finas (p. ej. "solo si el PR tiene la label `deploy`"), usa `if:` en el job:

```yaml
jobs:
  deploy:
    if: contains(github.event.pull_request.labels.*.name, 'deploy')
    runs-on: ubuntu-latest
```

Esto crea el run pero skippea el job. En billing cuenta como run; en UI aparece como skipped.

---

## 6. El payload del evento (`github.event`)

Cuando el workflow arranca, recibes todo el JSON del evento en dos sitios:

- `${{ github.event }}` (dentro de expresiones).
- `$GITHUB_EVENT_PATH` (fichero JSON en el runner).

```yaml
- name: Dump event
  run: cat "$GITHUB_EVENT_PATH" | jq .
```

Campos usados a diario:

| Campo | Evento | Uso |
|-------|--------|-----|
| `github.event.pull_request.number` | `pull_request*` | comentar/labelear el PR |
| `github.event.pull_request.head.sha` | `pull_request*` | SHA del head del PR (⚠ no confiable para `checkout` con `pull_request_target`) |
| `github.event.pull_request.base.ref` | `pull_request*` | rama destino |
| `github.event.pull_request.head.repo.fork` | `pull_request*` | `true` si viene de un fork |
| `github.event.release.tag_name` | `release` | tag publicado |
| `github.event.inputs.<name>` | `workflow_dispatch` | input del dispatch |
| `github.event.schedule` | `schedule` | la expresión cron que disparó |
| `github.event.workflow_run.conclusion` | `workflow_run` | `success` / `failure` / … |
| `github.event.comment.body` | `issue_comment` | texto del comentario (⚠ untrusted) |

**Regla de oro:** cualquier campo que un externo pueda controlar (`comment.body`, `pull_request.title`, `pull_request.body`, nombres de rama de forks) es **input no confiable** y nunca se interpola directamente en un `run:` de shell (ver `gha-02` sobre inyección y `gha-13` sobre hardening).

---

## 7. `pull_request` vs `pull_request_target`: la lección que no se olvida

### 7.1 Qué queremos realmente

Dos necesidades distintas en PRs desde forks:

1. **Correr tests contra el código del PR.** Necesito el código. No necesito secretos.
2. **Labelear/comentar/triagear el PR.** Necesito permisos de escritura y quizá secretos. **No necesito el código.**

GitHub creó dos triggers porque son casos opuestos.

### 7.2 Qué hace cada uno

```
┌──────────────────────────────┬───────────────────────────┬────────────────────────────┐
│                              │   pull_request            │  pull_request_target        │
├──────────────────────────────┼───────────────────────────┼────────────────────────────┤
│ Checkout por defecto         │   HEAD del PR (fork)      │  HEAD del base (upstream)   │
│ Secretos del repo            │   NO (fork)               │  SÍ                         │
│ Secretos de environment      │   NO (fork)               │  SÍ (con reglas)            │
│ GITHUB_TOKEN                 │   solo lectura (fork)     │  escritura                  │
│ YAML aplicado                │   el del PR               │  el del base                │
└──────────────────────────────┴───────────────────────────┴────────────────────────────┘
```

### 7.3 El anti-patrón

Un workflow con `on: pull_request_target` que incluye:

```yaml
# NO HAGAS ESTO
- uses: actions/checkout@v4
  with:
    ref: ${{ github.event.pull_request.head.sha }}
- run: npm install && npm test
```

Qué pasa:

1. El workflow se dispara con **secretos y token con escritura** (porque es `pull_request_target`).
2. Haces checkout **del código del fork** (atacante).
3. Ejecutas `npm install` → corres **`postinstall` del `package.json` del atacante** con esos secretos.

Resultado: cualquier persona que abra un PR a tu repo exfiltra tus secretos a su servidor. Esto no es teórico — ha pasado en proyectos reales grandes y los informes de incidentes están publicados.

### 7.4 El patrón seguro

Hay tres variantes legítimas, por orden de preferencia:

**Variante A — Nunca ejecutes código del PR en `pull_request_target`.** Úsalo solo para operaciones sobre metadata (labels, comments). Los tests van en un workflow separado con `on: pull_request`:

```
   PR desde fork
       │
       ├──> workflow A: on: pull_request
       │       - checkout del PR
       │       - npm test                  (sin secretos, sin write)
       │
       └──> workflow B: on: pull_request_target
               - NO hace checkout
               - comenta el PR, labelea     (con secretos, con write)
```

**Variante B — Procesa resultados con `workflow_run`.** Workflow A (`pull_request`) corre tests y sube artefactos. Workflow B (`workflow_run`, dispara al terminar A) descarga los artefactos **sin hacer checkout del PR** y publica resultados con secretos:

```
pull_request (A) ──[sube artefacto]──> workflow_run (B)
   sin secretos                           con secretos
   sin write                              con write
   corre código                           NO corre código del PR
```

**Variante C — `pull_request_target` + checkout aislado + aprobación manual.** Haces checkout del PR en un **job sin secretos** (`permissions: contents: read`, variables de environment vacías) y solo pasas el resultado (artefacto) al siguiente job. Requiere disciplina quirúrgica: si olvidas separar jobs correctamente, caes en el anti-patrón.

**Qué no cuenta como "seguro":**

- "Lo filtro con `if: github.event.pull_request.head.repo.fork == false`": no — un maintainer puede abrir un PR desde una rama del mismo repo con código malicioso para probar algo y los secretos siguen expuestos. (Y además, si confías solo en `if:`, el workflow sigue siendo evaluado con el YAML del base, pero expones permisos.)
- "Lo filtro con `if: github.actor == 'myself'`": `github.actor` puede ser suplantado en ciertos eventos encadenados.

Regla operativa que puedes memorizar:

> **Nunca combinar `pull_request_target` con `actions/checkout` apuntando a algo que el PR controle.**

### 7.5 Setting adicional en el repo

En `Settings → Actions → General → Fork pull request workflows from outside collaborators`, puedes requerir aprobación de un maintainer antes de que corra cualquier workflow desde un fork por primera vez. Es defensa en profundidad: no te salva del anti-patrón, pero limita exposición.

---

## 8. `workflow_run`: para qué es exactamente

Es el único trigger que se dispara por **otro workflow**. Clave para pipelines encadenados y para el patrón seguro de PRs de forks.

```yaml
on:
  workflow_run:
    workflows: ['CI']
    types: [completed]
```

Puntos clave:

- Siempre usa el **YAML del default branch**. Si cambias este workflow en una rama, los cambios **no aplican** hasta que mergees a default. Esto es intencional (seguridad) pero sorprende la primera vez.
- Corre contra el default branch con todos los permisos del repo.
- Para saber si el workflow origen tuvo éxito: `github.event.workflow_run.conclusion == 'success'`.
- Para descargar artefactos del run origen: usa `actions/download-artifact@v4` con `run-id: ${{ github.event.workflow_run.id }}` o la API.

**Úsalo para:** publicar comentarios con resultados de tests de PR, promover artefactos entre pipelines, orquestar fases que no caben en un solo workflow.

---

## 9. Cron: UTC y nada más

```yaml
on:
  schedule:
    - cron: '0 3 * * *'       # 03:00 UTC
    - cron: '15 */4 * * 1-5'  # 15 min pasada cada 4h, L-V
```

- Formato POSIX cron de 5 campos: `minuto hora día-mes mes día-semana`.
- Siempre **UTC**. "A las 9 de la mañana en Madrid" no existe para GitHub; conviértelo tú.
- **Resolución mínima 5 min**; patrones más frecuentes pueden ser rechazados.
- GitHub puede **demorar** la ejecución si hay carga; no asumas puntualidad.
- Si el workflow no se ha activado en 60 días en repos privados, se deshabilita (necesitarás reactivarlo manualmente).

Mezclar `schedule` con `workflow_dispatch` es útil para poder ejecutar el mismo workflow a mano cuando el cron se retrasa.

---

## 10. ChatOps con `issue_comment`

Patrón común:

```yaml
on:
  issue_comment:
    types: [created]

jobs:
  retest:
    if: >-
      github.event.issue.pull_request &&
      startsWith(github.event.comment.body, '/retest')
    runs-on: ubuntu-latest
    steps:
      - name: Check permission
        run: |
          # Only maintainers may trigger /retest
          gh api "repos/${{ github.repository }}/collaborators/${{ github.event.comment.user.login }}/permission" \
            --jq '.permission' | grep -Eq 'admin|write'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Rerun CI
        run: gh workflow run ci.yml --ref "refs/pull/${{ github.event.issue.number }}/head"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Observa:

- `comment.body` es **untrusted**: usa `startsWith`/`contains`, no lo interpoles en un `run:`.
- Siempre valida permiso del autor del comentario antes de obedecer.
- `issue_comment` corre contra default branch (como `workflow_run`), así que tus secretos están disponibles.

---

## 11. Tabla-resumen de decisión

Cinco escenarios y el trigger correcto:

| Escenario | Trigger recomendado | Por qué |
|-----------|---------------------|---------|
| CI que corre lint+test en cada PR al default branch | `on: pull_request` (con `paths` si quieres filtrar) | código del PR disponible, sin secretos; GITHUB_TOKEN read-only es suficiente |
| Deploy a staging al mergear a `main` | `on: push` con `branches: [main]` | push a main = merge aceptado; corre con secretos del repo |
| Publicación a package registry al cortar `v*.*.*` | `on: push` con `tags: ['v*.*.*']` **o** `on: release` con `types: [published]` | depende de si tu flujo usa `git tag` o GitHub Releases como fuente de verdad |
| Limpieza nocturna de recursos cloud a las 03:00 UTC | `on: schedule` con cron `'0 3 * * *'` + `workflow_dispatch` para re-ejecución manual | tareas periódicas; dispatch como escape hatch |
| Bot que labelea PRs externos (incluso de forks) | `on: pull_request_target` con `types: [opened]` y **sin** checkout del PR | necesita permisos de escritura; no necesita el código |
| Pipeline de release manual con elección de ambiente | `on: workflow_dispatch` con `inputs: environment` tipo `choice` | ejecución humana controlada; inputs tipados |
| Comentar resultados de tests en un PR desde fork | `on: workflow_run` del workflow de tests | único lugar seguro con secretos para procesar resultados del PR |

---

## 12. Checklist, evaluación y hacia adelante

### Checklist operativo antes de merge de un workflow nuevo

- [ ] El `on:` dispara **solo** cuando quieres (filtros `branches` / `paths` / `types` precisos).
- [ ] Si usas `paths`, no estás bloqueando un required check sin un fallback que siempre pase.
- [ ] Si usas `pull_request_target`, **no hay `actions/checkout`** apuntando al head del PR.
- [ ] Si consumes `github.event.pull_request.title`, `.body` o `comment.body`, no lo interpolas en `run:`.
- [ ] Si usas `schedule`, está en **UTC** y la expresión cron está comentada con la hora local equivalente.
- [ ] Si usas `workflow_run`, sabes que corre contra default branch y que los cambios al YAML no aplican hasta mergear.
- [ ] `permissions:` declarado a nivel workflow con lo mínimo necesario (`contents: read` por defecto).

### Evaluación

Para cada uno de los 5 escenarios siguientes, justifica el trigger elegido y por qué los otros no sirven:

1. "Quiero un pipeline que corra tests en cada PR, incluso de forks, y que publique resultados como comentario en el PR."
2. "Quiero publicar una imagen Docker a GHCR cada vez que creo un release en GitHub."
3. "Quiero que un bot cierre issues sin actividad tras 30 días."
4. "Quiero que un maintainer pueda disparar un deploy a producción escribiendo `/deploy prod` en un comentario del PR."
5. "Quiero promover un artefacto generado por el workflow `CI` al workflow `Publish`, pero solo si CI tuvo éxito y corrió en main."

Respuestas esperadas (ocultas; intenta tú primero): (1) dos workflows: `pull_request` para tests + `workflow_run` o `pull_request_target` para comentar; (2) `release` con `types: [published]`; (3) `schedule` diario; (4) `issue_comment` con validación de permisos + `workflow_dispatch` interno; (5) `workflow_run` filtrando `workflows: [CI]`, `conclusion == 'success'`, `head_branch == 'main'`.

### Hacia adelante

- `gha-04` — actions del marketplace y pinning a SHA.
- `gha-05` — secretos, variables, environments; relación con `pull_request_target` y `environment:` como gate.
- `gha-13` — hardening completo: pins a SHA, StepSecurity Harden-Runner, auditoría de `pull_request_target`.

Lo que acabas de aprender es la base sobre la que se construye casi toda la seguridad del pipeline. Si eliges el trigger correcto, el 70 % de los problemas de seguridad desaparecen antes de empezar.
