# jk-02 — Leccion: instalar Jenkins y hacer el primer job (Freestyle vs Pipeline)

> 10 secciones. Mayoritariamente practica local. Prerrequisitos: `jk-01`, curso **docker**.

---

## 1. Por que instalar con Docker (y no con un `.war` o un paquete)

Un Jenkins "a la antigua" se instalaba descargando `jenkins.war` y lanzandolo con `java -jar jenkins.war`, o instalando el paquete `.deb`/`.rpm` del repo oficial. Ambas formas siguen funcionando, pero tienen tres problemas practicos:

1. **Dependencias del host**: necesitas la JVM correcta (hoy Temurin 17/21), `fontconfig`, `git`, y una pila de utilidades. Cada maquina diverge.
2. **`JENKINS_HOME` suelto**: la configuracion, los jobs, los builds y las credenciales viven en un directorio del host (por default `/var/lib/jenkins`); migrar a otra maquina es "copiar carpetas y rezar".
3. **Upgrades**: cambiar de version implica reemplazar el `.war` o actualizar el paquete, y rezar otra vez.

La imagen oficial **`jenkins/jenkins:lts`** empaqueta la JVM correcta, el `.war` de la LTS actual, un usuario `jenkins` (UID 1000) y los scripts de arranque. El `JENKINS_HOME` se expone como volumen (`/var/jenkins_home`). Resultado: `docker run` con un volumen persistente te da un Jenkins igual en cualquier host, actualizable cambiando el tag de la imagen.

> **Idea clave:** `JENKINS_HOME` es el estado completo. Si lo pierdes, perdiste el Jenkins. Si lo tienes versionado o respaldado, tienes el Jenkins.

En este modulo instalamos **solo** con Docker. En `jk-05` veremos como correrlo dentro de Kubernetes; en `jk-06` como describirlo completo con JCasC para no depender del wizard.

---

## 2. Instalacion minima con Docker

El comando canonico para arrancar Jenkins local:

```bash
docker volume create jenkins_home

docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```

- Puerto **`8080`**: UI web y API REST.
- Puerto **`50000`**: inbound agent protocol (JNLP) para conectar agents permanentes; en local no se usa pero lo exponemos por completitud.
- Volumen **`jenkins_home`**: persiste `/var/jenkins_home`. Mientras exista el volumen, mantienes jobs, credenciales, plugins y usuarios al recrear el contenedor.

Primera arranque muestra en los logs una contrasena de administrador inicial. Para obtenerla:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Esta contrasena se usa **una sola vez** para entrar al setup wizard en `http://localhost:8080`.

> **Nota operativa:** la contrasena vive en `secrets/initialAdminPassword` dentro de `JENKINS_HOME`. Si pierdes el volumen antes de completar el wizard, pierdes el acceso y toca recrear el contenedor para generar una nueva.

---

## 3. Setup wizard: admin user + plugins "recomendados"

El wizard tiene tres pasos:

1. **Unlock Jenkins**: pegar el `initialAdminPassword`.
2. **Customize Jenkins**: elegir entre *Install suggested plugins* y *Select plugins to install*.
3. **Create First Admin User**: usuario, password, email.

La **suite recomendada** instala ~25 plugins (Pipeline, Git, Credentials Binding, Timestamper, Workspace Cleanup, Email Extension, etc.). Es util para arrancar, pero ya empieza a ser demasiado: cada plugin es codigo adicional, superficie de CVEs y una potencial fuente de rotura al actualizar.

> **Idea clave:** la primera medida de hardening de Jenkins (ver `jk-07`) es **reducir** los plugins instalados a los que realmente usas. Instalar "suggested" en el wizard es una concesion didactica para empezar, no una buena practica a largo plazo.

Al final del wizard, Jenkins te deja en la **Dashboard**. Es el punto de partida para el resto.

---

## 4. UI tour: lo minimo que hay que saber

La UI de Jenkins ha envejecido pero es consistente. Los puntos clave:

