# Lección: Modelo mental y primer workflow de GitHub Actions

> **ID:** `gha-01-model-and-first-workflow` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** curso Git ≥ `gh-07` (push, pull requests, remotos).

---

## 1. Introducción intuitiva

Imagina que acabas de empujar un commit a `main` en GitHub. Querrías que, sin que tú tengas que hacer nada más:

- Alguien levante una máquina Linux limpia.
- Clone tu código en esa máquina.
- Corra tus tests.
- Si algo falla, te avise en el PR y bloquee el merge.
- Si todo pasa, construya una imagen de contenedor y la publique.
- Y luego apague la máquina y te cobre solo lo usado.

Antes del CI moderno, montabas un Jenkins propio, instalabas Java, configurabas nodos, escribías Groovy con sintaxis distinta a tu código, abrías puertos a GitHub por webhook, mantenías el servidor vivo noche y día. Era *infraestructura* para construir *infraestructura*.

**GitHub Actions** (GHA) resuelve esto con dos ideas:

1. **El pipeline vive junto al código.** Un archivo YAML en `.github/workflows/` dentro del mismo repo.
2. **GitHub provee el motor y las máquinas.** Tú describes "qué quiero que pase cuando ocurra X evento"; GitHub se encarga de agendar, levantar un runner, ejecutar y guardar los logs.

Es *pipeline-as-code* reactivo a eventos del repo. Un push es un evento. Un pull request es un evento. Un comentario, un release, un cron, un "click aquí para desplegar" — todos son eventos. Para cada uno, puedes declarar uno o más workflows.

En esta lección construyes el modelo mental correcto. Si lo haces bien, los módulos siguientes (`gha-02` a `gha-15`) no te sorprenderán — solo añaden capas sobre esta.

---

## 2. Fundamentos

Hay cinco conceptos que necesitas interiorizar antes de escribir tu primer YAML:

### 2.1 Evento (event)

Un **evento** es "algo que pasó en el repositorio" (o alrededor). Ejemplos:

- `push` a una rama.
- `pull_request` abierto, actualizado, cerrado.
- `release` publicado.
- `schedule` (cron).
- `workflow_dispatch` (botón manual).
- `issue_comment`, `label`, `fork`, `watch`, etc.
- `repository_dispatch` / `workflow_call` (eventos de otro sistema o de otro workflow).

GitHub mantiene un **bus de eventos** interno. Cada vez que ocurre algo, publica un evento con un **payload** (JSON) y lo pasa al scheduler de Actions.

### 2.2 Workflow

Un **workflow** es un archivo YAML en `.github/workflows/` que dice:

> "Cuando ocurra *estos eventos*, ejecuta *estos jobs*."

Es una pieza versionada del repo. Cambiarlo es un commit más. Puede haber muchos workflows en el mismo repo; cada uno es independiente.

### 2.3 Job

Un **job** es una unidad de ejecución que corre en **un único runner**. Un workflow puede tener uno o varios jobs. Por defecto los jobs corren en **paralelo**; puedes forzar orden con `needs:`.

Cada job tiene:
- Un nombre (`build`, `test`, `deploy`).
- Un runner (`runs-on: ubuntu-latest`).
- Una lista de steps.

Dos jobs del mismo workflow **no comparten disco por defecto** — si quieres pasar archivos entre ellos, usas *artifacts* (se cubre en `gha-07`).

### 2.4 Step

Un **step** es un comando o invocación dentro de un job. Hay dos tipos:

- **`run:`** — ejecuta shell (bash por default en Linux/macOS, PowerShell en Windows). Es tu código.
- **`uses:`** — invoca una **action** (una pieza reutilizable publicada en GitHub). Es código ajeno (o tuyo publicado) que se ejecuta como un módulo.

Los steps corren **secuencialmente** dentro del job, en el mismo proceso de runner, compartiendo el mismo filesystem.

### 2.5 Runner

Un **runner** es la máquina (VM o contenedor) donde el job corre. Puede ser:

- **GitHub-hosted**: VM efímera provista por GitHub (`ubuntu-latest`, `windows-latest`, `macos-latest`, variantes ARM, GPU, larger runners). Se crea limpia para cada job y se destruye al terminar.
- **Self-hosted**: una máquina tuya (bare metal, VM, o pod en Kubernetes vía ARC) que corre el *runner agent* y recibe trabajo del scheduler. Útil para datos sensibles, hardware especial, o costo. Se verá en `gha-11`.

