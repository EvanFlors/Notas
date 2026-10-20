# Referencia semántica — jk-03-01

Este documento acompaña `solution/Jenkinsfile` y explica las decisiones.

## Mapeo detallado del workflow GHA al Jenkinsfile

| GHA job / clave | Jenkinsfile — stage / construcción | Nota |
|-----------------|-----------------------------------|------|
| `env:` top-level | `environment { APP_NAME, REGISTRY, VERSION }` | `VERSION` se calcula desde `BUILD_NUMBER`. |
| `jobs.lint` (container `node:20-alpine`) | `stage('Lint')` con `agent { docker { image 'node:20-alpine' } }` | Mapeo literal. |
| `jobs.test` con `strategy.matrix.node-version: [18, 20]` | `stage('Test')` con **un solo** agent `node:20-alpine` | Se simplifica. Para replicar matrix, usar bloque `matrix { }` dentro de `stages { }` — se comenta en el Jenkinsfile. |
| `jobs.build-and-push` con `if: github.ref == 'refs/heads/main'` | `stage('Build')` con `when { beforeAgent true; branch 'main' }` | `beforeAgent true` evita levantar el runner Docker en PRs. |
| `secrets.GHCR_TOKEN` | `withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) { ... }` | Explícito y nombrado; evita acoplar al `environment`. |
| `jobs.deploy-staging` con `environment: staging` | `stage('Deploy staging')` con `when { branch 'main' }` + `withCredentials([file(credentialsId: 'kubeconfig-staging', variable: 'KUBECONFIG')])` | El `environment: staging` de GHA (sin protection rule) se traduce a un stage normal condicionado por rama. |
| `jobs.deploy-prod` con `environment: production` (protection rule) | **No implementado aquí** — se añade en `jk-03-02` con `input` + `timeout` + `submitter`. | Separar el gate humano del flow principal es exactamente el objetivo de la actividad 02. |
| `actions/upload-artifact` | `archiveArtifacts` + `junit` en `post { always { ... } }` | Correcto: nunca en `steps { }` directamente, para que corra aunque el stage falle. |

## Por qué `agent none` + `agent` por stage

- Cada stage corre en el contenedor o nodo que necesita (Alpine + Node para lint/test, host con Docker para build, imagen con kubectl para deploy).
- El workspace no se comparte entre stages con `agent` distinto, por eso se usa `stash` en `Checkout` y `unstash` en los stages que necesitan el código.
- Alternativa: `agent any` global. Simplifica, pero fuerza a tener Docker, Node y kubectl en el mismo nodo. No escala.

## Decisiones defendibles vs antipatrones

| Decisión | Justificación |
|----------|---------------|
| `disableConcurrentBuilds()` | Evita que dos builds pisen el deploy de staging. En multibranch, considerar quitarlo. |
| `buildDiscarder(logRotator(numToKeepStr: '30'))` | Retención finita por job, obligatorio en controllers con disco finito. |
| `beforeAgent true` en Build/Deploy | Ahorra levantar el agent Docker en PRs — crítico con decenas de PRs/día. |
| `withCredentials` en vez de `credentials()` dentro de `environment` para GHCR_TOKEN | Más explícito; limita el scope del secret al stage concreto. |
| `file(...)` para KUBECONFIG | `credentials()` no soporta archivos — hay que usar `withCredentials`. |
| `junit` en `post { always { ... } }` | Imprescindible: si el `sh 'npm test'` falla, el stage se aborta antes de llegar a `junit` si lo pusiéramos en `steps { }`. |

## Diferencias semánticas que **no** se pueden ocultar

1. **Protection rules de GHA** no tienen equivalente puro en Jenkins. Se emulan con `input` + `submitter` (Role-based Authorization) → `jk-03-02` y `jk-07`.
2. **Matrix de Node** se omite por simplicidad; `matrix { }` existe en Declarative pero multiplica el coste de agent.
3. **`actions/cache`** no tiene equivalente directo. En Jenkins se cachea con `stash` entre stages del mismo build, o con un volumen montado en el agent Docker.
4. **Secrets por environment** (GHA permite scoping por `environment: production`) se traducen a credentials folder-scoped en Jenkins.
