# Lección — Plugins, JCasC, Job DSL y Blue Ocean

> **Resumen operativo**
> Un Jenkins sin configuración declarativa es un *snowflake*: nadie lo puede reproducir con fidelidad. JCasC convierte al controller en una app Git-driven como cualquier otra. Job DSL + seed job permiten mantener jobs legacy versionados mientras migras a Multibranch Pipeline. Blue Ocean existe pero está en *low-maintenance*: la UI por defecto sigue siendo la clásica. El baseline de disciplina es: pinnear plugins, reducir el número instalado, y versionar `jenkins.yaml` + `plugins.txt` + los `.groovy` del seed en el mismo repo que opera el controller.

---

## 1. Por qué este módulo existe

En una instalación Jenkins madura el 90% de los problemas de "no sé qué hace esta instancia" tienen una causa única: la configuración vive en `$JENKINS_HOME/config.xml` + `$JENKINS_HOME/jobs/*/config.xml` + decisiones hechas con clics en *Manage Jenkins*. Nada está en Git. Cuando toca restaurar la instancia tras un incidente, lo que se restaura es un backup del disco — con el estado de un día concreto, no la *intención*.

JCasC rompe este modelo. En vez de "la configuración es lo que está en el disco del controller", pasa a ser "la configuración es un YAML en Git; el controller la aplica al arrancar". El efecto operativo:

- Reproducir el controller en otro cluster es `git clone` + `docker run`.
- Un cambio de configuración entra por PR, se revisa, se aprueba, se auditea.
- El `$JENKINS_HOME` sigue siendo útil para *history*, artefactos y workspaces — no para configuración.

Este módulo construye esa disciplina en tres frentes complementarios: **plugins** (qué hay instalado y en qué versión), **JCasC** (cómo está configurado el controller) y **Job DSL** (cómo se generan jobs legacy desde código).

---

## 2. El plugin ecosystem

Jenkins es su plugin ecosystem. El core es casi irrelevante: lo que usas día a día (Pipeline, Credentials, Kubernetes, GitHub, Docker, Slack, Ansible, Blue Ocean, Role Strategy, Configuration as Code…) son plugins. Hay del orden de **1800** disponibles, con calidad desigual, cadencia de release desigual, y advisories de seguridad semanales.

### 2.1 Dos formas de instalar

1. **UI**: *Manage Jenkins → Plugins → Available → Install*. Prohibido en 2026 en una instalación seria: no deja rastro versionado, no se puede reproducir.
2. **CLI / preinstall**: `jenkins-plugin-cli` o el histórico `install-plugins.sh`, leyendo un `plugins.txt` como:

   ```
   configuration-as-code:1850.va_a_8c31d_83b_29
   job-dsl:1.90
   kubernetes:4287.v73451380b_576
   workflow-aggregator:600.vb_57cdd26fdd7
   credentials:1407.v_ef1580c9fb_8e
   role-strategy:755.v1a_c56eb_f27c0
   ```

   En la imagen oficial: `jenkins-plugin-cli --plugin-file plugins.txt`.

### 2.2 Pinning y update strategy

**No pinnear versiones es acumular deuda operativa invisible.** Dos reproducciones del mismo `plugins.txt` sin pinning pueden instalar versiones distintas y comportarse distinto. La disciplina mínima:

- Cada línea de `plugins.txt` lleva versión explícita (`plugin:version`).
- Las actualizaciones entran por PR al mismo repo que `jenkins.yaml`.
- Hay una cadencia definida (p. ej. quincenal) donde se revisan advisories vigentes y se decide qué actualizar.
- Se separa "update por CVE" (prioridad alta, out-of-band) de "update por feature" (prioridad baja, en la cadencia).

El antipatrón más común: todo lo instalado "recomendado" por el setup wizard, nunca revisado. Resultado: 80+ plugins, muchos sin usar, varios con advisories abiertos.

### 2.3 Reducir plugins es seguridad

La mayoría de CVEs de Jenkins no son del core: son de plugins. Primera medida de hardening — antes de RBAC, antes de Vault — es **auditar qué plugins hay instalados y desinstalar los que nadie usa**. Esto es la actividad `02` de este módulo.

---

## 3. Jenkins Configuration as Code (JCasC)