La VM hosted por GitHub trae **preinstalado** mucho: compiladores, Node, Python, JDK, Docker, kubectl, aws-cli, git, gh, y cientos más. Esta "runner image" es un documento actualizado por GitHub y la razón por la cual tu primer workflow no requiere instalar casi nada.

### 2.6 La cadena, en orden

```
         usuario hace push
                │
                ▼
    ┌────────────────────────┐
    │  GitHub recibe evento  │
    │  "push" en main        │
    └────────────────────────┘
                │  publica
                ▼
    ┌────────────────────────┐
    │  Scheduler de Actions  │
    │  busca workflows con   │
    │  on: push coincidentes │
    └────────────────────────┘
                │  encola 1 run por workflow
                ▼
    ┌────────────────────────┐
    │  Workflow run (uuid)   │
    │  jobs: build, test...  │
    └────────────────────────┘
                │  por cada job
                ▼
    ┌────────────────────────┐
    │  Asigna runner libre   │
    │  (ubuntu-latest, ...)  │
    └────────────────────────┘
                │
                ▼
    ┌────────────────────────┐
    │  Runner ejecuta steps  │
    │  uno a uno, en orden   │
    │  stream de logs → UI   │
    └────────────────────────┘
                │  al terminar
                ▼
    ┌────────────────────────┐
    │  Resultado: success /  │
    │  failure / cancelled.  │
    │  Commit queda con un   │
    │  check verde o rojo.   │
    └────────────────────────┘
```

Memoriza esta cadena. Es toda la ingeniería de alto nivel de GitHub Actions.

---

## 3. Contexto histórico

- **Octubre 2018** — GitHub anuncia Actions como una beta orientada a *contenedores encadenados* (un modelo distinto al actual, donde cada acción era un contenedor cuyo stdout alimentaba al siguiente).
- **Agosto 2019** — Rediseño: aparece el modelo YAML actual con `on:`, `jobs:`, `steps:`, `uses:`, `run:`. GA en noviembre de 2019.
- **2020** — Marketplace crece rápido. Aparece `actions/checkout@v2` como estándar.
- **2021** — OIDC a cloud providers (AWS, GCP, Azure, HashiCorp Vault) sin almacenar access keys.
- **2022** — Reusable workflows (`workflow_call`), composite actions, environments con required reviewers.
- **2023** — Larger runners (más CPU/RAM), ARM runners, deployment protection rules, merge queues.
- **2024–2025** — Build provenance / attestations SLSA integradas vía Sigstore, immutable actions (releases firmadas), Artifact Attestations GA.
- **2026** — Model estable; el foco está en seguridad de la supply chain del pipeline y en control de costo (minutos privados y larger runners pueden ser caros).

GitHub Actions no apareció en el vacío. Nació compitiendo contra Jenkins (líder incumbente), Travis CI (que servía al mundo open source), CircleCI, GitLab CI (dentro de GitLab), Azure Pipelines, Buildkite y Drone. Ganó mindshare por **integración nativa**: si tu código ya vive en GitHub, instalar GHA es escribir un archivo YAML en una carpeta.

---

## 4. Funcionamiento interno

Vamos de arriba hacia abajo: qué hace cada eslabón cuando tú haces push.

### 4.1 El bus de eventos y el scheduler

Cuando pusheas, el servidor de GitHub serializa el evento y lo publica en un bus interno. El servicio de Actions se suscribe a todos los eventos relevantes. Para cada evento consulta: *¿qué workflows en qué repos tienen `on:` que haga match con esto?* Para cada match, crea un **workflow run**: una entidad persistente con ID, estado (`queued`, `in_progress`, `completed`), payload del evento, SHA del commit disparador, actor, y lista de jobs declarados.

El scheduler encola los jobs. Cada job espera un runner disponible del tipo que pidió (`runs-on`).

### 4.2 La runner image

Un runner `ubuntu-latest` **no** es "Ubuntu limpio recién instalado". GitHub mantiene una **runner image** (hoy ~90 GB en disco) con cientos de herramientas preinstaladas: Node (varias versiones), Python (varias), JDK, .NET, Docker, kubectl, Terraform, aws-cli, gh, git, azcopy, etc. Esto es por qué tu primer workflow no instala nada.

La lista completa, versionada por SO, vive en: `https://github.com/actions/runner-images` (directorio `images/` con un README por imagen). Útil consultar antes de añadir un `apt install` innecesario.

