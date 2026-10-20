# Starter — jk-03-02

Punto de partida: el `Jenkinsfile` que produjiste en `jk-03-01` (o `../01-port-gha-workflow-to-jenkinsfile/solution/Jenkinsfile` si saltaste).

## Esqueleto del gate

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

stage('Deploy prod') {
  when { branch 'main' }
  agent { docker { image 'bitnami/kubectl:1.30' } }
  steps {
    withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
      sh '''
        kubectl set image deploy/demo-api \
          demo-api="$REGISTRY/$APP_NAME:$VERSION"
      '''
    }
  }
}
```

Y en el `post { }`:

```groovy
post {
  always  { echo "Build result: ${currentBuild.result ?: 'SUCCESS'}" }
  success { echo 'Deploy a prod OK' }
  failure { echo 'FAIL — rollback manual necesario' }
  aborted { echo 'Deploy a prod abortado (timeout o cancelacion del gate)' }
}
```

## Cómo validar

```bash
bash ../tests/validate.sh /tmp/jk-03-02
```

Esperado: `0 issue(s)`.