JCasC es el plugin `configuration-as-code`. Expone un YAML (`jenkins.yaml`) que describe la configuración del controller y se aplica al arranque. Si cambias el YAML y recargas (vía UI, API o reinicio), el controller converge a lo que diga el YAML.

### 3.1 Secciones típicas de un `jenkins.yaml`

```yaml
jenkins:
  systemMessage: "Jenkins — gestionado por JCasC. No modificar por UI."
  numExecutors: 0            # el controller no ejecuta builds
  mode: EXCLUSIVE
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${ADMIN_PASSWORD}"   # inyectado por env/secret
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            permissions:
              - "Overall/Administer"
            assignments:
              - "admin"
  clouds:
    - kubernetes:
        name: "k8s"
        serverUrl: "https://kubernetes.default"
        namespace: "jenkins-agents"
        jenkinsUrl: "http://jenkins.jenkins.svc:8080"
        templates:
          - name: "default"
            label: "k8s"
            containers:
              - name: "jnlp"
                image: "jenkins/inbound-agent:latest"
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: "github-bot"
              username: "ci-bot"
              password: "${GITHUB_TOKEN}"
unclassified:
  location:
    url: "https://jenkins.example.com/"
  gitHubPluginConfig:
    configs:
      - name: "github.com"
        apiUrl: "https://api.github.com"
tool:
  git:
    installations:
      - name: "Default"
        home: "git"
jobs:
  - script: >
      pipelineJob('seed') {
        definition {
          cps {
            script(readFileFromWorkspace('seed-jobs.groovy'))
            sandbox()
          }
        }
      }
```

**Puntos clave de lectura**:

- `jenkins.securityRealm` define *autenticación*. `authorizationStrategy` define *autorización*. Son cosas distintas: una dice "¿quién eres?", la otra "¿qué puedes hacer?".
- `credentials.system.domainCredentials` es el `credentials store` global.
- `${ADMIN_PASSWORD}` y `${GITHUB_TOKEN}` son placeholders que JCasC resuelve desde variables de entorno o `secrets/` — nunca se escriben en claro en el YAML.
- `unclassified` es el "cajón" para config de plugins que no cae en los bloques estándar: GitHub, Slack, Mattermost, etc.
- `tool` configura herramientas descargables (JDK, Maven, Git) con auto-install.
- `jobs` acepta scripts Job DSL inline o referenciando archivos. El patrón limpio es tener un único *seed job* definido aquí que a su vez lea `seed-jobs.groovy` con el resto.

### 3.2 El schema evoluciona

Los schemas JCasC cambian entre versiones de plugins (p. ej. un plugin renombra una propiedad, otro deja de exponerla). Dos consecuencias prácticas:

- Las actualizaciones de plugin pueden romper tu `jenkins.yaml`. Hay que validarlas antes de desplegar.
- La documentación "autoritaria" vive en el propio controller: `Manage Jenkins → Configuration as Code → Documentation` genera la referencia de schema a partir de los plugins instalados en ese momento.

### 3.3 Secrets

Patrón recomendado:

- Secrets como env vars inyectadas al controller (desde Kubernetes Secret, SSM, Vault…).
- `${VAR_NAME}` en el YAML.
- Nunca secrets en claro en el repo.
- JCasC también soporta `${file:/path}` para leer de disco (útil con `tmpfs` montado por Vault Agent Injector).

---

## 4. Job DSL plugin

JCasC describe el *controller*. Para describir **jobs** desde código hay dos caminos:

1. **Multibranch Pipeline / Pipeline from SCM**: cada repo trae su `Jenkinsfile`. Es lo moderno y lo recomendado para repos nuevos.
2. **Job DSL**: un `.groovy` genera N jobs declarativamente. Es lo útil para:
   - Repos legacy sin `Jenkinsfile` que no vas a tocar.
   - Jobs que no corresponden a un repo (ej. jobs operativos: *trigger de release*, *seed job* propio).
   - Generación masiva (un job por entorno, un job por microservicio).

### 4.1 Patrón seed job

El patrón canónico es:

1. En `jenkins.yaml` defines un único job "seed" (via `jobs.script`) que es un `pipelineJob` que ejecuta Job DSL.
2. El Job DSL (`seed-jobs.groovy`) genera el resto de jobs del controller.
3. Cada vez que haces push al repo que contiene `seed-jobs.groovy`, el seed se re-ejecuta y los jobs convergen a lo descrito.

