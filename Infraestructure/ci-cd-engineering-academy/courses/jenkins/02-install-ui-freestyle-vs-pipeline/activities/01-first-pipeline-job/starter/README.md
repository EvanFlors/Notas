# Starter — jk-02-01-first-pipeline-job

El entregable vive en `/tmp/jk-02-pipeline/` (o la ruta que pases al validador). Esta carpeta no contiene codigo precargado: el objetivo es que escribas tu `Jenkinsfile` desde cero siguiendo el `README.md` de la actividad.

## Checklist rapido

- [ ] `mkdir -p /tmp/jk-02-pipeline`
- [ ] (Si tienes Docker) `docker run ... jenkins/jenkins:lts` y setup wizard completo.
- [ ] Escribir `/tmp/jk-02-pipeline/Jenkinsfile` cumpliendo los 8 requisitos del punto 5.3 del README.
- [ ] (Si tienes Docker) crear Pipeline job `first-pipeline-job` en Jenkins y correr **Build Now** → SUCCESS.
- [ ] Escribir `/tmp/jk-02-pipeline/README-INTENT.md` con las 4 secciones obligatorias.
- [ ] `bash tests/validate.sh /tmp/jk-02-pipeline` → OK.

## Esqueleto sugerido del `Jenkinsfile`

Partir de aqui es valido, pero debes **completar y adaptar** (no entregar literalmente este snippet):

```groovy
pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Hello') {
            steps {
                echo 'TODO: tu mensaje'
                sh 'uname -a'
            }
        }
        stage('TODO: segundo stage') {
            steps {
                echo 'TODO'
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

## Secciones esperadas en `README-INTENT.md`

```
## Pipeline anatomy
## Freestyle vs Pipeline
## Retention
## Run evidence
```
