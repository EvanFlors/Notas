// seed-jobs.groovy — ejecutado por el seed job definido en jenkins.yaml.
// Genera carpetas y jobs del controller de forma declarativa.

folder('legacy') {
    description('Jobs heredados del Jenkins snowflake original. En migracion.')
}

folder('product') {
    description('Jobs de productos activos — repos con Jenkinsfile.')
}

pipelineJob('legacy/batch-nightly') {
    description('Batch nocturno de reconciliacion — migrado desde freestyle.')
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

pipelineJob('legacy/manual-release') {
    description('Release manual — se dispara desde la UI con parametro.')
    parameters {
        stringParam('VERSION', '', 'Version semver a liberar, ej. 1.4.2')
    }
    definition {
        cpsScm {
            scm {
                git {
                    remote { url('https://github.com/example/release-tools.git') }
                    branch('main')
                }
            }
            scriptPath('Jenkinsfile.release')
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