Al asignar un job, GitHub provisiona una VM con esa imagen, crea un usuario (`runner`), monta un workspace vacío en `/home/runner/work/<repo>/<repo>`, y lanza el runner agent. El agente se conecta de vuelta al servicio de Actions, descarga la definición del job y empieza a ejecutar steps.

### 4.3 El workspace y la ausencia de checkout automático

Aquí la trampa que casi todo principiante encuentra: **el runner llega con el workspace vacío**. GitHub *no* clona tu repo automáticamente. Debes hacerlo tú con el step `uses: actions/checkout@v4`.

¿Por qué no es automático? Tres razones:
1. **No siempre quieres código.** Un workflow que solo etiqueta issues no necesita checkout.
2. **No siempre quieres *ese* checkout.** Puedes querer un ref distinto, submódulos, LFS, depth=0, otro repo, etc.
3. **Para ciertos triggers es inseguro.** En `pull_request` desde un fork, el código del PR es ajeno; GitHub quiere que *tú* decidas conscientemente qué checkear (y nunca da secretos a ese workflow). Se profundiza en `gha-03`.

### 4.4 El step `actions/checkout`

Es la action más usada del ecosistema. Lo que hace, resumido:

- Lee del contexto `github` el repo y el SHA a checkear.
- Autentica con un token efímero (`GITHUB_TOKEN`).
- `git init && git fetch` del SHA.
- Deja el workspace poblado.

Por default clona solo el commit disparador con `depth=1` (shallow). Si necesitas historia completa (p. ej. para `git describe`), le pasas `fetch-depth: 0`.

### 4.5 `uses` vs `run`

- **`run: echo hola`** — ejecuta `echo hola` en el shell del runner. Es *tu* comando. Hereda `env`, `cwd` del step, y comparte filesystem con los demás steps del job.
- **`uses: actions/checkout@v4`** — invoca una *action*. Una action es un repo (o path en un repo) con un `action.yml` que declara inputs/outputs y define cómo ejecuta (puede ser JavaScript, Docker, o composite). GitHub descarga la action antes de correr el step y la ejecuta aislada, pero compartiendo workspace.

Operacionalmente:
- `run:` es flexibilidad total con costo cognitivo: tú escribes todo.
- `uses:` es reutilización: alguien resolvió el problema; tú le pasas inputs.

En un workflow real típico ves los dos mezclados: `uses: actions/checkout@v4`, `uses: actions/setup-python@v5`, luego `run: pip install -r requirements.txt && pytest`.

### 4.6 El contexto `github`

Durante la ejecución, el runner tiene disponible un objeto llamado `github` con metadata del evento. Lo verás en `gha-02` con detalle, pero a este nivel:

- `github.repository` — "owner/repo".
- `github.ref` — ref disparador (`refs/heads/main`).
- `github.sha` — commit SHA del evento.
- `github.event_name` — `push`, `pull_request`, etc.
- `github.actor` — usuario que disparó.
- `github.workflow`, `github.run_id`, `github.run_number`, etc.

De dónde sale: GitHub lo rellena desde el payload del evento *antes* de dispatcher el job. El runner lo recibe como variables de entorno (`GITHUB_REPOSITORY`, `GITHUB_SHA`, etc.) y como el objeto `github` en expresiones `${{ … }}`.

### 4.7 La UI: runs, logs, re-run

En `https://github.com/<owner>/<repo>/actions` verás:

- **Lista de workflow runs**: por workflow, con filtros por branch, estado, actor, evento.
- Al abrir un run: la lista de jobs, cada uno con sus steps y el log *en streaming*.
- Botones **"Re-run all jobs"** y **"Re-run failed jobs"** — útil para fallos transitorios. **Importante**: por default re-run usa la *misma* definición del workflow que corrió originalmente (el SHA del commit en el que vive el YAML), no la última.
- Status checks en la vista del commit y del PR: verde / rojo / amarillo según resultado.

### 4.8 Minutos y billing

GitHub cobra por **minutos de runner-hosted** en repos privados; en repos públicos los runners estándar son gratis (hasta hoy, 2026).

- Linux: 1x consumo (minuto facturado por minuto real).
- Windows: 2x.
- macOS: 10x (ARM runners son más baratos que los x86 pero siguen caros).
- Larger runners (más CPU/RAM): múltiplos adicionales.
- Self-hosted: $0 de factura GHA; tú pagas la máquina.

En planes free hay ~2000 minutos/mes de runners Linux para repos privados. Un pipeline mal diseñado puede consumirlos rápido (p. ej. matriz grande × cada push × retry). Se trata en `gha-15` (control de costo a nivel org).

