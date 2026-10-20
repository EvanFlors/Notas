# REFERENCE — jk-02-02-explore-jenkins-home

> Solucion de referencia para autoevaluacion. No es la unica forma correcta.

## JENKINS_HOME layout

| Ruta | Contiene |
|------|----------|
| `config.xml` | Configuracion global del controller (modo de seguridad, URL, numero de executors, labels, properties). |
| `jobs/` | Un subdirectorio por job (`jobs/<name>/config.xml`, `builds/`, `nextBuildNumber`). Para folders, estructura anidada. |
| `workspace/` | Workspaces de los jobs cuando corren en el controller como executor local; checkout de SCM, archivos generados. Persiste entre builds salvo `cleanWs()`. |
| `plugins/` | Un `.jpi` o `.hpi` por plugin instalado + sus directorios de datos. |
| `users/` | Un subdirectorio por usuario local (si la auth es Jenkins DB); dentro, `config.xml` del usuario. |
| `secrets/` | `initialAdminPassword`, master key, hudson.util.Secret, certificados de agent. **Nunca** copiar en claro ni commitear. |
| `nodes/` | Config de nodes (agents) permanentes. |
| `credentials.xml` | Credential store cifrado (user/pwd, secret text, SSH keys) cifrado con las claves de `secrets/`. |
| `logs/` | Logs del controller y de ciertos subsistemas. |
| `updates/` | Metadata del update center de plugins. |
| `caches/` | Caches de SCM, de descargas, etc. — crecen y rara vez se limpian solos. |

## Freestyle

La configuracion de un Freestyle vive integra en `jobs/<name>/config.xml`. Ese XML describe el SCM, los triggers, los build steps (`<hudson.tasks.Shell>`, `<hudson.tasks.Maven>`, etc.) y los post-build actions.

Tres razones concretas por las que **no** es versionable de forma util:

1. **El archivo vive en el controller, no en un repo**. Cualquier cambio desde la UI reescribe el XML sin PR, sin review y con un audit trail minimo (solo "quien edito el job" en la UI).
2. **El XML depende de los plugins instalados y de sus versiones**. Elementos como `<com.cloudbees.jenkins.GitHubPushTrigger>` solo existen si el plugin equivalente esta instalado en la version compatible; copiar el XML a otro Jenkins no es portable sin replicar el estado de plugins.
3. **Diffs ruidosos y no significativos**. Jenkins reserializa el XML con sus defaults implicitos (orden de secciones, atributos opcionales), produciendo diffs que no reflejan el cambio semantico; eso rompe el valor de versionarlo.

## Pipeline inline vs from SCM

- **Pipeline inline (`Pipeline script`)**: el Groovy vive dentro del `config.xml` del job (`<definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition"><script>...</script>`). Formalmente es "Pipeline", pero sufre los mismos problemas que un Freestyle: no esta en Git, no es revisable como codigo de producto, no se puede testear fuera del controller.
- **Pipeline from SCM**: el `config.xml` del job es minimo y apunta a un repo (`<definition class="...CpsScmFlowDefinition">` + URL del repo + path del `Jenkinsfile` + branch). La **logica real** vive en el `Jenkinsfile` dentro del repo Git. Beneficios:
  - PRs con code review sobre el pipeline igual que sobre el codigo.
  - Blame y audit trail en Git.
  - Portabilidad: mover el pipeline a otro Jenkins es apuntarlo al mismo repo.
  - Posibilidad de factorizar logica compartida en Shared Libraries (`jk-04`).
  - Lint estatico con `declarative-linter` sin ejecutar.

## Growth without retention

Rutas que crecen sin limite si no se gestionan:

1. **`jobs/<j>/builds/`**: un subdirectorio por build con `log`, `build.xml`, `changelog.xml` y los artefactos archivados. Sin `buildDiscarder`/log rotator se acumulan indefinidamente. En jobs que corren por hora, es decenas de GB en meses.
2. **`workspace/<j>/`**: checkout del repo + binarios generados durante el build. Sin `cleanWs()` ni `deleteDir()`, residuos de builds anteriores se quedan. En pipelines con `node_modules/`, `target/`, imagenes construidas localmente, crece rapidamente.
3. **`logs/`** y **`caches/`**: logs del controller (incluidos de los subsystems) y caches de SCM/plugins. No se limpian solos; en instalaciones viejas acumulan GBs.
4. (bonus) **`updates/`**: metadata del plugin update center; menor, pero contribuye.

Impacto operativo: cuando el disco del controller se llena, Jenkins deja de aceptar builds, bloquea escrituras y en casos extremos corrompe archivos de estado. Es el "incidente de domingo por la noche" clasico en Jenkins mal operado.

## Risks

1. **Perdida del volumen = perdida total**. `JENKINS_HOME` es la unica fuente de estado. Sin backup externo (snapshots del volumen, `tar.gz` de `JENKINS_HOME`, Velero si corre en K8s), un error del operador borra el Jenkins entero.
2. **`secrets/` y `credentials.xml` cifrados con claves locales**. Las `credentials` del store se cifran con material que vive en `secrets/`; copiar `credentials.xml` a otro Jenkins sin la master key correspondiente deja las credenciales **inutiles o re-cifrables mal**. Nunca commitear estos archivos ni compartirlos en claro.
3. **Plugins acumulados = superficie de CVEs**. Cada plugin es Java/Groovy adicional. El wizard "Install suggested plugins" instala ~25 de entrada; la mayoria de CVEs historicos de Jenkins son de plugins. La primera medida de hardening (`jk-07`) es reducir plugins.
4. **Freestyle fantasma**. En instalaciones legacy, es tipico encontrar Freestyle creados por gente que ya no esta, sin descripcion, con triggers activos. El primer paso de un audit es inventariarlos.
5. **Sin retention por default**. Si el equipo no fija `buildDiscarder` por job o un default global, el disco se llena antes del primer trimestre.