Ejemplo mínimo de `seed-jobs.groovy`:

```groovy
folder('legacy') {
  description('Jobs heredados del Jenkins snowflake original.')
}

pipelineJob('legacy/batch-nightly') {
  description('Batch nocturno de reconciliación — migrado desde freestyle.')
  triggers {
    cron('H 2 * * *')
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url('https://github.com/example/batch-nightly.git') }
          branch('main')
        }
      }
      scriptPath('Jenkinsfile')
    }
  }
}

multibranchPipelineJob('product/checkout') {
  branchSources {
    github {
      id('checkout')
      repoOwner('example')
      repository('checkout')
      credentialsId('github-bot')
    }
  }
}
```

### 4.2 Cuándo NO usar Job DSL

- Si tu repo moderno ya tiene `Jenkinsfile` y `webhook` de GitHub, un *Multibranch Pipeline* se autoconfigura. No necesitas Job DSL para eso.
- Si tu organización está migrando fuera de Jenkins, no inviertas en construir una capa Job DSL grande: será código a tirar en 6 meses.
- Si el seed job genera cientos de jobs y nadie entiende por qué uno de ellos tiene un parámetro raro, estás haciendo Job DSL *procedural* en vez de declarativo. Simplifica.

---

## 5. Blue Ocean — qué pasa con ello en 2026

Blue Ocean fue lanzado en 2017 como la UI "moderna" de Jenkins: dashboard por pipeline, visualización de stages y parallels, editor visual de Jenkinsfiles. Prometió reemplazar a la UI clásica.

Realidad hoy (2026):

- La UI clásica **sigue siendo la por defecto**. No hay fecha anunciada de deprecación.
- Blue Ocean está en estado *feature-complete / low-maintenance*: recibe parches de seguridad y compatibilidad, pero no features nuevas significativas.
- El editor visual de Jenkinsfile está desaconsejado: el flujo real moderno es `Jenkinsfile` versionado + review en PR, no edición visual.
- Para visualización de pipelines, muchas instalaciones usan directamente el *Pipeline Graph View plugin* (más moderno que Blue Ocean) o nada: miran el Jenkinsfile y los logs.
- Pierde momentum frente a la realidad de que la mejor "UI moderna" para CI es *no mirar la UI* — mirar el commit status en GitHub, un dashboard de métricas, Slack con los fallos.

**Cuándo instalar Blue Ocean en 2026**:

- Instalación legacy donde los usuarios la pidieron hace años y la usan a diario — vale la pena mantenerla.
- Equipo que ejecuta muchos pipelines con *parallel stages* y quiere la visualización clásica de Blue Ocean.
- Casi nunca para una instalación nueva.

**Cuándo NO instalarlo**: instalación nueva, equipo pequeño, equipo que ya mira commit status en GitHub/GitLab, equipo que planea migrar fuera de Jenkins.

En este módulo lo tratamos como **walkthrough**: lo mencionamos en el `plugins.txt` opcionalmente, documentamos su estado real, y no construimos nada específico encima.

---

## 6. Jenkins Operator for Kubernetes (mención)

Para instalaciones Jenkins corriendo en Kubernetes existe el *Jenkins Operator* (CRD-based): declaras un `Jenkins` CR con la configuración, y el operator lo materializa. Suma JCasC + plugins + backup como una sola unidad declarativa.

Trade-off: añade una pieza más (el operator) que hay que mantener; para instalaciones medianas, un `Deployment` + `PersistentVolume` + JCasC vía ConfigMap suele ser suficiente y más transparente.

No profundizamos aquí. Para instalaciones *greenfield* en Kubernetes, antes de adoptar el operator, evalúa seriamente si Jenkins es la herramienta correcta vs **Argo Workflows** o **Tekton** (temario de `jk-01` y `jk-08`).

---

## 7. Backup del `JENKINS_HOME`

JCasC **no reemplaza el backup**. Lo que vive solo en el disco del controller y no está en Git:

- Build history (`$JENKINS_HOME/jobs/<name>/builds/*`).
- Artefactos archivados (`archiveArtifacts`).
- Workspaces (si no están en PVC separado).
- Fingerprints.
- Logs del propio controller.

Estrategias:

