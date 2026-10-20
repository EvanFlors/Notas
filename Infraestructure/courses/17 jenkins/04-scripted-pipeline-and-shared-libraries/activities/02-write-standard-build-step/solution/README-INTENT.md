# Step `standardBuild` — contrato público

> Documento de intención: define la API pública del step, los defaults, los errores que lanza y la política de versionado. Es el contrato que ven los 15 equipos consumidores.

## Resumen

`standardBuild(args)` es el step opinado de la organización. Encapsula checkout → build → notify como una fachada única. Está pensado para que un `Jenkinsfile` consumidor quede en 5–10 líneas.

---

## API

| Parámetro | Tipo | Obligatorio | Default | Descripción |
|-----------|------|-------------|---------|-------------|
| `image` | `String` | **Sí** | — | Nombre lógico del artefacto. Se usa como parte del tag Docker: `${registry}/${image}:${BUILD_NUMBER}`. Debe ser `kebab-case` sin barras. |
| `registry` | `String` | No | `ghcr.io/acme` | Registry destino del push. Cambiar solo si la app vive fuera del tenant estándar. |
| `deploy` | `List<String>` | No | `['dev']` | Lista de entornos destino. Subconjunto permitido: `['dev', 'stg', 'prod']`. Pasar lista vacía desactiva el deploy. |
| `requireApproval` | `Boolean` | No | `false` | Si `true`, inserta un `input` humano con timeout antes de cualquier deploy a `prod`. |

**Convención Groovy**: los argumentos se pasan como un `Map` con nombre (`standardBuild(image: 'x', deploy: ['dev'])`). No existen argumentos posicionales en la API pública.

---

## Defaults

Cada default se justifica por el patrón de uso real de la organización:

- **`registry = 'ghcr.io/acme'`**: 95% de los repos publican ahí. Los pocos que no (p. ej. `analytics-images` que publica a ECR) sobreescriben explícitamente. El default evita boilerplate en 14 de 15 Jenkinsfiles.
- **`deploy = ['dev']`**: el *principio de menor sorpresa*. Un `Jenkinsfile` nuevo que solo declare `image` deploya a dev y nada más. Pasar a `stg`/`prod` requiere declararlo explícitamente — queda en el diff del `Jenkinsfile` y pasa por review.
- **`requireApproval = false`**: la mayoría de equipos tienen su propio gate externo (ArgoCD rollouts, PR en el repo de GitOps). Habilitar el gate humano dentro de Jenkins es *opt-in*, no *opt-out*, para no duplicar fricción.

### Defaults que **no** se exponen

Hay valores "duros" que el step no permite cambiar al consumidor:

- `timeout` del pipeline: 20 min. Si un build legítimo tarda más, el equipo abre PR a la library para subirlo globalmente, no lo monkey-patchea desde el `Jenkinsfile`.
- `disableConcurrentBuilds()`: siempre on. Dos builds concurrentes del mismo repo son casi siempre un bug.

---

## Errores

El step lanza errores **antes de levantar un agent** siempre que puede. Cuanto más temprano falle, menos recursos consume y más claro queda el error en la UI de Jenkins.

| Condición | Excepción | Mensaje |
|-----------|-----------|---------|
| `image` ausente o `null` | `IllegalArgumentException` | `"standardBuild: 'image' es obligatorio. Ejemplo: standardBuild(image: 'checkout-api')"` |
| `image` no es `String` | `AssertionError` | `"standardBuild: 'image' debe ser String"` |
| `deploy` presente pero no es `List` | `IllegalArgumentException` | `"standardBuild: 'deploy' debe ser una lista, no <tipo>"` |

**Fallos tardíos** (durante la ejecución del pipeline, no en validación):

- `docker build` falla → stage `Build` roja, `post { failure }` loguea el error.
- `libraryResource(...)` lanza `FileNotFoundException` si la plantilla fue borrada → bug de la library, requiere parche + bump.

---

## Versionado

### Política de bumps semver

| Cambio | Bump |
|--------|------|
| Añadir un parámetro opcional con default | `MINOR` (`v0.1.0` → `v0.2.0`) |
| Añadir un stage sin cambiar la API | `MINOR` |
| Cambiar el default de un parámetro existente | `MAJOR` (`v0.2.0` → `v1.0.0`) |
| Renombrar / eliminar un parámetro | `MAJOR` |
| Fix de bug sin cambio de API | `PATCH` (`v0.1.0` → `v0.1.1`) |
| Cambio solo en `resources/notify-template.md` | `PATCH` |

### Cómo deprecar un parámetro

El principio: **nunca romper 15 consumidores de golpe**. Si queremos renombrar `image` a `artifact`:

1. **`v0.X.0`**: aceptar ambos nombres (`args.artifact ?: args.image`), loguear `WARN` cuando el consumidor use el nombre antiguo.
2. Avisar a los equipos y actualizar la documentación.
3. **`v1.0.0`** (meses después): eliminar el nombre antiguo. Los que no hayan migrado quedan bloqueados en `v0.X.0`, lo cual es aceptable: les da tiempo.

### Mecánica del release

- Tag anotado `vX.Y.Z` en el repo `acme-ci` tras merge a `main`.
- `CHANGELOG.md` actualizado en el mismo PR del release.
- Branch protection sobre `v*` evita reescritura de tags ya consumidos.
- Los consumidores actualizan su `Jenkinsfile` cuando les conviene; el bump no es automático.

---

## Notas de implementación

- **`Serializable`** en `StandardBuild` es obligatorio por el motor CPS de Jenkins: el estado del pipeline se serializa a disco cuando un step cede la ejecución (`input`, `sleep`, suspensión del controller). Sin `Serializable`, el pipeline estalla con `NotSerializableException`. Fuente nº 1 de errores oscuros en libraries nuevas.
- **`libraryResource('org/acme/ci/notify-template.md')`** es la forma oficial de leer archivos de `resources/`. La ruta es relativa a `resources/`. Permite editar la plantilla sin recompilar lógica Groovy.
- `vars/standardBuild.groovy` **no debe** crecer en lógica: su rol es validar args, construir el dominio y orquestar. Toda nueva lógica va a `src/org/acme/ci/`.

---

## Qué NO cubre `v0.1.0`

- Lint y tests (vendrán en `v0.2.0`).
- Push a registry (vendrá en `v0.2.0` tras resolver credenciales por tenant).
- Deploy real a Kubernetes (vendrá en `v0.3.0` tras definir el modelo de ArgoCD).
- Rotación de secretos: fuera del scope de este step; lo cubre `jk-07`.