- **Dashboard** (`/`): lista de jobs y folders; estado del ultimo build por job (azul/rojo/gris).
- **New Item** (`/newJob`): crear jobs (Freestyle, Pipeline, Multibranch Pipeline, Folder, etc.).
- **Manage Jenkins** (`/manage`): la "panel de control" global:
  - **System**: configuracion global (URL de Jenkins, SMTP, variables de entorno).
  - **Plugins**: instalar, actualizar, desinstalar.
  - **Nodes and Clouds**: agents permanentes y clouds (Docker, Kubernetes).
  - **Credentials**: secret text, user/pass, SSH keys, certificates.
  - **Security**: autenticacion y autorizacion.
  - **Tools**: binarios (JDK, Maven, Gradle, NodeJS) gestionados por Jenkins.
- **People**: usuarios del sistema de autenticacion local.
- **Build Queue** (barra lateral izquierda): builds esperando un executor.
- **Build Executor Status**: slots de ejecucion disponibles por nodo.

> **Idea clave:** todo lo que configures aqui vive en `JENKINS_HOME` como XML. Lo que no esta en Git, no existe desde el punto de vista de GitOps.

---

## 5. Freestyle jobs: el modelo clasico (y por que es un anti-patron hoy)

Un **Freestyle job** se crea desde `New Item` eligiendo "Freestyle project". La configuracion es puramente por UI: checkboxes y campos de texto agrupados en secciones:

- **Source Code Management**: Git, Subversion, None.
- **Build Triggers**: SCM polling, cron, trigger remoto, upstream build.
- **Build Environment**: timestamps, workspace cleanup, credenciales inyectadas.
- **Build Steps**: ejecutar shell, Windows batch, Ant, Maven, Gradle, invocar otro job.
- **Post-build Actions**: archivar artefactos, publicar resultados de tests, enviar emails, trigger downstream.

Toda esa configuracion se serializa a `JENKINS_HOME/jobs/<job-name>/config.xml`. Un snippet real:

```xml
<project>
  <description>Hello world freestyle</description>
  <builders>
    <hudson.tasks.Shell>
      <command>echo "hello"
uname -a</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
```

**Problemas practicos de Freestyle en 2026:**

1. **No esta en Git**. El `config.xml` vive en el controller. Cualquier cambio es un click en la UI sin review ni audit trail util.
2. **No es diffeable**. Dos jobs "parecidos" tienen XML distinto por orden de secciones y defaults implicitos.
3. **No es portable**. Mover un Freestyle a otro Jenkins implica copiar `config.xml` (y tener los mismos plugins instalados en la misma version).
4. **No tiene estructura reutilizable**. Para compartir logica entre jobs, Freestyle solo ofrece "invocar otro job" o duplicar steps.
5. **No tiene test**. No puedes "linterar" un Freestyle; solo lo ejecutas y ves si rompe.

Por eso: **todo job nuevo debe ser Pipeline**. Los Freestyle sobreviven como pasivo legacy a migrar; no se crean en 2026 excepto como ejercicio didactico (lo que hacemos aqui).

---

## 6. Pipeline jobs: el modelo moderno

Un **Pipeline job** se crea tambien desde `New Item` eligiendo "Pipeline". La diferencia clave: la **logica del job vive en un `Jenkinsfile` escrito en Groovy DSL**, no en formularios.

Hay dos variantes:

- **Pipeline script**: pegas el Groovy inline en la UI (util para prototipar; **no versionado**).
- **Pipeline script from SCM**: Jenkins clona un repo Git y lee el `Jenkinsfile` desde ahi (**unica opcion recomendada para prod**).

Un `Jenkinsfile` declarative minimo:

```groovy
pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'hello'
                sh 'uname -a'
            }
        }
    }

    post {
        always {
            echo "Finished with status: ${currentBuild.currentResult}"
        }
    }
}
```

Bloques minimos:

- **`pipeline { ... }`**: wrapper obligatorio en Declarative.
- **`agent`**: donde se ejecuta (`any` = cualquier executor libre; luego veremos `docker`, `kubernetes`, `none`).
- **`stages { stage { steps { ... } } }`**: unidades visibles en la UI de Jenkins (cada `stage` es un rectangulo en Blue Ocean / Pipeline Graph).
- **`post { ... }`**: acciones condicionadas por el resultado (`always`, `success`, `failure`, `unstable`, `changed`, `fixed`).

**Ventajas inmediatas sobre Freestyle:**

1. **Esta en Git**. Review en PR, blame por autor, audit trail por commit.
2. **Es diffeable**. Dos pipelines parecidos tienen diffs legibles.
3. **Es portable**. Mover el pipeline a otro Jenkins es mover el repo.
4. **Tiene estructura reutilizable**: Shared Libraries (`jk-04`).
5. **Tiene lint**: `declarative-linter` valida sintaxis sin ejecutar.

