// seed-jobs.groovy — jobs del controller Plataforma.
// Lo ejecuta el seed job definido en jenkins.yaml.

folder('legacy') {
    description('Jobs heredados del Jenkins snowflake — en migracion a Multibranch.')
}

folder('product') {
    description('Jobs de productos activos con Jenkinsfile versionado.')
}

folder('ops') {
    description('Jobs operativos de la plataforma (release, cleanup, rotacion).')
}

pipelineJob('legacy/batch-nightly') {
    description('Batch nocturno de reconciliacion — pipeline migrado desde freestyle.')
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

pipelineJob('ops/rotate-credentials') {
    description('Rotacion mensual de credenciales via workflow operativo.')
    triggers {
        cron('H 3 1 * *')
    }
    definition {
        cpsScm {
            scm {
                git {
                    remote { url('https://github.com/example/ops-tools.git') }
                    branch('main')
                }
            }
            scriptPath('Jenkinsfile.rotate')
        }
    }
}

multibranchPipelineJob('product/checkout') {
    description('Pipeline Multibranch del servicio checkout.')
    branchSources {
        github {
            id('checkout')
            repoOwner('example')
            repository('checkout')
            credentialsId('github-bot')
            scanCredentialsId('github-bot')
        }
    }
    orphanedItemStrategy {
        discardOldItems {
            numToKeep(20)
        }
    }
}
