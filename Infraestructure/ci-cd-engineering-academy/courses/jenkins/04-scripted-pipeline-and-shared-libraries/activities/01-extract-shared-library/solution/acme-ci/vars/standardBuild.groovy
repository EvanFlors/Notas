// vars/standardBuild.groovy
//
// Step global de la Shared Library acme-ci. Encapsula el pipeline estandar
// de la organizacion: checkout -> test -> build -> push (solo en main) y
// delega toda la logica de dominio en org.acme.ci.BuildContext.

import org.acme.ci.BuildContext

def call(Map args = [:]) {
  assert args.image : "standardBuild: 'image' es obligatorio"
  BuildContext ctx = new BuildContext(args)

  pipeline {
    agent any
    options {
      timeout(time: ctx.timeoutMinutes, unit: 'MINUTES')
      disableConcurrentBuilds()
    }
    stages {
      stage('Checkout') {
        steps { checkout scm }
      }
      stage('Test') {
        steps { sh 'make test' }
        post {
          always { junit allowEmptyResults: true, testResults: 'reports/*.xml' }
        }
      }
      stage('Build') {
        steps { sh "docker build -t ${ctx.imageRef()} ." }
      }
      stage('Push') {
        when { branch 'main' }
        steps {
          withCredentials([usernamePassword(credentialsId: 'ghcr',
                                            usernameVariable: 'U',
                                            passwordVariable: 'P')]) {
            sh 'echo $P | docker login ghcr.io -u $U --password-stdin'
            sh "docker push ${ctx.imageRef()}"
          }
        }
      }
    }
    post {
      failure { echo "standardBuild: build fallo para ${ctx.image}" }
    }
  }
}
