# Ejemplo 02 — Agent multi-contenedor

> Un solo Pod, varios contenedores especializados. Workspace compartido vía `emptyDir`.

## 1. El Pod

```yaml
apiVersion: v1
kind: Pod
spec:
  restartPolicy: Never
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:3283.v92c105e0f819-9
    - name: maven
      image: maven:3.9-eclipse-temurin-21
      command: ["sleep"]
      args: ["infinity"]
      resources:
        requests: { cpu: "500m", memory: "1Gi" }
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ["sleep"]
      args: ["infinity"]
    - name: kubectl
      image: bitnami/kubectl:1.30
      command: ["sleep"]
      args: ["infinity"]
```

## 2. El Jenkinsfile

```groovy
pipeline {
  agent {
    kubernetes {
      yaml libraryResource('podTemplates/full-build.yaml')
    }
  }
  stages {
    stage('build-jar') {
      steps { container('maven') { sh 'mvn -B -DskipTests package' } }
    }
    stage('build-image') {
      steps {
        container('kaniko') {
          sh '''/kaniko/executor \
            --dockerfile=Dockerfile \
            --context=`pwd` \
            --destination=registry.local/app:${BUILD_NUMBER}'''
        }
      }
    }
    stage('deploy-dev') {
      steps {
        container('kubectl') {
          sh 'kubectl -n dev set image deploy/app app=registry.local/app:${BUILD_NUMBER}'
        }
      }
    }
  }
}
```

## 3. Lectura clave

1. **Workspace compartido**: lo que `maven` deja en `target/*.jar`, `kaniko` lo lee desde el mismo path. El plugin monta `emptyDir` en todos los contenedores en `/home/jenkins/agent/workspace/...`.
2. **Un Pod por build**: todas las stages corren en el mismo Pod. Si saltas a otro `agent`, pierdes el workspace (necesitarías `stash`/`unstash`).
3. **Separación de responsabilidades**: cada contenedor trae **solo** su herramienta. No más imágenes "swiss army knife" que mezclan JDK + Node + Docker + Terraform.
4. **Service account**: el contenedor `kubectl` necesita permisos para hacer `set image` en `namespace=dev`. Esos permisos se otorgan al **service account del Pod**, no al controller.

## 4. Anti-patrones

- Un contenedor único con `maven + docker + kubectl + awscli` instalados → imagen de 3 GB, pull lento, blast-radius enorme.
- Compartir el mismo service account con permisos amplios entre todos los pipelines → cualquier `Jenkinsfile` puede desplegar en prod.
- Usar `docker` dentro del Pod (DinD) con socket montado → antigua escuela, inseguro. Preferir `kaniko` o `buildkit` en modo rootless.
