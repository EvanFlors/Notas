# jk-04 — Lección: Scripted Pipeline y Shared Libraries

> 10 secciones. Mayoritariamente de lectura y revisión de código Groovy. Prerrequisito: `jk-03`.

---

## 1. Dos lenguajes de pipeline bajo el mismo motor

Jenkins Pipeline tiene dos "dialectos" encima del mismo motor de ejecución (`CPS-transformed Groovy`):

- **Declarative Pipeline**: DSL estructurado dentro de un bloque `pipeline { ... }`. Chequeos estáticos, orden rígido de secciones, menos flexibilidad, mantenible por humanos no-Groovy. Es el estilo recomendado para código nuevo desde 2017.
- **Scripted Pipeline**: Groovy "casi puro" dentro de un bloque `node { ... }`. Flexible, imperativo, sin estructura obligatoria, difícil de leer para quien no sabe Groovy. Es lo que ves en el 90% de las instalaciones anteriores a 2018.

Ambos ejecutan sobre el mismo motor y pueden coexistir: dentro de un pipeline declarative puedes abrir un bloque `script { ... }` y escribir Groovy imperativo. Esto es un *escape hatch* legítimo pero debería ser el **último recurso**: cada `script {}` cancela los chequeos del DSL y empuja hacia la mantenibilidad baja de scripted.

> **Idea clave:** la elección Scripted vs Declarative no es sobre poder expresivo (ambos ejecutan Groovy). Es sobre **gobernanza**: Declarative te prohíbe escribir cosas que luego nadie va a entender; Scripted te deja hacerlo todo, incluido lo que no deberías.

---

## 2. Scripted Pipeline: el estilo legacy

Un pipeline scripted mínimo:

```groovy
node('linux') {
  stage('Checkout') {
    checkout scm
  }
  stage('Build') {
    sh 'make build'
  }
  stage('Test') {
    try {
      sh 'make test'
    } finally {
      junit 'reports/*.xml'
    }
  }
}
```

Qué estás viendo:

- `node('linux')`: aloja un agent con label `linux` para el bloque entero y le reserva un workspace.
- `stage('...')`: delimita secciones visibles en Blue Ocean / pipeline view.
- `sh`, `checkout`, `junit`: *steps* globales del DSL.
- `try/finally`: Groovy puro — un pipeline scripted puede usar cualquier control de flujo del lenguaje (`if`, `for`, `switch`, `return`, excepciones). Esto es simultáneamente su mayor virtud (flexibilidad) y su mayor defecto (nadie sabe qué hace tu `for (def repo in repos) { ... }` seis meses después).

**Cuándo lo encontrarás**: en jobs que llevan años en el controller, migrados a `Jenkinsfile` pero sin reescribir, o escritos a mano por un SRE que "no quería pelearse con las limitaciones del declarative". No vas a escribir scripted nuevo en 2026, pero vas a **leerlo** mucho.

---

## 3. El escape hatch: `script {}` dentro de Declarative

```groovy
pipeline {
  agent any
  stages {
    stage('Compute version') {
      steps {
        script {
          def tag = sh(script: 'git describe --tags --always', returnStdout: true).trim()
          env.VERSION = tag
        }
      }
    }
    stage('Build') {
      steps { sh "docker build -t app:${env.VERSION} ." }
    }
  }
}
```

Casos legítimos para `script {}`:

- Calcular un valor dinámico (versión semántica, nombre de artefacto) basado en comandos shell.
- Iterar sobre una lista proveniente de un paso previo (p. ej. shards de tests).
- Manejar errores con lógica no trivial que `post { failure {...} }` no cubre.

Casos **ilegítimos** (y comunes):

- "Es que quería un `if` complicado" → casi siempre se expresa con `when { expression { ... } }`.
- "Quería paralelizar algo exótico" → `parallel { ... }` ya existe.
- "Quería leer un YAML" → mete esa lógica en un step de la Shared Library y llama al step desde `steps`.

La regla: si tu `script {}` ocupa más de 10 líneas, muévelo a `vars/` de la Shared Library. Si tiene estado o varios métodos, muévelo a `src/`.

---

## 4. Shared Libraries: el modelo mental

Una **Shared Library** es un repositorio Git (o un path local, pero eso solo sirve en lab) con un layout preestablecido que Jenkins **carga en el classpath del pipeline** cuando lo pides con `@Library`.

Layout canónico (los tres directorios se buscan **exactamente** con esos nombres):

