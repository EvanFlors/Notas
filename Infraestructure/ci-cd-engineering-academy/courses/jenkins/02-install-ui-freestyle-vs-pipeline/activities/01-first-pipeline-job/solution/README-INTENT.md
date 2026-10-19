# README-INTENT — jk-02-01-first-pipeline-job (solucion de referencia)

> Solucion de referencia. Compara con la tuya para autoevaluacion. No es la unica forma correcta.

## Pipeline anatomy

El `Jenkinsfile` se abre con `pipeline { ... }`, el wrapper obligatorio de Declarative. Dentro:

- `agent any` indica que cualquier executor libre del controller puede correr el job. En este modulo no distinguimos agents; `jk-05` introduce `agent { docker ... }` y `agent { kubernetes ... }` para builds reproducibles e isolados.
- `options { ... }` fija comportamiento global del pipeline:
  - `timestamps()` prefija cada linea del console output con hora — ayuda a correlacionar con logs externos.
  - `buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))` retiene como maximo 10 builds o 30 dias (lo que ocurra primero). Sin esto `JENKINS_HOME` crece sin limite.
  - `timeout(10, MINUTES)` corta el build si se cuelga mas de 10 minutos.
- `stages { ... }` lista las fases visibles en el pipeline graph:
  - `stage('Hello')` imprime un mensaje y ejecuta `uname -a` para dejar evidencia del agent.
  - `stage('Environment')` imprime variables de entorno expuestas automaticamente por Jenkins (`BUILD_NUMBER`, `JOB_NAME`, `WORKSPACE`) — util para debugging real.
- `post { ... }` corre al final, condicionado por el resultado:
  - `always` siempre;
  - `success` solo si todo salio OK;
  - `failure` solo si algo rompio — util para notificaciones (Slack, email, metrics).

## Freestyle vs Pipeline

Tres razones concretas por las que este pipeline gana a un Freestyle equivalente:

1. **Esta en un `Jenkinsfile` versionable en Git.** Si lo subo al repo del codigo, cada cambio del CI pasa por PR review igual que el codigo de producto. Un Freestyle vive en `JENKINS_HOME/jobs/<j>/config.xml` dentro del controller; nadie puede hacer code review sobre eso de forma util.
2. **Es diffeable y auditable.** Dos pipelines parecidos tienen diffs legibles en Git. Dos `config.xml` parecidos tienen diffs ruidosos por orden de secciones, defaults implicitos y configuraciones de plugins que cambian entre versiones.
3. **Es reproducible en otro Jenkins.** Mover este pipeline a otro controller es apuntar su "Pipeline script from SCM" al mismo repo. Mover un Freestyle requiere copiar el XML, instalar los mismos plugins en las mismas versiones y rezar.

Ventaja implicita adicional: con un `Jenkinsfile` puedo refactorizar logica repetida hacia una Shared Library (`jk-04`); con Freestyle solo puedo duplicar o encadenar jobs.

## Retention

`buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))` le dice a Jenkins que conserve como maximo los ultimos 10 builds del job y descarte builds con mas de 30 dias.

Sin retention explicita, el default por job suele ser "conservar todo". En un pipeline que corre varias veces por hora, en 6 meses el `JENKINS_HOME/jobs/<j>/builds/` acumula decenas de miles de directorios con logs y artefactos — hasta llenar el disco del controller. La primera limpieza en instalaciones legacy suele recuperar decenas de GB. Fijar retention desde el primer build es higiene minima.

## Run evidence

Al ejecutar **Build Now** sobre el Pipeline job `first-pipeline-job`, el console output termina con algo asi:

```
[Pipeline] echo
Finished with status: SUCCESS
[Pipeline] echo
Pipeline SUCCEEDED
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] End of Pipeline
Finished: SUCCESS
```

Si tu entorno no tiene Docker, documenta aqui que validaste el `Jenkinsfile` solo estructuralmente con `bash tests/validate.sh /tmp/jk-02-pipeline`.
