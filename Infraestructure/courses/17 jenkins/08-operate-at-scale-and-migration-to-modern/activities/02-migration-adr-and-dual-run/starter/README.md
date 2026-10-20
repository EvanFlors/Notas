# Starter — jk-08-02-migration-adr-and-dual-run

Entregas 3 archivos: ADR + Jenkinsfile + workflow GHA.

## Pasos

1. Lee `../README.md` completo. Recorre `../../examples/02-dual-run-jenkins-and-gha/` y `../../examples/03-migration-plan-template/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-08-02/.github/workflows
   cd /tmp/jk-08-02
   ```
3. Escribe `ADR-MIGRATION.md` siguiendo las secciones y contenidos mínimos del README.
4. Escribe `Jenkinsfile` para `orders-api-ci` (declarative, con `withCredentials` en publish — es el patrón viejo que la migración elimina).
5. Escribe `.github/workflows/dual-run.yml` equivalente usando **OIDC** (`permissions: id-token: write` + `role-to-assume:` — **sin** access keys).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/08-operate-at-scale-and-migration-to-modern/activities/02-migration-adr-and-dual-run/tests/validate.sh /tmp/jk-08-02
   ```
7. Compara con `../solution/REFERENCE.md`, `../solution/Jenkinsfile` y `../solution/dual-run.yml` para autoevaluarte.

## Esqueletos útiles

### Jenkinsfile (patrón viejo, `withCredentials`)

```groovy
pipeline {
  agent any
  stages {
    stage('Install') { steps { sh 'make deps' } }
    stage('Test')    { steps { sh 'make test' } }
    stage('Publish') {
      when { branch 'main' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-prod',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh 'aws s3 cp dist/ s3://releases/ --recursive'
        }
      }
    }
  }
}
```

### Workflow GHA (patrón nuevo, OIDC)

```yaml
name: dual-run-ci
on:
  push: { branches: [main] }
  pull_request:
permissions:
  id-token: write
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make deps
      - run: make test
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111111111111:role/gha-orders-api
          aws-region: eu-west-1
      - if: github.ref == 'refs/heads/main'
        run: aws s3 cp dist/ s3://releases/ --recursive
```

> El validador comprueba sintaxis mínima y presencia de patrones (OIDC, no access keys como inputs del action, 3 stages/fases).