- Si el controller corre en Kubernetes, el `PersistentVolumeClaim` del `$JENKINS_HOME` se respalda con **Velero** u otro backup de PVs.
- Si corre en VM, snapshot del disco a cadencia definida (RPO según criticidad).
- Para artefactos de larga retención, mejor publicarlos a un **artifact repo** (Nexus, Artifactory, S3) desde el pipeline y no retenerlos en el controller.

Lo importante conceptualmente: `jenkins.yaml` reproduce el *controller configurado y vacío*. El backup reproduce el *controller con historia*. Son dos cosas distintas y las dos hacen falta.

---

## 8. Qué va dónde

Resumen de la separación de responsabilidades:

| Qué | Dónde vive | Herramienta |
|-----|------------|-------------|
| Config del controller (security, credentials, nodes, clouds, tools) | Git | JCasC (`jenkins.yaml`) |
| Lista de plugins y versiones | Git | `plugins.txt` + `jenkins-plugin-cli` |
| Jobs modernos (un repo = un pipeline) | Repo del producto | `Jenkinsfile` + Multibranch Pipeline |
| Jobs legacy / jobs operativos sin repo | Git (repo del controller) | Job DSL (seed job) |
| Código reutilizable compartido entre pipelines | Git (repo de la library) | Shared Library (`jk-04`) |
| Builds, logs, artefactos | `$JENKINS_HOME` + artifact repo | Backup del PV + repo externo |
| Secrets | Vault / Kubernetes Secret / SSM | Referenciados como `${VAR}` desde JCasC |

Si algo no cae en una celda clara, es síntoma de que la instalación está empezando a desalinearse. Reclasifícalo antes de que se vuelva snowflake de nuevo.

---

## 9. Antipatrones típicos

- **"Lo cambio por la UI y luego exporto"**: JCasC permite exportar la config actual, sí, pero esto normaliza el flujo malo. El flujo correcto es: cambio en Git → PR → merge → recarga JCasC.
- **Plugin sin pinning**: `plugins.txt` con líneas como `kubernetes:latest`. Rompe reproducibilidad y silencia advisories.
- **80 plugins instalados "porque sí"**: multiplica superficie de CVE. Reduce.
- **Seed job que genera 400 jobs y nadie sabe qué hace cada uno**: Job DSL se usa como código espagueti. Divide en varios `.groovy` por dominio y añade comentarios.
- **Blue Ocean instalado en instancia nueva "porque se ve bonito"**: ocupa recursos de mantenimiento sin aportar valor real.
- **`${PASSWORD}` sin inyección**: JCasC no lanza error si la variable no existe — simplemente mete el string literal. Validar en CI que todas las referencias `${...}` tienen una env var definida en el entorno de prueba.

---

## 10. Criterios de calidad del repo del controller

Si estás revisando el repo que opera un Jenkins con JCasC, estos deberían ser los mínimos:

1. `jenkins.yaml` presente y validado (al menos parsea como YAML y no tiene secrets en claro).
2. `plugins.txt` con todas las líneas pinneadas (`:version` explícito).
3. Un *seed job* definido en `jenkins.yaml` que carga `seed-jobs.groovy`.
4. Un `README.md` que explica cómo levantar el controller desde cero.
5. CI del repo que, al menos, valide que `jenkins.yaml` parsea y `plugins.txt` no tiene duplicados ni líneas sin versión.
6. CODEOWNERS que exige review de un admin de plataforma para cambios en `jenkins.yaml` o `plugins.txt`.
7. Changelog / notas sobre los últimos upgrades de plugins (fecha + motivo).

Lo que **no** debería estar: `config.xml` crudos commiteados "por si acaso", pass en claro, plugins instalados a mano fuera del `plugins.txt`.

---

## 11. Qué llevas de este módulo a `jk-07`

El siguiente módulo (`jk-07 security`) asume que ya tienes:

- Un `jenkins.yaml` donde definir el `authorizationStrategy` con Role-based Strategy.
- Un `plugins.txt` pinneado al que añadir `role-strategy`, `credentials-binding`, `hashicorp-vault-plugin`.
- Capacidad de reconstruir el controller desde cero para probar un hardening sin miedo.

Sin esta base, el hardening se hace a clics y es irreproducible — exactamente lo que estamos tratando de evitar.