---

## 7. `config.xml` vs `Jenkinsfile`: el fondo del asunto

El cambio de Freestyle a Pipeline **no** es cosmetico. Es un cambio de **fuente de verdad**:

| Aspecto | Freestyle | Pipeline (SCM) |
|---------|-----------|----------------|
| Fuente de verdad | `JENKINS_HOME/jobs/<j>/config.xml` | `Jenkinsfile` en Git |
| Audit trail | logs de UI, poco util | historial de Git |
| Review | ninguno | PR review |
| Reproducibilidad entre Jenkins | copiar XML + plugins | checkout del repo |
| Rollback | restaurar backup del XML | `git revert` |
| Testing | ejecutar y ver | lint + unit tests de Shared Libraries |

Esto es la raiz del concepto **pipeline-as-code**: la logica del CI/CD se trata como el resto del codigo del producto. Sin ello, Jenkins es una caja negra operada por clicks.

> **Idea clave:** la pregunta correcta ante un Freestyle no es "funciona?" sino "quien sabe que hace?". Si la respuesta es "una persona que ya no esta", es un bug latente.

---

## 8. Workspace, build artifact, retention

Tres conceptos operativos basicos que vale conocer desde el primer job:

- **Workspace**: directorio por job en el agent donde se checkout el repo y corren los steps. En Jenkins local sobre Docker esta en `/var/jenkins_home/workspace/<job-name>`. Entre builds el workspace **persiste por default** (puede ensuciarse); se puede limpiar con `cleanWs()` o configurando el job.
- **Build artifact**: ficheros declarados con `archiveArtifacts` (Pipeline) o "Archive the artifacts" (Freestyle). Jenkins los copia al controller y los asocia al numero de build. Se descargan desde la UI.
- **Retention**: cuantos builds (y cuantos dias) conservar. Se configura con `options { buildDiscarder(logRotator(numToKeepStr: '20', daysToKeepStr: '30')) }` en Pipeline, o en la seccion equivalente de Freestyle. Sin retention, `JENKINS_HOME` crece sin limite hasta llenar disco.

> **Idea clave:** `JENKINS_HOME` crecera indefinidamente si no configuras retention. En instalaciones legacy, la primera limpieza suele recuperar decenas de GB.

---

## 9. Folders y views: organizacion basica

Cuando el numero de jobs crece (en orgs reales son cientos o miles), hay dos herramientas de organizacion basicas:

- **Folders**: contenedores jerarquicos de jobs (equivalente visual a directorios). Permiten aplicar credenciales y permisos **por folder** en vez de job por job. Se instalan con el plugin **Folders** (parte de la suite recomendada).
- **Views**: filtros guardados en la Dashboard (p. ej. "mis jobs", "jobs de produccion", "jobs rotos"). Son solo presentacion, no cambian la estructura.

En este modulo no profundizamos. Importante saber que existen; en `jk-06` las veremos de nuevo al hablar de Job DSL y JCasC.

---

## 10. Resumen y conexion con el resto del curso

Lo que te llevas de este modulo:

1. **Jenkins se instala local con `docker run` y la imagen oficial `jenkins/jenkins:lts`**. El `JENKINS_HOME` es un volumen y es tu unica fuente de estado.
2. **La UI tiene cinco zonas clave**: Dashboard, New Item, Manage Jenkins, People, Build Queue.
3. **Freestyle es anti-patron en 2026**: toda su logica vive en un `config.xml` no versionado. Sobrevive como pasivo legacy.
4. **Pipeline (Jenkinsfile desde SCM) es el unico modo recomendado**: logica versionada, revisable, reproducible.
5. **Workspace, artifact y retention** son conceptos operativos que te siguen todo el curso.

Conexiones:

- `jk-03`: la sintaxis declarative completa (environment, parameters, when, parallel, withCredentials, lint).
- `jk-04`: Scripted Pipeline + Shared Libraries, donde vive el poder de las instalaciones legacy.
- `jk-05`: agents efimeros + Kubernetes plugin.
- `jk-06`: JCasC + Job DSL, para que el controller completo (y los jobs) esten en Git.
- `jk-07`: hardening (RBAC, credentials, script approvals) sobre esta base.
