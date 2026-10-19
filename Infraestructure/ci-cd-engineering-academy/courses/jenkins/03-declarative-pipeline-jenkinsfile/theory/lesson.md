# jk-03 — Lección: Declarative Pipeline y el Jenkinsfile versionado

> 10 secciones. Mayoritariamente conceptual con fragmentos reales de Jenkinsfile. Prerrequisitos: `jk-02`.

---

## 1. Por qué Declarative y no Scripted como punto de entrada

Jenkins ofrece **dos** DSLs sobre Groovy para describir un pipeline-as-code:

1. **Scripted Pipeline** (`node { ... }`): Groovy puro, cualquier estructura de control es válida. Flexibilidad total, pero también margen total para pipelines que nadie se atreve a tocar seis meses después.
2. **Declarative Pipeline** (`pipeline { ... }`): un DSL restringido con estructura validable, chequeos sintácticos estáticos y mensajes de error claros. Es el **modo recomendado** oficial desde ~2017.

En 2026, el estándar es: **todo nuevo pipeline nace Declarative**. Scripted se mantiene por legacy y, dentro de Declarative, se baja a Scripted sólo dentro de un bloque `script { ... }` cuando no hay alternativa (y revisándolo en PR como se revisa un `eval` en Python).

> **Idea clave que repetiremos:** Declarative es un contrato. El pipeline tiene bloques fijos en orden fijo. Si no cabe en el contrato, probablemente estás resolviendo el problema en el sitio equivocado (candidato a Shared Library — próximo módulo).

---

## 2. Anatomía del `Jenkinsfile`: los bloques top-level

Un `Jenkinsfile` declarative mínimo-realista tiene esta forma:

```groovy
pipeline {
  agent any

  options {
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    booleanParam(name: 'DEPLOY_PROD', defaultValue: false, description: 'Despliega a prod si true')
    choice(name: 'ENV', choices: ['dev', 'stg', 'prod'], description: 'Entorno destino')
  }

  environment {
    APP_NAME   = 'demo-api'
    REGISTRY   = 'ghcr.io/acme'
    VERSION    = "${env.BUILD_NUMBER}"
  }

  triggers {
    pollSCM('H/5 * * * *')
  }

  stages {
    stage('Lint') {
      steps { sh 'make lint' }
    }
  }

  post {
    always  { echo "Build ${currentBuild.result ?: 'SUCCESS'}" }
    failure { echo 'Avisar al canal de Slack' }
  }
}
```

Reglas de oro:

- **`pipeline { }` siempre al nivel más externo**, nada antes salvo `@Library(...)`.
- **`agent` es obligatorio** justo tras `pipeline {`. Puede ser `any`, `none` (y entonces lo pones por `stage`) o un agente específico.
- Los bloques internos tienen **orden recomendado**: `agent`, `options`, `parameters`, `environment`, `triggers`, `tools`, `stages`, `post`. El linter acepta otros órdenes, pero mantener este orden hace el `Jenkinsfile` legible.
- **`stages { }` contiene `stage { }`**, y cada `stage { }` contiene `steps { }` o `parallel { }` o `stages { }` anidadas (matrix, etc.).

---

## 3. `agent`: dónde se ejecuta cada cosa

El `agent` dice en **qué máquina** (o qué contenedor) corre el pipeline. Variantes:

```groovy
agent any                                // cualquier executor libre del controller o nodes conectados
agent none                               // nada — cada stage declara el suyo (patrón recomendado)
agent { label 'linux && docker' }        // nodo que matchee ambas labels
agent { docker { image 'node:20-alpine'; args '-u root' } }     // contenedor efímero por build
agent { dockerfile { filename 'ci/Dockerfile' } }                // build de la imagen desde el repo
agent { kubernetes { yaml '''...''' } }  // Pod en K8s (plugin kubernetes — jk-05)
```

El patrón **`agent none` + `agent` por `stage`** es el más defensivo:

```groovy
pipeline {
  agent none
  stages {
    stage('Lint')  { agent { docker { image 'node:20-alpine' } }; steps { sh 'npm run lint' } }
    stage('Test')  { agent { docker { image 'node:20-alpine' } }; steps { sh 'npm test' } }
    stage('Build') { agent { label 'linux && docker' };            steps { sh 'docker build .' } }
  }
}
```

Ventajas: cada stage declara su entorno, cada stage puede correr en un nodo distinto, un `stage` lento no bloquea un executor de alta prioridad. Contrapartida: el workspace **no persiste** entre stages con `agent` distinto — para pasar archivos entre ellos se usa `stash` / `unstash` (sección 7).

---

## 4. `stages`, `steps` y el flujo del pipeline

Un `stage { }` es una fase lógica del pipeline (lint, test, build, deploy). Un `steps { }` es la lista de acciones de esa fase. Steps más usados:

