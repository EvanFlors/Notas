# Ejemplo 02 — Esqueleto de una Shared Library

> Lectura. Objetivo: saber dónde va cada cosa en una Shared Library y cómo se consume.

## Layout mínimo

```
acme-ci/                                        # repo Git separado
├── CHANGELOG.md
├── CODEOWNERS
├── README.md
├── vars/
│   ├── standardBuild.groovy                    # step global standardBuild(...)
│   ├── standardBuild.txt                       # ayuda opcional para el editor
│   └── notifySlack.groovy                      # step global notifySlack(...)
├── src/
│   └── org/
│       └── acme/
│           └── ci/
│               ├── BuildContext.groovy         # clase Groovy con dominio
│               └── Notifier.groovy             # helpers
└── resources/
    └── org/
        └── acme/
            └── ci/
                └── pipeline-settings.yaml      # fichero estático
```

## `vars/standardBuild.groovy` (fachada)

```groovy
// vars/standardBuild.groovy
import org.acme.ci.BuildContext

def call(Map args = [:]) {
  // Validación de parámetros
  assert args.image : "standardBuild: 'image' es obligatorio"
  def ctx = new BuildContext(args)

  pipeline {
    agent any
    options { timeout(time: 20, unit: 'MINUTES') }
    stages {
      stage('Checkout') { steps { checkout scm } }
      stage('Test')     { steps { sh 'make test' } }
      stage('Build')    { steps { sh "docker build -t ${ctx.imageRef()} ." } }
      stage('Push') {
        when { branch 'main' }
        steps { sh "docker push ${ctx.imageRef()}" }
      }
    }
    post {
      always  { notifySlack(status: currentBuild.currentResult, context: ctx) }
    }
  }
}
```

Puntos:

- Un fichero por step público. El método se llama `call` y Groovy lo invoca cuando escribes `standardBuild(...)`.
- Validación temprana con `assert` o lanzando `IllegalArgumentException`.
- Delegación a `BuildContext` (clase en `src/`) para toda lógica que no sea "orquestar stages".

## `src/org/acme/ci/BuildContext.groovy` (dominio)

```groovy
package org.acme.ci

class BuildContext implements Serializable {
  String image
  String registry = 'ghcr.io/acme'
  List<String> deploy = []

  BuildContext(Map args) {
    this.image    = args.image
    this.registry = args.registry ?: this.registry
    this.deploy   = args.deploy   ?: this.deploy
  }

  String imageRef() {
    return "${registry}/${image}:${System.getenv('BUILD_NUMBER') ?: 'local'}"
  }
}
```

Puntos:

- `implements Serializable`: obligatorio para clases que viven en el estado del pipeline (CPS). Si falta, el pipeline falla al suspender/reanudar.
- `package org.acme.ci`: debe coincidir con la ruta bajo `src/`.
- Groovy clásico: constructor, propiedades, métodos. Nada "mágico".

## `resources/org/acme/ci/pipeline-settings.yaml` (recurso)

```yaml
# Default settings consumidas por BuildContext
registry: ghcr.io/acme
defaultEnvs: [dev]
timeoutMinutes: 20
```

Leído desde la library:

```groovy
def raw = libraryResource('org/acme/ci/pipeline-settings.yaml')
def settings = readYaml(text: raw)   // requiere plugin pipeline-utility-steps
```

## Consumidor (en el repo de la app)

```groovy
// Jenkinsfile
@Library('acme-ci@v1.3.0') _
standardBuild(
  image:   'checkout-api',
  deploy:  ['dev', 'stg', 'prod']
)
```

15 líneas o menos. Toda la lógica vive en la library, versionada.
