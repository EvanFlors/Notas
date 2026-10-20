# Ejemplo 02 — Dual-run: Jenkins + GitHub Actions

> Lectura y análisis. Mismo pipeline corriendo en los dos lados y método de comparación.

## 1. Pipeline de ejemplo: build + test + publish de una app Python

Objetivo: construir un wheel, correr tests, publicar en un bucket de artefactos. Simple a propósito — queremos ver la **mecánica del dual-run**, no la del pipeline.

## 2. Lado Jenkins — `Jenkinsfile`

```groovy
pipeline {
  agent {
    kubernetes {
      yaml '''
        apiVersion: v1
        kind: Pod
        spec:
          containers:
            - name: python
              image: python:3.12-slim
              command: ["cat"]
              tty: true
      '''
    }
  }
  environment {
    APP_NAME = 'orders-api'
  }
  stages {
    stage('Install') {
      steps {
        container('python') {
          sh 'pip install --no-cache-dir -r requirements.txt'
        }
      }
    }
    stage('Test') {
      steps {
        container('python') {
          sh 'pytest -q --junitxml=reports/junit.xml'
        }
      }
      post {
        always { junit 'reports/junit.xml' }
      }
    }
    stage('Build wheel') {
      steps {
        container('python') {
          sh 'python -m build --wheel --outdir dist/'
        }
      }
    }
    stage('Publish') {
      when { branch 'main' }
      steps {
        container('python') {
          withCredentials([usernamePassword(credentialsId: 'artifact-store',
                                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                                            passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh '''
              pip install awscli
              aws s3 cp dist/ s3://artifacts/${APP_NAME}/ --recursive
            '''
          }
        }
      }
    }
  }
  post {
    always { archiveArtifacts artifacts: 'dist/**', allowEmptyArchive: true }
  }
}
```

## 3. Lado GitHub Actions — `.github/workflows/dual-run.yml`

```yaml
name: dual-run-ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  id-token: write   # OIDC a AWS
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    container: python:3.12-slim
    steps:
      - uses: actions/checkout@v4

      - name: Install
        run: pip install --no-cache-dir -r requirements.txt

      - name: Test
        run: pytest -q --junitxml=reports/junit.xml

      - name: Upload test report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: junit
          path: reports/junit.xml

      - name: Build wheel
        run: python -m build --wheel --outdir dist/

      - name: Upload wheel
        uses: actions/upload-artifact@v4
        with:
          name: wheel
          path: dist/

  publish:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: wheel
          path: dist/

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-orders-api-publisher
          aws-region: eu-west-1

      - name: Publish to S3
        run: aws s3 cp dist/ s3://artifacts/orders-api/ --recursive
```

Diferencia clave: **GHA no usa `withCredentials` con access keys**. OIDC emite un JWT firmado por GitHub; AWS lo valida contra el OIDC provider y devuelve credenciales STS temporales. **Cero secretos de larga duración.**

## 4. Método de comparación durante el dual-run

Script `compare-runs.sh` (concepto; aquí solo descripción):

1. Para cada commit a `main`:
   - Esperar a que ambos pipelines terminen.
   - Extraer: estado (`success`/`failure`), duración, hash del wheel generado, lista de tests ejecutados.
2. Reportar en una tabla:

| Commit | Jenkins | GHA | Hash Jenkins | Hash GHA | Delta duración |
|--------|---------|-----|--------------|----------|----------------|
| `abc123` | ✓ 3m12s | ✓ 2m48s | `sha256:aaa…` | `sha256:aaa…` | -11% |
| `def456` | ✓ 3m05s | ✗ 2m20s | `sha256:bbb…` | — | — |

3. Alertas:
   - **Divergencia de estado**: investigar el día que ocurra.
   - **Hash distinto con mismo commit**: build no reproducible — bloqueador para apagar Jenkins.
   - **Delta duración > +100%**: el target no está dimensionado.

## 5. Criterio de corte (ganador = GHA)

- 20 commits consecutivos con **mismo estado y mismo hash**.
- Equipo del pipeline da OK por escrito.
- Webhook de Jenkins para ese pipeline se desactiva.
- Jenkinsfile se mueve a `/legacy/` del repo (no se borra — útil para auditoría).

## 6. Qué miras durante dual-run (dashboards)

- Builds por hora (ambos lados).
- % de divergencia (debería tender a 0).
- Diferencia de duración p50 / p95.
- Fallos por lado y categoría ("flaky test", "secret missing", "network").

## 7. Preguntas de autocomprobación

1. En el `Jenkinsfile`, ¿qué cambia si quieres evitar el `withCredentials` y usar OIDC a AWS desde Jenkins? (Pista: hay un plugin, pero exige configurar un IAM provider que confíe en el controller — tangible pero no tan limpio como GHA).
2. Si el hash del wheel difiere entre Jenkins y GHA pero los tests pasan en ambos, ¿debes apagar Jenkins? Justifica.
3. ¿Cómo detectarías durante el dual-run que un pipeline tiene una **dependencia implícita** del `JENKINS_HOME` (p. ej. un cache local)? Pista: ejecútalo en un controller limpio.
4. En GHA, ¿qué pasa si `role-to-assume` apunta a un rol que confía en `main` pero el push viene de `feature/x`? ¿Dónde se controla el scope?
5. ¿Qué política de retention aplicarías a los artefactos del dual-run (ambos lados) para no inflar costes?
