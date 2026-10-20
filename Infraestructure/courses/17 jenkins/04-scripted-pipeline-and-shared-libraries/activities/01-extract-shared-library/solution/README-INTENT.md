# Refactor a Shared Library — acme-ci

> Documento de intención: por qué el monolito se partió así y qué garantías ofrece el nuevo diseño. El código Groovy está en los archivos adyacentes.

## Resumen

El pipeline estándar de la organización se extrae a una Shared Library (`acme-ci`) con layout canónico. Cada repo consumidor queda con un `Jenkinsfile` de menos de 15 líneas que carga la library con pin por **tag semver** e invoca el step `standardBuild(...)`.

| Antes | Después |
|-------|---------|
| 15 `Jenkinsfile` de ~180 líneas cada uno | 15 `Jenkinsfile` de ~10 líneas + 1 library versionada. |
| Un cambio al pipeline estándar = 15 PRs. | Un cambio = 1 PR a la library + bump de tag en consumidores. |
| Deriva incontrolada entre repos. | Un único punto de verdad, auditable por `git log`. |

---

## Layout

El layout respeta exactamente las convenciones de Jenkins (los nombres de los tres directorios no son opcionales):

```
acme-ci/
├── vars/standardBuild.groovy
├── src/org/acme/ci/BuildContext.groovy
└── resources/org/acme/ci/pipeline-settings.yaml
```

### Qué va en `vars/`

Steps públicos invocables desde el `Jenkinsfile`. Un archivo = un step. El método se llama `call(...)` y Groovy lo invoca cuando el consumidor escribe `standardBuild(args)`. **No ponemos lógica compleja aquí**: `standardBuild.groovy` valida argumentos, construye un `BuildContext` y orquesta las stages. Toda la lógica de dominio (resolver `imageRef`, decidir si deploysTo un entorno) vive en `src/`.

### Qué va en `src/`

Clases Groovy "normales" con `package`, `class`, propiedades y métodos. `BuildContext` modela los parámetros del build y sus derivaciones. Lo movemos aquí (y no a `vars/`) porque:

1. Es más de una función: tiene estado (`image`, `registry`, `deploy`) y comportamiento (`imageRef()`, `deploysTo()`).
2. Permite testing con `JenkinsPipelineUnit` o con un `GroovyShell` sin cargar el DSL completo.
3. El `import` explícito desde `vars/` deja clara la dependencia.

**`Serializable`** es obligatorio: el motor CPS de Jenkins serializa el estado del pipeline a disco cuando un step cede la ejecución (p. ej. `input` humano, `sleep`, suspensión del controller). Si `BuildContext` no implementara `Serializable`, el pipeline fallaría con `NotSerializableException` en el primer step que ceda. Es la fuente nº 1 de errores oscuros en libraries nuevas.

### Qué va en `resources/`

Ficheros estáticos accesibles con `libraryResource('org/acme/ci/pipeline-settings.yaml')`. Son defaults de la organización que **no cambian a nivel de repo consumidor** (registry, canal de Slack, timeouts estándar). Moverlos a `resources/` en lugar de hardcodearlos en `BuildContext.groovy` permite:

- Cambiar defaults sin recompilar lógica.
- Mantener YAML (legible por humanos) separado del Groovy.
- Reutilizar los mismos defaults desde varios steps (`standardBuild`, `notifySlack`, etc.).

---

## Pinning

El consumidor usa:

```groovy
@Library('acme-ci@v1.0.0') _
```

### Por qué un tag semver (`@v1.0.0`) y no `@main`

- **Reproducibilidad**: el build #142 corrió con `v1.0.0`. Mañana `v1.0.0` sigue siendo el mismo commit. Con `@main` eso no es cierto: cualquier merge a `main` cambia el pipeline sin tocar el `Jenkinsfile`.
- **Auditabilidad**: el PR que bumpee `v1.0.0 → v1.1.0` es revisable. Un merge a `main` de la library no deja rastro en el repo consumidor.
- **Seguridad**: si la library está marcada como *trusted* por el admin de Jenkins, su código corre con privilegios de admin. `@main` + commit malicioso = compromiso del controller. `@tag` + branch protection sobre `v*` cierra el vector.
- **Rollout controlado**: bumpear tag es decisión explícita del equipo de la app, no efecto colateral de un merge ajeno.

Las variantes `@main` y `@branch-de-desarrollo` quedan permitidas **solo** durante desarrollo activo de la library, nunca en el `Jenkinsfile` final de la app.

---

## Governance

El refactor solo entrega valor si la library se gobierna con disciplina. Reglas mínimas:

- **`CODEOWNERS`** en el repo `acme-ci`: `*` → `@acme/platform`. Cualquier PR requiere aprobación de Platform.
- **PR obligatorio** sobre `main`. Branch protection activa; sin pushes directos.
- **Tag como mecanismo de release**: Platform taguea `vX.Y.Z` cuando un cambio está listo. Hasta que no haya tag, los consumidores no ven el cambio. El tag es el "release".
- **CHANGELOG.md** en la library con la lista de breaking changes por tag.
- **CI de la library**: lint Groovy + tests con `JenkinsPipelineUnit` para los steps más usados. Lo cubre un pipeline aparte (fuera del scope de esta actividad).
- **Branch protection sobre `v*`**: evita que alguien reescriba un tag ya consumido.
- **Review obligatoria de dos personas** para cambios en `vars/` (son la superficie pública).

### Testing futuro con `JenkinsPipelineUnit`

Este módulo no ejecuta tests, pero el diseño está preparado para introducirlos:

- `BuildContext` es una clase Groovy pura: se puede testear con JUnit sin cargar el DSL de Jenkins.
- `standardBuild.groovy` se testea con `JenkinsPipelineUnit` mockeando `sh`, `checkout`, `withCredentials`, etc., y afirmando sobre la secuencia de llamadas.

El plan es introducir tests para los dos escenarios más críticos antes del `v1.1.0`:

1. `standardBuild(image: 'x', deploy: [])` no invoca `kubectl apply`.
2. `standardBuild(image: 'x')` lanza con mensaje claro si falta un parámetro obligatorio.

---

## Qué NO cubre este refactor

- Testing automático de la library (planificado para `v1.1.0`).
- Rotación de credenciales (`ghcr`): se asume ya resuelto por `jk-07` (security).
- Observabilidad del pipeline (métricas de duración por stage): se añadirá en `v1.2.0`.