| Step | Qué hace |
|------|----------|
| `sh 'make test'` | Ejecuta un comando shell en Linux/Mac. En Windows: `bat`. |
| `script { ... }` | Baja a Scripted (Groovy puro). Último recurso. |
| `withEnv(['FOO=bar']) { ... }` | Añade variables de entorno sólo a los steps dentro del bloque. |
| `dir('subpath') { ... }` | Cambia de directorio dentro del workspace. |
| `stash` / `unstash` | Pasa archivos entre stages con `agent` distinto. |
| `archiveArtifacts artifacts: '**/dist/**', fingerprint: true` | Guarda artefactos en el controller. |
| `junit '**/test-results/*.xml'` | Reporta resultados JUnit en la UI. |
| `publishHTML target: [reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage']` | Publica un HTML como pestaña del build. |
| `input message: '¿Desplegar prod?'` | Pausa el pipeline esperando aprobación humana (gate — sección 9). |

Reglas:

- Dentro de `steps { }` no puedes meter estructuras Groovy sueltas (`if`, `for`, `def`). Para eso: `script { }` o — mejor — refactor a Shared Library.
- `sh` falla el stage si el exit code es ≠ 0. Para capturar el exit sin fallar: `sh(script: 'cmd', returnStatus: true)` o `returnStdout: true`.

---

## 5. `environment` y `parameters`

### 5.1 `environment`

Define variables disponibles en **todos** los steps del pipeline (o del stage, si se declara dentro). Soporta interpolación y, muy importante, **credential helpers**:

```groovy
environment {
  APP_NAME = 'demo-api'
  AWS_REGION = 'eu-west-1'
  // credential helper — expone 3 vars: AWS_CREDS, AWS_CREDS_USR, AWS_CREDS_PSW
  AWS_CREDS = credentials('aws-ci-user')
}
```

El valor devuelto por `credentials('id')` depende del tipo de credencial:

- **Secret text** → una sola variable con el string.
- **Username/password** → tres variables: `NAME`, `NAME_USR`, `NAME_PSW`.
- **SSH key** / **file** → `credentials()` **no** funciona para estos tipos. Hay que usar `withCredentials { ... }` (sección 8).

### 5.2 `parameters`

Expone al usuario que lanza el build un formulario con parámetros. Tipos: `string`, `text`, `booleanParam`, `choice`, `password`, `file`.

```groovy
parameters {
  choice(name: 'ENV', choices: ['dev', 'stg', 'prod'], description: 'Entorno destino')
  booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Saltar tests (NO en main)')
}
```

Antipatrón común: convertir el pipeline en un formulario con 15 parámetros para "flexibilidad". Si necesitas 15 parámetros, probablemente necesitas 3 pipelines distintos o una Shared Library con una función `buildAndDeploy(opts)`.

---

## 6. `when`: condicionales por `stage`

`when { }` decide si un stage se ejecuta. Es la alternativa declarativa a los `if` sueltos:

```groovy
stage('Deploy prod') {
  when {
    allOf {
      branch 'main'
      expression { return params.DEPLOY_PROD }
      not { changeRequest() }
    }
  }
  steps { sh './scripts/deploy.sh prod' }
}
```

Operadores soportados: `branch`, `buildingTag`, `tag`, `changelog`, `changeset`, `changeRequest`, `environment`, `equals`, `expression`, `anyOf`, `allOf`, `not`, `triggeredBy`.

**Peculiaridad útil**: `beforeAgent true` dentro de `when { }` evalúa la condición **antes** de levantar el agent — crítico cuando el agent es un contenedor Docker caro de iniciar y la mayoría de ramas no deben ejecutar ese stage:

```groovy
stage('Deploy') {
  agent { docker { image 'hashicorp/terraform:1.9' } }
  when { beforeAgent true; branch 'main' }
  steps { sh 'terraform apply -auto-approve' }
}
```

---

## 7. `stash` / `unstash` y artefactos compartidos entre stages

Cuando cada `stage` corre en un `agent` distinto, el workspace no se comparte. Para pasar archivos:

```groovy
stage('Build') {
  agent { docker { image 'node:20-alpine' } }
  steps {
    sh 'npm run build'
    stash name: 'dist', includes: 'dist/**'
  }
}
stage('Package') {
  agent { label 'linux && docker' }
  steps {
    unstash 'dist'
    sh 'docker build -t demo:$BUILD_NUMBER .'
  }
}
```

`stash` guarda los archivos en el controller y los libera al terminar el build. Para artefactos que deben sobrevivir al build (o descargarse después), usa `archiveArtifacts`.

---

## 8. Credenciales: `credentials('id')` vs `withCredentials { }`

### 8.1 `credentials('id')` como variable de entorno

Simple, legible, útil para secrets planos y user/pass. Ya mostrado en §5.1.

### 8.2 `withCredentials { }` como bloque

Más flexible. Soporta tipos que `credentials()` no soporta (SSH key, file, cert) y permite nombrar explícitamente las variables:

```groovy
steps {
  withCredentials([
    string(credentialsId: 'vault-token', variable: 'VAULT_TOKEN'),
    usernamePassword(credentialsId: 'registry-creds',
                     usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
    file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')
  ]) {
    sh '''
      vault login "$VAULT_TOKEN"
      echo "$REG_PASS" | docker login ghcr.io -u "$REG_USER" --password-stdin
      kubectl --kubeconfig "$KUBECONFIG" get pods
    '''
  }
}
```

