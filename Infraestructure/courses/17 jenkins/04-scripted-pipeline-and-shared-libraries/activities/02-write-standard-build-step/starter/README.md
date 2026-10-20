# Starter — jk-04-02-write-standard-build-step

Esta actividad es **independiente**: produces una Shared Library pequena con un step opinado.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-04-standard-build/vars
   mkdir -p /tmp/jk-04-standard-build/src/org/acme/ci
   mkdir -p /tmp/jk-04-standard-build/resources/org/acme/ci
   cd /tmp/jk-04-standard-build
   ```
3. Escribe los archivos (nombres exactos):
   - `vars/standardBuild.groovy`
   - `src/org/acme/ci/StandardBuild.groovy`
   - `resources/org/acme/ci/notify-template.md`
   - `Jenkinsfile`
   - `README-INTENT.md`
4. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/04-scripted-pipeline-and-shared-libraries/activities/02-write-standard-build-step/tests/validate.sh /tmp/jk-04-standard-build
   ```
5. Compara con `../solution/`.

## Esqueletos útiles

### `vars/standardBuild.groovy`

```groovy
import org.acme.ci.StandardBuild

def call(Map args = [:]) {
  if (!args.image) {
    error "standardBuild: 'image' es obligatorio"
  }
  def build = new StandardBuild(args)
  // TODO: orquestar stages Checkout, Build, Notify
}
```

### `src/org/acme/ci/StandardBuild.groovy`

```groovy
package org.acme.ci

class StandardBuild implements Serializable {
  String image
  String registry = 'ghcr.io/acme'
  List<String> deploy = ['dev']

  StandardBuild(Map args) {
    // TODO: aplicar args y defaults
  }
}
```

### `resources/org/acme/ci/notify-template.md`

```
Build ${status} para ${image}
Ver: ${buildUrl}
```

### `Jenkinsfile`

```groovy
@Library('acme-ci@v0.1.0') _

standardBuild(
  image:  'checkout-api',
  deploy: ['dev']
)
```

### `README-INTENT.md`

```
# Step standardBuild — contrato publico

## API
...

## Defaults
...

## Errores
...

## Versionado
...
```
