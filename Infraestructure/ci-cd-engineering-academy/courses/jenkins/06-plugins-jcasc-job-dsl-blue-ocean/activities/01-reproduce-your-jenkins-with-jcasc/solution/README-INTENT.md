# README-INTENT — Jenkins Plataforma reproducible con JCasC

Este documento acompaña a `jenkins.yaml`, `plugins.txt` y `seed-jobs.groovy`. Explica las decisiones tomadas al bootstrapear el controller con **Jenkins Configuration as Code** (JCasC) y Job DSL, y por qué Blue Ocean no está instalado.

## jenkins.yaml

El fichero describe la configuración completa del controller. Decisiones clave:

- **`jenkins.numExecutors: 0` + `mode: EXCLUSIVE`**: el controller no ejecuta builds. Todo va a agents efímeros del cloud Kubernetes (`k8s`). Esto reduce blast-radius y evita *controller contamination*.
- **`securityRealm.local`**: autenticación local para esta fase. En `jk-07` migraremos a OIDC/SAML; se cambia aquí sin tocar el resto.
- **`authorizationStrategy.roleBased`**: dos roles (`admin`, `readonly`). La granularidad por folder se añadirá en `jk-07`.
- **`credentials.system.domainCredentials`**: dos credenciales (`github-bot` y `slack-webhook`). Ambos usan placeholders `${…}` — ningún secret en claro.
- **`unclassified.gitHubPluginConfig` + `unclassified.slackNotifier`**: configuran plugins GitHub y Slack sin recurrir a UI.
- **`tool.git` + `tool.jdk`**: declaran herramientas disponibles. JDK con auto-install para pipelines Java.
- **`jobs[0].script`**: único job definido inline — el **seed job**. Lee `seed-jobs.groovy` del workspace y genera el resto. Patrón canónico recomendado.

## plugins.txt

Toda línea no-comentario tiene `nombre:version` explícito (pinning estricto). Decisiones:

- **Core obligatorio**: `configuration-as-code`, `job-dsl`, `workflow-aggregator`, `pipeline-model-definition`. Sin estos no hay módulo.
- **Credentials + RBAC**: `credentials`, `credentials-binding`, `role-strategy`.
- **SCM GitHub**: `git`, `github`, `github-branch-source` (necesario para Multibranch desde GitHub Organizations).
- **Agents K8s**: `kubernetes`.
- **Notificaciones / UX**: `slack`, `timestamper`, `ws-cleanup`.

**Pinning rationale**: dos reproducciones del mismo `plugins.txt` sin pinning pueden traer versiones distintas y comportarse distinto. Cada bump entra por PR al mismo repo que `jenkins.yaml`. Advisories de seguridad se tratan out-of-band (prioridad alta), features en cadencia quincenal.

**Reducción deliberada**: no se instalan plugins "recomendados" del setup wizard. La primera medida de seguridad en Jenkins es reducir superficie de CVE y la mayor parte de CVEs son de plugins.

## seed-jobs.groovy

El seed job genera:

- Tres **folders**: `legacy/`, `product/`, `ops/`. Separan responsabilidades y permiten aplicar RBAC por folder en `jk-07`.
- `legacy/batch-nightly` — `pipelineJob` nocturno, migrado desde freestyle. Vive aquí hasta que el equipo dueño adopte Jenkinsfile en su repo.
- `ops/rotate-credentials` — job operativo propio de la plataforma (no corresponde a un repo de producto).
- `product/checkout` — `multibranchPipelineJob`. Autoconfigura ramas con `Jenkinsfile`. Es el patrón moderno — Job DSL aquí solo sirve para versionar la *existencia* del job, no su lógica.

**Job DSL vs otras opciones**:

- Repos modernos con `Jenkinsfile` → `multibranchPipelineJob` (Job DSL define el job; la lógica vive en el repo).
- Jobs legacy sin `Jenkinsfile` propio → `pipelineJob` con `cpsScm` apuntando a un `Jenkinsfile` del repo del controller o del repo legacy.
- Jobs operativos sin repo claro → `pipelineJob` apuntando a un repo de `ops-tools` común.

**Lo que NO va en Job DSL**: código reutilizable compartido. Para eso, Shared Libraries (ver `jk-04`).

## Blue Ocean

Blue Ocean **no está** en `plugins.txt`. Decisión fundada en el estado real del proyecto en 2026:

1. La UI clásica sigue siendo la por defecto y no hay fecha anunciada de deprecación.
2. Blue Ocean está en estado *feature-complete / low-maintenance*: solo recibe parches de seguridad.
3. El editor visual de Jenkinsfile de Blue Ocean está desaconsejado: el flujo moderno es `Jenkinsfile` versionado en Git + PR review.
4. Para visualización de pipelines paralelos, el *Pipeline Graph View plugin* (nativo moderno) suele cubrir el caso sin añadir Blue Ocean.
5. En este Jenkins nuevo nadie ha pedido Blue Ocean; añadirlo "por si acaso" suma mantenimiento y superficie de CVE sin aportar valor concreto.

Si en el futuro el equipo pide Blue Ocean para una visualización específica, se descomenta la línea en `plugins.txt` y entra por PR como cualquier otro plugin, con pinning explícito.

## Recarga y cambio

Flujo correcto para cualquier cambio:

1. PR al repo que contiene `jenkins.yaml` + `plugins.txt` + `seed-jobs.groovy`.
2. Review por un admin de plataforma (CODEOWNERS).
3. Merge → pipeline del propio controller valida YAML con `python3` y verifica pinning.
4. Deploy aplica el nuevo `plugins.txt` (reinicio del controller si hay cambio de plugins) y recarga la config JCasC.

Nunca se modifica por UI. Si alguien lo hace, el próximo reload de JCasC lo revierte — por diseño.