Reglas no negociables:

- **Nunca `echo "$SECRET"`**: Jenkins enmascara los valores en la UI, pero si el `echo` cae en un artefacto o en un error de otro proceso, el secreto puede escapar.
- **No concatenes el secret en Groovy** (`def cmd = "curl -H 'Auth: ${TOKEN}'"`). Usa el secreto **dentro del shell**, no en el Groovy del pipeline. El enmascarado funciona sólo para el valor exacto en logs.
- **Usa un `credentialsId` por secret**, no un bucket con todas las credenciales.

---

## 9. `post` y `input`: cerrar bien y abrir gates

### 9.1 `post`

El bloque `post { }` corre después de los `stages`. Es imprescindible para publicar resultados y notificar:

```groovy
post {
  always   { junit '**/test-results/*.xml' }
  success  { echo 'OK — publicar status check verde' }
  failure  { echo 'Avisar a Slack con enlace al build' }
  unstable { echo 'Hay tests marcados como flaky' }
  changed  { echo 'El estado cambió respecto al build anterior' }
  fixed    { echo 'Build vuelve a verde tras rojos' }
  aborted  { echo 'Build cancelado (p.ej. gate manual con timeout)' }
}
```

Antipatrón: poner `junit` en el `steps` del stage de test. Si el `sh 'npm test'` falla, el stage se aborta antes de `junit`. **Siempre** publica reports en `post { always { ... } }`.

### 9.2 `input`: gate manual

```groovy
stage('Approve prod deploy') {
  when { branch 'main' }
  steps {
    timeout(time: 15, unit: 'MINUTES') {
      input message: '¿Desplegar a producción?',
            ok: 'Desplegar',
            submitter: 'release-managers'
    }
  }
}
```

Reglas:

- **Siempre envuelve `input` en `timeout`**: un gate olvidado deja el pipeline bloqueado consumiendo un slot del controller por horas o días.
- Define `submitter` (usuario o grupo) si quieres restringir quién aprueba. Sin `submitter`, cualquier usuario con permiso de build puede aprobar.
- Si el `input` expira o se cancela, el build pasa a estado `aborted` → maneja la limpieza en `post { aborted { ... } }`.

---

## 10. Linting y validación local

Un `Jenkinsfile` roto detectado en el momento de hacer push es caro (ocupa un build, bloquea otros). Opciones de validación:

### 10.1 Validación semántica con `jenkins-cli declarative-linter`

Requiere un controller accesible y el plugin `pipeline-model-definition`:

```bash
curl -s "$JENKINS_URL/pipeline-model-converter/validate" \
  --user "$USER:$API_TOKEN" \
  -F "jenkinsfile=<Jenkinsfile"
```

Devuelve mensajes del parser oficial. Es la validación **real**.

### 10.2 Validación estructural con `grep` (sin Jenkins)

Útil en CI o pre-commit cuando no hay un controller disponible. Es lo que usan los validadores de este módulo:

```bash
grep -qE '^\s*pipeline\s*\{'           Jenkinsfile || echo 'FAIL: falta pipeline { }'
grep -qE '^\s*agent\s'                 Jenkinsfile || echo 'FAIL: falta agent'
grep -qE '^\s*stages\s*\{'             Jenkinsfile || echo 'FAIL: falta stages { }'
grep -qE '^\s*post\s*\{'               Jenkinsfile || echo 'FAIL: falta post { }'
```

No sustituye al linter oficial, pero captura el 80% de los errores (bloques faltantes, nombres mal escritos). Es la base del validador de las actividades `01` y `02`.

### 10.3 Pre-commit hook recomendado

```bash
#!/usr/bin/env bash
set -eu
# Hook pre-commit: validación estructural + linter si JENKINS_URL está definido.
bash courses/jenkins/03-declarative-pipeline-jenkinsfile/activities/01-port-gha-workflow-to-jenkinsfile/tests/validate.sh "$(pwd)"
if [ -n "${JENKINS_URL:-}" ]; then
  curl -sf "$JENKINS_URL/pipeline-model-converter/validate" \
    --user "$JENKINS_USER:$JENKINS_TOKEN" \
    -F "jenkinsfile=<Jenkinsfile" || { echo 'linter falló'; exit 1; }
fi
```

---

## Resumen

- **Declarative** es el modo por defecto en 2026; **Scripted** se mantiene por legacy.
- Un `Jenkinsfile` tiene **bloques fijos**: `agent`, `options`, `parameters`, `environment`, `triggers`, `stages`, `post`.
- `agent none` + `agent` por `stage` es el patrón más defensivo; `stash` / `unstash` para compartir archivos.
- `when { beforeAgent true }` ahorra levantar contenedores innecesarios.
- Credenciales: `credentials('id')` para casos simples, `withCredentials { }` para todo lo demás. **Nunca** se concatena en Groovy.
- `post { always }` para `junit` / `archiveArtifacts`; `input` + `timeout` para gates humanos.
- Valida **antes** de hacer push: `declarative-linter` si tienes Jenkins, `grep` estructural si no.