---

## 5. Ejemplo mínimo

El workflow más corto útil (lo encontrarás en `examples/01-hello-world/`):

```yaml
# .github/workflows/hello.yml
name: hello

on:
  push:
  pull_request:

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "Hola desde $GITHUB_REPOSITORY"
          echo "Commit: $GITHUB_SHA"
          echo "Evento: $GITHUB_EVENT_NAME"
          ls -la
```

Léelo de arriba abajo:

- **`name:`** — el nombre humano del workflow (lo que ves en la UI). Opcional; si lo omites, GitHub usa el nombre del archivo.
- **`on:`** — qué eventos lo disparan. Aquí: cualquier `push` a cualquier rama y cualquier `pull_request`.
- **`jobs:`** — mapping de jobs. Clave = ID técnico (`greet`); valor = definición.
- **`runs-on:`** — tipo de runner (VM hosted de Ubuntu).
- **`steps:`** — lista ordenada. El primero clona el repo; el segundo ejecuta shell con variables de entorno del contexto.

Si lo pones en `.github/workflows/hello.yml` y pusheas: en ~30 segundos aparece un run verde en la pestaña Actions, con los `echo` en los logs.

---

## 6. Implementación progresiva

Añadamos un segundo job que corra tests, y veamos qué cambia.

```yaml
name: ci

on:
  push:
  pull_request:

jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Entorno
        run: |
          echo "OS: $(uname -a)"
          echo "Node: $(node --version)"
          echo "Python: $(python3 --version)"
          echo "Git: $(git --version)"

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Correr tests triviales
        run: |
          echo "assert 1 == 1" > ok.py
          python3 ok.py
          echo "tests OK"
```

Observa:

- **Dos jobs** → corren en **paralelo** en dos runners distintos. Si uno falla, el otro sigue (salvo `needs:` o `fail-fast`).
- Cada job **re-ejecuta `actions/checkout`**: no comparten disco. Esta es la fuente de la pregunta de principiante "¿por qué tengo que hacer checkout dos veces?".
- `name:` dentro de un step es *opcional* pero muy recomendado — es el título visible en la UI del log.
- No instalamos Node ni Python; vienen preinstalados en `ubuntu-latest`.

Si en el PR cambias el YAML (p. ej. añades otro step), **la nueva versión del workflow corre con el nuevo YAML**: el workflow se lee del repo *en el commit disparador*, no del commit de `main`. Esto es importante y a veces contraintuitivo.

---

## 7. Aplicación profesional

En producción, un workflow mínimo "serio" para un proyecto Python se ve así (lo construirás en módulos siguientes; aquí solo para que lo reconozcas):

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -r requirements.txt
      - run: ruff check .
      - run: pytest -q
