# Ejemplo 01 — Scripted vs Declarative, lado a lado

> Lectura. Objetivo: ver el **mismo pipeline** escrito en los dos dialectos y predecir qué pierde (y qué gana) cada uno.

## El pipeline

Un flujo mínimo: checkout → unit tests → build Docker image → push al registry si estamos en `main`.

## Declarative

```groovy
pipeline {
  agent { label 'linux' }
  options {
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }
  environment {
    IMAGE = "ghcr.io/acme/checkout-api"
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Test') {
      steps { sh 'make test' }
      post {
        always { junit 'reports/*.xml' }
      }
    }
    stage('Build') {
      steps { sh "docker build -t ${IMAGE}:${env.BUILD_NUMBER} ." }
    }
    stage('Push') {
      when { branch 'main' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'ghcr', usernameVariable: 'U', passwordVariable: 'P')]) {
          sh 'echo $P | docker login ghcr.io -u $U --password-stdin'
          sh "docker push ${IMAGE}:${env.BUILD_NUMBER}"
        }
      }
    }
  }
  post {
    failure { echo 'build failed — notify oncall' }
  }
}
```

Lo que **gana**: estructura rígida (`agent`, `options`, `stages`, `post` siempre en el mismo orden), chequeos sintácticos del plugin, `when` nativo, legible para quien no sabe Groovy.

Lo que **pierde**: cualquier lógica dinámica necesita escapar a `script {}`. Si quieres iterar `deploy` sobre una lista variable de entornos, lo haces con `script { ['dev','stg','prod'].each { ... } }` — el DSL no te lo permite directo.

## Scripted (equivalente aproximado)

```groovy
node('linux') {
  timeout(time: 20, unit: 'MINUTES') {
    def image = "ghcr.io/acme/checkout-api"

    stage('Checkout') {
      checkout scm
    }

    stage('Test') {
      try {
        sh 'make test'
      } finally {
        junit 'reports/*.xml'
      }
    }

    stage('Build') {
      sh "docker build -t ${image}:${env.BUILD_NUMBER} ."
    }

    if (env.BRANCH_NAME == 'main') {
      stage('Push') {
        withCredentials([usernamePassword(credentialsId: 'ghcr', usernameVariable: 'U', passwordVariable: 'P')]) {
          sh 'echo $P | docker login ghcr.io -u $U --password-stdin'
          sh "docker push ${image}:${env.BUILD_NUMBER}"
        }
      }
    }
  }
}
```

Lo que **gana**: control total. `if`, `for`, excepciones, variables locales, cualquier cosa que Groovy permite. Puedes decidir el conjunto de stages a runtime (`for env in envs { stage(env) { ... } }`).

Lo que **pierde**: no hay `options {}` ni `post {}` estructurados — todo se expresa con `try/finally`, llamadas a `properties(...)`, y `catchError { ... }`. El pipeline deja de ser auto-descriptivo: hay que **ejecutarlo** para saber qué stages aparecerán. `disableConcurrentBuilds()` del declarative aquí se expresa con `properties([disableConcurrentBuilds()])` dentro del `node`.

## Observaciones

1. **Nunca el mismo pipeline**: la versión scripted de arriba no es exactamente equivalente. Faltan matices (p. ej. el `post { failure }` global). Reproducir Declarative exactamente en Scripted requiere ~40 líneas de boilerplate extra.
2. **El `agent` cambia de semántica**: en Declarative, `agent { label 'linux' }` reserva el agent para **todo** el pipeline y gestiona el workspace; en Scripted, `node('linux') { ... }` hace lo mismo pero tú controlas el bloque.
3. **El `script {}` escape**: en Declarative puedes añadir un `stage('Dynamic') { steps { script { ... } } }` para traer flexibilidad puntual. En Scripted ya estás dentro de "modo script" todo el rato.

## Cuándo escribir cada uno

- **Código nuevo**: Declarative, siempre. La lógica que no cabe se mueve a Shared Library.
- **Mantener legacy**: no reescribas scripted → declarative "por gusto". Reescribe cuando toque modificar el pipeline por otra razón.
- **DSL imposible**: hay casos donde Declarative es inviable (p. ej. construir dinámicamente la matriz de `parallel` basada en una API externa). Scripted puro o Shared Library con un step encapsulador.