```
<repo-root>/
├── vars/
│   ├── standardBuild.groovy      # define 'standardBuild()' como step global
│   ├── standardBuild.txt         # (opcional) ayuda para el DSL editor
│   ├── notifySlack.groovy
│   └── buildAndPush.groovy
├── src/
│   └── org/
│       └── acme/
│           └── ci/
│               ├── BuildContext.groovy    # clase Groovy
│               ├── Image.groovy
│               └── Notifier.groovy
└── resources/
    └── org/
        └── acme/
            └── ci/
                ├── pipeline-settings.yaml   # leíble con libraryResource(...)
                └── slack-template.md
```

Semántica:

- **`vars/foo.groovy`** define un step global `foo()`. Jenkins toma el fichero, instancia la clase que contiene y expone el método `call(...)` como invocable: `foo(arg1: 'x')`. Cada archivo = un step público. **No pongas lógica compleja aquí**; delega en clases bajo `src/`.
- **`src/<package>/<Class>.groovy`** son clases Groovy "normales" (con `package`, `class`, `def method() { ... }`). Jenkins las compila y las deja disponibles al pipeline con `import org.acme.ci.BuildContext`. Aquí vive la lógica reutilizable: dominios, modelos, helpers.
- **`resources/<package>/<file>`** son ficheros estáticos (YAML, Markdown, plantillas) accesibles con `libraryResource('org/acme/ci/pipeline-settings.yaml')`. Nunca compiles, solo leíbles.

Esto no es convención opcional: Jenkins **ignora** cualquier otro layout. No puedes meter steps en `src/`, ni clases en `vars/`, ni resources fuera de `resources/`.

---

## 5. `@Library` y el pinning por versión

Desde un `Jenkinsfile`:

```groovy
@Library('acme-ci@v1.3.0') _
standardBuild(
  image: 'app',
  registry: 'ghcr.io/acme',
  deploy: ['dev', 'stg']
)
```

Qué hace la primera línea:

- `acme-ci` es el **nombre lógico** de la library, configurado en `Manage Jenkins > System > Global Pipeline Libraries` (o en el folder) con su URL y credenciales.
- `v1.3.0` es la versión: un **tag, branch o SHA del repo** de la library.
- El `_` al final es un hack sintáctico de Groovy (necesita algo a lo que aplicar la anotación `@Library`). Sí, parece feo. Es la forma oficial.

Cuatro variantes y sus consecuencias:

| Forma | Qué significa | Prod ok? |
|-------|---------------|----------|
| `@Library('acme-ci') _` | Carga la versión *default* configurada por el admin (habitualmente `main`). | **No** — el pipeline cambia bajo tus pies cuando alguien mergea a `main`. |
| `@Library('acme-ci@main') _` | Siempre la última de `main`. | **No** — mismo problema, explícito. |
| `@Library('acme-ci@v1.3.0') _` | Tag inmutable. | **Sí** — reproducible y auditable. |
| `@Library('acme-ci@abc1234') _` | SHA. | **Sí**, pero menos legible que un tag semver. |

**Regla**: nunca pin a branch en producción. Un tag semver (`v1.3.0`) es ideal porque permite revisión en PR antes de "liberar" la versión a los consumidores.

**Admin override**: el administrador puede marcar la library como *"Allow default version to be overridden"* para dejar que los `Jenkinsfile` sobrescriban la default, y *"Include @Library changes in job recent changes"* para que el changelog del job incluya el bump de versión.

---

## 6. Patrones típicos: `standardBuild()` y amigos

El patrón **"facade step"** es la receta más común. En lugar de que cada repo tenga 200 líneas de Jenkinsfile, la library expone:

```groovy
standardBuild(
  image: 'checkout-api',
  registry: 'ghcr.io/acme',
  deploy: ['dev'],
  requireApproval: true,
  skipSast: false
)
```

Y el `Jenkinsfile` del repo consumidor queda en 15 líneas:

```groovy
@Library('acme-ci@v1.3.0') _
standardBuild(
  image: 'checkout-api',
  registry: 'ghcr.io/acme',
  deploy: ['dev', 'stg', 'prod'],
  requireApproval: true
)
```

Qué encapsula el step típico:

1. `agent { kubernetes { ... } }` opinado (o `docker`).
2. Stages: checkout → lint → test → SAST → build → push → deploy a lista de entornos.
3. Credentials binding estándar (registry, Vault, cloud).
4. `post { always { notifySlack(...) } failure { pageOnCall(...) } }`.
5. Parámetros con defaults sensatos y validación (p. ej. "`deploy` debe ser subset de `['dev','stg','prod']`").

Beneficios concretos:

- Un cambio en el pipeline estándar (añadir SAST, cambiar runner) requiere **un PR en la library**, no 50 PRs en 50 repos.
- Los repos consumidores actualizan "cuando quieran" subiendo el tag.
- La review de pipelines nuevos es trivial: todos los repos lucen igual.

