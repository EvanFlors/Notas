# Ejemplo 01 — `podTemplate` mínimo del Kubernetes plugin

> Lectura y análisis. Objetivo: fijar la **forma mínima** de un Pod ejecutor y qué papel cumple cada contenedor.

## 1. El Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins-agent: "true"
spec:
  restartPolicy: Never
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:3283.v92c105e0f819-9
      resources:
        requests: { cpu: "100m", memory: "256Mi" }
        limits:   { cpu: "500m", memory: "512Mi" }
    - name: build
      image: maven:3.9-eclipse-temurin-21
      command: ["sleep"]
      args: ["infinity"]
      resources:
        requests: { cpu: "500m", memory: "1Gi" }
        limits:   { cpu: "2",    memory: "2Gi" }
```

## 2. El Jenkinsfile que lo consume

```groovy
pipeline {
  agent {
    kubernetes {
      yaml libraryResource('podTemplates/maven.yaml')
    }
  }
  stages {
    stage('build') {
      steps {
        container('build') {
          sh 'mvn -B -DskipTests package'
        }
      }
    }
  }
}
```

## 3. Lectura clave

1. **`jnlp` siempre**. Si no lo declaras, el plugin lo inyecta con defaults; declararlo te da control sobre versión y recursos.
2. **`sleep infinity`** en el contenedor de build. El plugin ejecuta comandos con `kubectl exec`-equivalente; necesita que el contenedor siga vivo.
3. **`container('build')`** redirige los `sh` al contenedor nombrado. Fuera del bloque, los comandos van al `jnlp`.
4. **`restartPolicy: Never`**. Un fallo del Pod no se reintenta a nivel K8s; Jenkins gestiona el retry a nivel pipeline.
5. **Requests y limits**. Sin requests, el `scheduler` adivina; sin limits, un `mvn` loco puede comerse el nodo.

## 4. Trampas comunes

- Olvidar `command/args` → el contenedor se cierra inmediatamente y el stage falla con "Container ... not running".
- Fijar la imagen `jnlp` a una versión incompatible con el controller → el agent no se conecta nunca.
- Montar un secret con permisos amplios → agent efímero con `cluster-admin` es tan peligroso como un controller comprometido.
