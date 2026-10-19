// vars/standardBuild.groovy
//
// Step global opinado de la organizacion.
//
// Contrato publico (ver README-INTENT.md):
//   standardBuild(
//     image:           String   // obligatorio
//     registry:        String   // opcional, default 'ghcr.io/acme'
//     deploy:          List     // opcional, default ['dev']
//     requireApproval: Boolean  // opcional, default false
//   )

import org.acme.ci.StandardBuild

def call(Map args = [:]) {
  // Validacion temprana: error claro antes de levantar un agent.
  if (!args.image) {
    throw new IllegalArgumentException(
      "standardBuild: 'image' es obligatorio. Ejemplo: standardBuild(image: 'checkout-api')"
    )
  }
  if (args.deploy != null && !(args.deploy instanceof List)) {
    throw new IllegalArgumentException(
      "standardBuild: 'deploy' debe ser una lista, no ${args.deploy.getClass().simpleName}"
    )
  }
  assert args.image instanceof String : "standardBuild: 'image' debe ser String"

  StandardBuild build = new StandardBuild(args)

  pipeline {
    agent any
    options {
      timeout(time: 20, unit: 'MINUTES')
      disableConcurrentBuilds()
    }
    stages {
      stage('Checkout') {
        steps { checkout scm }
      }
      stage('Build') {
        steps {
          sh "docker build -t ${build.imageRef()} ."
        }
      }
      stage('Notify') {
        steps {
          script {
            def tpl = libraryResource('org/acme/ci/notify-template.md')
            def msg = tpl
              .replace('${status}', currentBuild.currentResult ?: 'IN_PROGRESS')
              .replace('${image}', build.image)
              .replace('${buildUrl}', env.BUILD_URL ?: '')
            echo msg
          }
        }
      }
    }
    post {
      failure {
        echo "standardBuild: build fallo para ${build.image}"
      }
    }
  }
}
