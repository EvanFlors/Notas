# Actividad 01 — Ejecutar un pipeline en un agent efímero de Kubernetes

## 1. Identificación

- **ID:** `jk-05-01-run-pipeline-on-k8s-agent`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-05-agents-distributed-builds-kubernetes-plugin`
- **Dificultad:** intermediate
- **Duración estimada:** 70–90 min
- **Tipo:** guided-lab (independiente respecto a la actividad 02)

## 2. Contexto

Tu equipo opera un cluster Kubernetes y acaba de migrar los agents de Jenkins de **permanent SSH** a **ephemeral Pods**. El Platform team te pide un `podTemplate` reutilizable y un `Jenkinsfile` que lo consuma, para que el resto de los repos lo tomen como plantilla.

Tu encargo: escribir `podTemplate.yaml` (al menos `jnlp` + un contenedor de build) y un `Jenkinsfile` declarative que lo use con `agent { kubernetes { ... } }` + `container('build') { sh '...' }`. Opcionalmente, levantar un `kind` local y probar el ciclo completo.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `podTemplate.yaml` válido con `jnlp` y al menos un contenedor de build.
- Escribir un `Jenkinsfile` declarative que lo consume vía `agent { kubernetes { yaml ... } }`.
- Dirigir cada `sh` al contenedor correcto con `container('name') { ... }`.
- Dimensionar `requests`/`limits` razonables.
- Justificar `restartPolicy: Never` y `command: ["sleep"] / args: ["infinity"]`.

## 4. Prerrequisitos

- `jk-02` completo (Jenkins corriendo y un pipeline hello-world funcional).
- Curso **kubernetes** ≥ Nivel 2 (Pod, container, resources, service account).
- Herramientas: `bash`, `python3` (para validar el YAML; se usa `python3 -c 'import yaml'`), opcionalmente `kind` y `kubectl` para el lab vivo.

**Costos**: ninguno. Lab local sobre `kind` o solo validación estructural.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-05-k8s-agent
cd /tmp/jk-05-k8s-agent
```

Puedes usar otro directorio; pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `podTemplate.yaml`

Contenido mínimo que el validador exige:

- `apiVersion: v1` y `kind: Pod`.
- `spec.restartPolicy: Never`.
- `spec.containers` con **al menos dos** entradas.
- Un contenedor **llamado exactamente `jnlp`** con imagen `jenkins/inbound-agent:*`.
- Al menos **otro contenedor** (p. ej. `build`, `maven`, `node`, `kaniko`) con:
  - `command: ["sleep"]` y `args: ["infinity"]` (o `cat` / `tail -f /dev/null` equivalentes long-running).
  - `resources.requests` y `resources.limits` ambos presentes.

Ejemplo guía (puedes partir de este o reescribir):

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

### 5.3 Escribe `Jenkinsfile`

Contenido mínimo que el validador exige:

- Bloque `pipeline { ... }`.
- `agent { kubernetes { yaml ... } }` (puede ser `yamlFile 'podTemplate.yaml'` o `yaml '''...'''` inline).
- Al menos una `stage { ... }` dentro de `stages { ... }`.
- Al menos un `container('name') { sh '...' }` que apunte al contenedor de build que declaraste.

Ejemplo guía:

```groovy
pipeline {
  agent {
    kubernetes {
      yamlFile 'podTemplate.yaml'
    }
  }
  stages {
    stage('build') {
      steps {
        container('build') {
          sh 'echo "running inside the build container"'
          sh 'mvn --version || true'
        }
      }
    }
  }
}
```

### 5.4 (Opcional) Lab vivo en `kind`

Si tienes `kind` y `kubectl` instalados, puedes levantar un cluster para probar el ciclo end-to-end. El validador **no** exige esta parte; si `kind` falta, la salta con `SKIP`.

```bash
# Levantar cluster
kind create cluster --name jk05

# Instalar Jenkins (helm chart) — fuera del alcance obligatorio;
# ver docs/README.md para la receta completa.
```

### 5.5 Entregables

```
/tmp/jk-05-k8s-agent/
├── podTemplate.yaml
└── Jenkinsfile
```

## 6. Resultado esperado

- Los dos archivos existen y pasan validación estructural.
- Un ingeniero externo puede leer el par y entender qué Pod se crea y dónde corre cada paso.
- Opcional: pipeline arrancado en `kind` muestra el Pod efímero creado y destruido.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada contenedor tiene un propósito claro; recursos dimensionados; `jnlp` presente.
- **Reproducibilidad**: el `Jenkinsfile` referencia el `podTemplate.yaml` por path o lo incluye inline.
- **Mantenibilidad**: YAML válido, Groovy válido, nombres de contenedor consistentes entre YAML y pipeline.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-05-k8s-agent
```

El validador comprueba estructura (parsing + presencia de claves y patrones). La ejecución real en `kind` es opcional; si `kind` no está instalado, se emite `SKIP` y no falla.

## 9. Preguntas de reflexión

1. ¿Por qué el contenedor de build necesita `sleep infinity`? ¿Qué pasa si lo omites?
2. ¿Por qué `restartPolicy: Never` y no `OnFailure`?
3. Si el `jnlp` del YAML queda fijado a una versión y el controller se actualiza, ¿qué puede fallar?
4. ¿Qué `label` descriptivo le pondrías a este `podTemplate` para pedirlo desde otros pipelines?
5. ¿Cómo evitarías que un pipeline malicioso use un `podTemplate` con permisos amplios en el cluster?

## 10. Extensiones

- Añade un segundo contenedor (`kaniko` o `kubectl`) y una stage por contenedor.
- Convierte el `podTemplate.yaml` en un `libraryResource` de una Shared Library.
- Añade `securityContext` restrictivo (`runAsNonRoot: true`, `readOnlyRootFilesystem: true` cuando sea posible).

## 11. Limpieza

```bash
rm -rf /tmp/jk-05-k8s-agent
# Si levantaste kind:
kind delete cluster --name jk05
```
