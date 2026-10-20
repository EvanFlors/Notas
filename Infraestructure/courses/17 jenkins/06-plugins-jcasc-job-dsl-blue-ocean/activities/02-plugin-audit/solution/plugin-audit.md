# Audit de plugins — Jenkins legacy

## Resumen ejecutivo

- **Estado actual**: 25 plugins instalados, sin pinning, con 5 candidatos a retirar inmediatamente y 2 advisories abiertos (hipotéticos) en plugins no usados.
- **Target propuesto**: 14 plugins, 100% pinneados, con cadencia quincenal de revisión.
- **Reducción**: 44% (11 plugins fuera).
- **Riesgo**: bajo — todos los removidos son legacy / sin uso real o cubiertos por otros.

## Inventario

Listado actual (25 plugins) tomado del Update Center:

| Plugin | Rol actual |
|--------|-----------|
| configuration-as-code | JCasC — core. |
| job-dsl | Seed job — core. |
| workflow-aggregator | Pipeline — core. |
| pipeline-model-definition | DSL declarativo. |
| credentials, credentials-binding | Store de credenciales. |
| role-strategy, matrix-auth | RBAC (dos plugins compiten). |
| git, github, github-branch-source | SCM GitHub. |
| kubernetes | Agents efímeros. |
| blueocean, blueocean-pipeline-editor, blueocean-dashboard | UI alternativa. |
| slack | Notificaciones. |
| email-ext, mailer | Notificaciones por email. |
| timestamper | Timestamps en logs. |
| ws-cleanup | Limpieza de workspace. |
| ant, maven-plugin | Builds freestyle Java legacy. |
| subversion, cvs | SCMs obsoletos. |
| build-timeout | Timeouts por job. |

## Clasificación

| Plugin | Decisión | Rationale |
|--------|----------|-----------|
| configuration-as-code | **keep** | Core del módulo. |
| job-dsl | **keep** | Seed job. |
| workflow-aggregator | **keep** | Pipeline. |
| pipeline-model-definition | **keep** | Declarative. |
| credentials, credentials-binding | **keep** | Imprescindibles. |
| role-strategy | **keep** | Base para `jk-07`. |
| matrix-auth | **remove** | Duplica a `role-strategy`; mantener uno simplifica. |
| git, github, github-branch-source | **keep** | SCM activo. |
| kubernetes | **keep** | Agents efímeros. |
| blueocean + sub-plugins (×3) | **remove** | Estado *low-maintenance*; nadie en el equipo lo usa; UI clásica cubre casos. |
| slack | **keep** | Notificaciones principales. |
| email-ext, mailer | **remove** | Consolidamos notificaciones en Slack; emails críticos van vía ops-alerting externo. |
| timestamper | **keep** | Barato y mejora debugging. |
| ws-cleanup | **keep** | Evita contamination. |
| ant | **remove** | Builds via `sh 'mvn …'` dentro de pipeline; no se usan freestyle Ant. |
| maven-plugin | **remove** | Es el plugin de freestyle Maven (no `pipeline-maven`); no se usa. |
| subversion, cvs | **remove** | SCM obsoletos; ningún repo activo. |
| build-timeout | **remove** | Reemplazable por `options { timeout(...) }` en Jenkinsfile. |

**Total eliminados**: 11.

## Plan

**Fase 1 (semana 1)** — pinning de los que se quedan:
- Añadir `:version` a los 14 plugins keep en `plugins-target.txt`. Deploy.

**Fase 2 (semana 2)** — remover Blue Ocean y SCMs obsoletos:
- Verificar en todos los jobs que ninguno referencia `blueocean` o scripts específicos de Blue Ocean.
- `grep -ri "svn\|cvs" $JENKINS_HOME/jobs/` para confirmar que ningún job los usa.
- Despinstalar y re-deploy.

**Fase 3 (semana 3)** — consolidación de notificaciones:
- Migrar los 3 jobs que todavía usan `email-ext` a Slack o al bus de alertas externo.
- Remover `email-ext` y `mailer`.

**Fase 4 (semana 4)** — limpieza final:
- Remover `matrix-auth`, `ant`, `maven-plugin`, `build-timeout`.
- Añadir `options { timeout(...) }` donde falte.

Cada fase entra por PR al repo del controller, revisada por CODEOWNERS, con rollback trivial (reintroducir la línea en `plugins.txt` + redeploy).

## Blue Ocean

Blue Ocean **se retira** del controller. Rationale (2026):

- Estado del proyecto: *feature-complete / low-maintenance*. Solo parches de seguridad.
- La UI clásica sigue siendo la por defecto; no hay deprecación anunciada.
- El editor visual de Jenkinsfile está desaconsejado — flujo moderno es `Jenkinsfile` + PR.
- Nadie en el equipo lo usa activamente (confirmado por encuesta interna).
- Al retirar los 3 plugins (`blueocean`, `blueocean-pipeline-editor`, `blueocean-dashboard`) reducimos superficie de CVE.

Si en el futuro surge una necesidad concreta de visualización de pipelines paralelos, se evaluará *Pipeline Graph View* antes de reinstalar Blue Ocean.

## CVE

Fuentes de monitorización activa:

- **Jenkins Security Advisories (RSS)**: suscripción en Slack `#security-alerts`.
- **CloudBees security advisories**: boletín interno quincenal (incluye LTS line).
- **Dependabot** sobre el repo del controller: alerta en el `plugins.txt` cuando un bump cubre un advisory.

Política:

- **Advisory crítico**: PR out-of-band, merge y deploy el mismo día si es exploitable en nuestra configuración.
- **Advisory high**: PR en 48 h.
- **Advisory medium/low**: siguiente ventana quincenal.
- **Plugin con advisory en plugin NO instalado**: ignorar formalmente, pero reforzar que no se instale (añadir a lista de bloqueados).

La **cadencia** de revisión de advisories es quincenal (jueves alternos), coincidiendo con la cadencia de bumps no críticos. Fuera de esa ventana solo entran parches de seguridad.