```

Cosas que ya puedes "ver" sin saber todavía `gha-02` a `gha-05`:

- `permissions: contents: read` — mínimo privilegio del `GITHUB_TOKEN` (se detalla en `gha-05`).
- `with:` — inputs de una action (aquí `actions/setup-python`).
- `cache: pip` — cachea dependencias entre runs (se detalla en `gha-07`).
- La action está **pinneada a `@v5`** — un tag mutable, aceptable para actions oficiales de GitHub; para actions de terceros se recomienda pin a SHA (ver `gha-04`).

### 7.1 Qué revisar al llegar a un repo ajeno

Un reflejo útil cuando entras a un repo nuevo:

1. `ls .github/workflows/` → ¿cuántos workflows hay?
2. Para cada uno: `cat` y leer `on:` → ¿cuándo corre?
3. ¿Qué permissions declara?
4. ¿Qué actions usa? ¿Oficiales, de vendor, terceros desconocidos? ¿Pinneadas a SHA?
5. ¿Hay matrix? ¿Hay `needs:` (dependencias entre jobs)?
6. ¿Dónde publica artefactos (si lo hace)?

Con esta lección solo puedes contestar las primeras 2–3. El resto llega en los módulos siguientes.

---

## 8. Trade-offs

### 8.1 GitHub Actions vs alternativas

| Dimensión | GitHub Actions | GitLab CI | Jenkins | CircleCI |
|-----------|---------------|-----------|---------|----------|
| Integración con repo | Nativa si repo en GitHub | Nativa si repo en GitLab | Externa (webhook) | Externa (webhook) |
| Pipeline-as-code | YAML en `.github/workflows/` | `.gitlab-ci.yml` | Jenkinsfile (Groovy) | `.circleci/config.yml` |
| Marketplace de reusables | Amplio (Actions) | Templates + CI/CD catalog | Plugins (muchísimos, mezcla de calidad) | Orbs |
| Runners hosted | Linux/Mac/Windows/ARM/GPU | Linux (SaaS limitado) | No (self-hosted siempre) | Linux/Mac/Windows |
| Self-hosted | Sí, incluyendo ARC/K8s | Sí, muy maduro | Nativo | Sí |
| Secretos nativos | Repo / env / org | Variables de proyecto/grupo | Credentials plugin | Project / contexts |
| OIDC a clouds | Sí, pionero | Sí | Vía plugin | Sí |
| Curva de aprendizaje | Suave si YAML / Git ya conocido | Suave | Dura (Groovy, plugins) | Media |

Reglas prácticas:
- Si el repo vive en GitHub, usa GHA salvo razón fuerte en contrario.
- Si estás en GitLab, usa GitLab CI.
- Jenkins es la opción cuando necesitas plugins muy específicos o compliance que exige self-hosted completo.
- CircleCI brilla en empresas que ya lo tienen desplegado y en orbs ricos.

### 8.2 Hosted vs self-hosted vs ARC

| | Hosted | Self-hosted estático | ARC (Kubernetes) |
|---|--------|---------------------|------------------|
| Costo | $$ por minuto (free en repos públicos) | $ (hardware tuyo, pero fijo) | $ (escalado a demanda) |
| Mantenimiento | 0 | Alto | Medio |
| Herramientas preinstaladas | Muchísimas | Lo que instales | Lo que esté en la imagen |
| Datos sensibles | Nunca tocan tu red | OK | OK |
| Hardware especial (GPU, ARM) | Sí (pagando) | Sí si lo compras | Depende del cluster |
| Elasticidad | Infinita (en teoría) | Fija | Alta |
| Inicio de un job | ~segundos | Inmediato si idle | ~segundos (crear pod) |

A nivel org, muchas empresas combinan los tres. Se profundiza en `gha-11`.

### 8.3 YAML: pros y contras

Pros: declarativo, legible, diff-friendly, universal.

Contras: la sintaxis con `${{ … }}` termina siendo un mini-lenguaje; indentación errónea rompe cosas de forma sutil; las expresiones no se tipean. Es la fuente #1 de "funciona en mi laptop pero no en Actions" junto con las *runner images*.

---

## 9. Errores frecuentes

### 9.1 Olvidar `actions/checkout`

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: ls -la      # ← vacío
      - run: pytest       # ← pytest: command not found; o: no tests
```

El workspace está vacío. Añade `- uses: actions/checkout@v4` como primer step.

### 9.2 Esperar que dos jobs compartan disco

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: make dist
  publish:
    runs-on: ubuntu-latest
    steps:
      - run: ls dist/     # ← no existe; `publish` corrió en otro runner
