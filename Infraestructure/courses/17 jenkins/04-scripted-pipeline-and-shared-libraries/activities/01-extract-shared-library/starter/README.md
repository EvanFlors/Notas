# Starter — jk-04-01-extract-shared-library

Esta actividad es **independiente**: produces un árbol de archivos con el layout de una Shared Library.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-04-shared-library/acme-ci/vars
   mkdir -p /tmp/jk-04-shared-library/acme-ci/src/org/acme/ci
   mkdir -p /tmp/jk-04-shared-library/acme-ci/resources/org/acme/ci
   mkdir -p /tmp/jk-04-shared-library/consumer-repo
   cd /tmp/jk-04-shared-library
   ```
3. Escribe los archivos (nombres exactos — el validador los busca):
   - `acme-ci/vars/standardBuild.groovy`
   - `acme-ci/src/org/acme/ci/BuildContext.groovy`
   - `acme-ci/resources/org/acme/ci/pipeline-settings.yaml`
   - `consumer-repo/Jenkinsfile`
   - `README-INTENT.md`
4. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/04-scripted-pipeline-and-shared-libraries/activities/01-extract-shared-library/tests/validate.sh /tmp/jk-04-shared-library
   ```
5. Compara con `../solution/` para autoevaluarte.

## Esqueletos útiles

### `vars/standardBuild.groovy`

```groovy
import org.acme.ci.BuildContext

def call(Map args = [:]) {
  // TODO: validar args, construir BuildContext, orquestar stages
}
```

### `src/org/acme/ci/BuildContext.groovy`

```groovy
package org.acme.ci

class BuildContext implements Serializable {
  String image
  String registry
  List<String> deploy

  BuildContext(Map args) {
    // TODO: inicializar con defaults sensatos
  }
}
```

### `consumer-repo/Jenkinsfile`

```groovy
@Library('acme-ci@v1.0.0') _

standardBuild(
  image: 'checkout-api'
  // TODO: pasar deploy y otros parámetros
)
```

### `README-INTENT.md`

```
# Refactor a Shared Library — acme-ci

## Layout
...

## Pinning
...

## Governance
...
```

> El validador comprueba layout, palabras clave y presencia de secciones. **No** ejecuta Groovy.