Costes:

- La library se vuelve el **cuello de botella**: romper la library rompe a todos los consumidores que estén en la última versión.
- Hay que diseñar la API con cuidado: romper backwards compat requiere mayor estrategia (deprecaciones, dual-path, major bump).
- Testear la library sin un controller real es trabajoso (ver §8).

---

## 7. Governance: CODEOWNERS, PR y tagging

Una Shared Library sin disciplina de PR es un vector de ataque y de fallo. Reglas mínimas:

- **CODEOWNERS**: `*` → equipo de Platform. Los PRs requieren aprobación de Platform.
- **PR obligatorio** sobre `main`. Sin pushes directos.
- **CI de la library misma**: lint (`npm-groovy-lint` o similar) + tests con **JenkinsPipelineUnit**.
- **Tags semver** manuales o con `release-please`. Nunca `main` como default en prod.
- **CHANGELOG.md** con la lista de breaking changes por tag.
- **Branch protection** sobre `main` y sobre tags `v*`.

Riesgo específico de Jenkins: una library con **permisos Groovy sin sandbox** puede ejecutar código arbitrario con los privilegios del controller. Si tu admin marcó la library como "trusted" (opción global), **cualquier commit a `main` corre como admin**. Combinado con un `@Library('name@main')` en los consumidores = compromiso del controller con un PR malicioso. Un tag inmutable + revisión obligatoria mitigan esto.

---

## 8. Testing: JenkinsPipelineUnit

Testear una Shared Library sin un controller es viable pero no trivial. El framework estándar es **JenkinsPipelineUnit**: provee un `BasePipelineTest` que mockea los steps (`sh`, `checkout`, `withCredentials`...) y permite afirmar sobre la secuencia de llamadas.

Esquema conceptual (no ejecutamos en este módulo):

```groovy
class StandardBuildTest extends BasePipelineTest {
  @Test
  void deploys_only_requested_envs() {
    def script = loadScript('vars/standardBuild.groovy')
    script.call(image: 'x', deploy: ['dev'])
    assertThat(helper.callStack).contains(call('sh', 'kubectl apply ... dev'))
    assertFalse(helper.callStack.any { it.contains('prod') })
  }
}
```

Compromiso del módulo: **validamos layout, invocación, y pinning**. No ejecutamos el DSL ni corremos JenkinsPipelineUnit en los validadores (requeriría JVM + Gradle/Maven, fuera de scope). Se cita como lectura obligatoria para quien vaya a mantener una library en prod.

---

## 9. Migración desde script embebido

Mapa típico de refactor desde un pipeline monolítico:

| Antes (en `Jenkinsfile` de 200 líneas) | Después |
|----------------------------------------|---------|
| `script { def ver = sh(...) }` repetido en 10 repos | Step `computeVersion()` en `vars/computeVersion.groovy`. |
| 40 líneas de notificación Slack | Step `notifySlack(status, channel)` en `vars/notifySlack.groovy` + plantilla en `resources/`. |
| Clase con 5 métodos helper dentro de `script {}` | Clase `src/org/acme/ci/Notifier.groovy`. |
| Secuencia completa checkout→lint→test→build→push→deploy | Step `standardBuild(args)` en `vars/standardBuild.groovy` orquestando lo anterior. |

Orden recomendado:

1. **Extraer helpers primero** (`notifySlack`, `computeVersion`) — menos riesgo, resultado inmediato.
2. **Introducir la fachada** (`standardBuild`) sin cambiar comportamiento (parity test).
3. **Pin consumidores** a un tag (`v0.1.0`) incluso si solo hay un consumidor.
4. **Reescribir internamente** la library sin romper el contrato público.

---

## 10. Checklist de hardening de una library heredada

- `@Library('name@main')` → cambiar a `@Library('name@vX.Y.Z')` en todos los consumidores.
- Sin `CODEOWNERS` → añadir uno con el equipo responsable.
- Sin branch protection en `main` → activar; requerir PR + review.
- Sin tests → introducir JenkinsPipelineUnit aunque sea para los 2 steps más usados.
- Library marcada "trusted" sin razón → cambiar a untrusted + usar `@NonCPS` solo donde necesario.
- `vars/` con ficheros de 500 líneas → extraer clases a `src/`.
- `resources/` vacío con texto embebido en strings Groovy multilinea → mover a `resources/`.
- Sin CHANGELOG → generarlo retroactivamente desde los tags git.

Si tu library tiene 5+ de estos puntos, **no bumpees versión** antes de arreglar al menos los tres primeros. El riesgo de que un commit cualquiera comprometa el controller supera el beneficio del cambio.