```

Para pasar archivos entre jobs necesitas `actions/upload-artifact` + `actions/download-artifact`. Se cubre en `gha-07`.

### 9.3 Workflow fuera de `.github/workflows/`

GitHub **no** detecta workflows en otras rutas. `workflows/ci.yml` o `.github/ci.yml` no funcionan. La ruta exacta es `.github/workflows/*.yml` (o `*.yaml`), **en la rama disparadora**.

### 9.4 YAML con tabs o indentación mezclada

YAML prohíbe tabs; usa 2 espacios consistentes. El error típico "mapping values are not allowed in this context" casi siempre es indentación.

### 9.5 `on: push` sin filtro en una rama costosa

```yaml
on:
  push:
```

Dispara en **cualquier** push a **cualquier** rama. Si tu matriz es grande, puedes consumir minutos sin querer. En producción se suele filtrar: `branches: [main]` y usar `pull_request` para el resto.

### 9.6 Confundir el `name:` del workflow con `runs-on:`

El `name:` es decorativo (lo que ves en la UI). `runs-on:` define el SO. Son cosas distintas; el error de principiante es poner `name: ubuntu-latest`.

### 9.7 Pensar que `uses: actions/checkout@v4` descarga código de internet "sin control"

El código viene del repo público `actions/checkout` en GitHub, en el tag `v4` (que apunta a un SHA). Es público, auditable, y mantenido por GitHub. El riesgo real surge con actions de **terceros desconocidos** o actions pinneadas a tags mutables que luego son reescritos — tema de `gha-04`.

### 9.8 Re-run no re-lee el YAML más reciente

"Re-run failed jobs" usa el YAML del commit disparador (el SHA en el que ocurrió el run), no `main` actual. Si cambiaste el workflow en `main` y haces re-run de un run viejo, el YAML viejo gana. Para probar un YAML nuevo, haz un commit nuevo.

---

## 10. Buenas prácticas

- **Pon un workflow mínimo desde el commit 1 del repo**. "CI más tarde" es un olor de proceso.
- **Siempre `actions/checkout@vN` como primer step** si tu job toca código.
- **Dale `name:` a cada step** (opcional pero hace que los logs sean legibles).
- **Un workflow = un propósito**. `ci.yml`, `release.yml`, `nightly.yml`, en vez de un `all.yml` monolítico.
- **Prefiere `runs-on: ubuntu-latest`** salvo que necesites algo específico — es lo más barato y rápido.
- **No instales lo que ya está preinstalado**. Consulta `actions/runner-images` antes de un `apt-get install`.
- **Lee los logs completos la primera vez** — entenderás todo el entorno antes de automatizar.
- **Trata el YAML con la misma seriedad que el código**: PRs, revisión, tests (más adelante con `act` o workflows de prueba).
- **No pongas secretos en el YAML**. Nunca. Usa `secrets.*` (se verá en `gha-05`).
- **Mantén un hábito de "mínimos permisos"**: `permissions: contents: read` por default y escala por job cuando haga falta (`gha-05`).

---

## 11. Ejercicios recomendados

1. **`examples/01-hello-world/`** — reproduce y lee la salida comparándola con lo predicho.
2. **`examples/02-run-vs-uses/`** — compara dos jobs equivalentes.
3. **`activities/01-first-workflow/`** — construye y valida tu primer workflow (dual-mode local/live). **Guided-lab**.
4. **`activities/02-read-and-explain/`** — lee un workflow ajeno y predice su comportamiento. **Independent** — es la que valida comprensión real.

---

## 12. Evaluación

Responde sin consultar la lección. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Ordena correctamente la cadena que ocurre tras un `git push`:
   - [ ] runner descarga action
   - [ ] GitHub recibe evento `push`
   - [ ] workflow run se crea
   - [ ] scheduler busca workflows que hagan match con el evento
   - [ ] steps se ejecutan secuencialmente
   - [ ] runner VM se provisiona

**P2.** ¿Verdadero o falso?
   - [ ] El runner clona el repo automáticamente antes del primer step.
   - [ ] Dos jobs del mismo workflow comparten filesystem.
   - [ ] `runs-on: ubuntu-latest` crea una VM limpia por job.
   - [ ] `uses: actions/checkout@v4` descarga código ajeno sin pin fijo.
   - [ ] Un workflow en `my-workflows/ci.yml` también es detectado.

**P3.** Explica en 2–3 frases la diferencia entre `run:` y `uses:` y cuándo elegirías cada uno.

**P4.** Dado este workflow, enumera *todo* lo que pasa paso a paso, y qué imprimirá:
```yaml
name: demo
on: [push]
jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "$GITHUB_REPOSITORY @ $GITHUB_SHA"
      - run: git log -n1 --format='%s'
```

**P5.** Un compañero dice: "añadí un segundo job y necesito los archivos que generó el primero; ¿por qué no están?". ¿Qué le respondes y qué opción le propones?

**P6.** ¿Por qué GitHub **no** clona el repo automáticamente, dado que es la operación más común en un pipeline? Enumera al menos dos razones.

**P7.** Dado un repo público con un workflow en `.github/workflows/ci.yml` que corre en `push: [main]`, ¿se dispara con un `push` a una rama `feature/x`? ¿Por qué?

**P8.** Diseño: te piden añadir CI a un repo de un script bash de 50 líneas. Explica qué workflow mínimo escribirías, qué triggers, qué pasos, y por qué.

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Understanding GitHub Actions*. <https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions>
- *Workflow syntax for GitHub Actions*. <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions>
- *Events that trigger workflows*. <https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows>
- *About GitHub-hosted runners*. <https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners>
- Repositorio **actions/runner-images** con listado por SO. <https://github.com/actions/runner-images>
- Action **actions/checkout**. <https://github.com/actions/checkout>
- *About billing for GitHub Actions*. <https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions>

Lectura complementaria:

- *The GitHub Blog — Actions-tagged posts*. <https://github.blog/tag/github-actions/>
- *Awesome Actions* (índice comunitario). <https://github.com/sdras/awesome-actions>
