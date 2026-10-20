# Recursos — jk-06

## JCasC

- **Jenkins Configuration as Code — plugin oficial**: <https://plugins.jenkins.io/configuration-as-code/>
- **Documentación del schema**: se genera dinámicamente en `Manage Jenkins → Configuration as Code → Documentation` dentro de cada controller (depende de los plugins instalados).
- **Repo con ejemplos**: <https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos>

## Job DSL

- **Plugin oficial**: <https://plugins.jenkins.io/job-dsl/>
- **API Viewer** (referencia de todos los métodos DSL): <https://jenkinsci.github.io/job-dsl-plugin/>
- **Patrón seed job**: <https://github.com/jenkinsci/job-dsl-plugin/wiki/Tutorial---Using-the-Jenkins-Job-DSL>

## Plugin management

- **`jenkins-plugin-cli`** (reemplazo moderno de `install-plugins.sh`): <https://github.com/jenkinsci/plugin-installation-manager-tool>
- **Plugin index**: <https://plugins.jenkins.io/>
- **Jenkins Security Advisories (RSS)**: <https://www.jenkins.io/security/advisories/rss.xml>

## Blue Ocean

- **Plugin**: <https://plugins.jenkins.io/blueocean/>
- **Discusión sobre estado del proyecto** (hilo de 2023+): <https://community.jenkins.io/t/future-of-blue-ocean/>

## Jenkins Operator (K8s)

- **jenkinsci/kubernetes-operator**: <https://github.com/jenkinsci/kubernetes-operator>
- Nota: evalúa su mantenimiento real antes de adoptarlo en producción.

## Backup

- **Velero** (backup de PVs en Kubernetes): <https://velero.io/>
- **ThinBackup plugin** (opción legacy, no recomendado para prod): <https://plugins.jenkins.io/thinBackup/>

## Imagen oficial

- **jenkins/jenkins** (DockerHub): <https://hub.docker.com/r/jenkins/jenkins>
- Convención: `jenkins/jenkins:lts-jdk17` para producción.

## Lecturas de contexto

- CloudBees — *Managing Jenkins at Scale*: whitepapers públicos.
- Jenkins Infra — cómo la fundación opera sus propios Jenkins con JCasC: <https://github.com/jenkins-infra/charts>
