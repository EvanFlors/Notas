# Lección — jk-05 — Agents distribuidos y Kubernetes plugin

> Builds distribuidos en Jenkins moderno. El controller coordina, los agents trabajan. En 2026 la variante dominante en entornos nuevos es el **agent efímero en Kubernetes**, y conviene entender por qué.

---

## 1. Modelo mental: controller + agents

Jenkins separa dos planos:

- **Controller** (histórico "master"): aloja la UI, el `JENKINS_HOME`, la cola de builds, la gestión de plugins, credenciales y RBAC. **No debe ejecutar builds** en producción.
- **Agents** (histórico "slaves"): nodos externos que ejecutan los *steps* del pipeline. Cada agent ofrece uno o varios **executors** (slots paralelos de ejecución).

El controller publica trabajo en una **cola**. Un agent se conecta al controller, dice "yo tengo capacidad y estos labels", el controller le entrega un build que haga match. El resultado (logs, artefactos, estado) vuelve al controller.

> **Regla de oro:** el día que el controller también corre builds, un `rm -rf` en un `sh` se come el `JENKINS_HOME`. En prod, controller **sin** executors (`executors = 0`).

---

## 2. Tipos de agent

### 2.1 Permanent

Un host (VM, bare-metal, incluso tu laptop) con un proceso agent corriendo todo el tiempo. Dos variantes de conexión:

- **SSH**: el controller se conecta al nodo por SSH y lanza el agent. Requiere clave SSH, red abierta en dirección controller → agent.
- **Inbound JNLP** ("JNLP4-connect"): el nodo se conecta al controller por una URL y un secret. Útil cuando el agent está detrás de NAT o firewall.

Pros: baja latencia (ya está encendido), útil para hardware específico (GPU, mac para iOS builds, licencias atadas a MAC address).

Contras: estado contaminado entre builds (workspace sucio, caches heredados), parcheo manual, "pet" en vez de "cattle".

### 2.2 Ephemeral — Docker on a host

Con **Docker Pipeline plugin** o `agent { docker { image '...' } }`, cada build arranca un contenedor en un host Docker, ejecuta los steps, y lo destruye. El workspace se monta como volumen temporal.

Pros: entorno limpio por build, imagen versionada, reproducible.

Contras: dependes de un pool de hosts Docker vivos; el *bin-packing* es manual; si pierdes el host, pierdes capacidad.

### 2.3 Ephemeral — Kubernetes plugin (recomendado hoy)

Cada build spawnea un **Pod** en un cluster Kubernetes. Dentro del Pod:

- Un contenedor `jnlp` (nombre convencional) que **habla con el controller** mediante JNLP4.
- Uno o varios contenedores con las herramientas de build (`maven`, `node`, `kaniko`, `terraform`, `python`...).

Cuando el build termina (éxito o fallo), el Pod se elimina. El `scheduler` de K8s hace el bin-packing; el `cluster-autoscaler` (si existe) añade nodos.

Pros: aisla por build, usa capacidad K8s existente, imagen por tool, escala horizontalmente.

Contras: cold-start de Pods (image pull, scheduling), controller necesita acceso al API server, debugging requiere entender K8s.

### 2.4 Cloud agents (EC2/GCE/Azure plugins)

VMs efímeras provisionadas por el plugin del proveedor cuando la cola crece. Útil si no tienes K8s pero sí cloud. Modelo híbrido en instalaciones legacy.

---

## 3. Nodes, labels y executors

- **Node**: representa un agent (o el controller, si tuviera executors).
- **Executor**: slot de ejecución. Un node con 4 executors corre hasta 4 builds en paralelo.
- **Label**: etiqueta libre asignada al node. Un pipeline pide `agent { label 'linux && docker' }` y solo nodes con **ambos** labels califican.

En el Kubernetes plugin, el `podTemplate` también declara un label; el pipeline lo pide por nombre. Si no existe un Pod activo con ese label, el plugin spawnea uno nuevo.

> **Anti-patrón**: labels tipo `node-15` (identidad). Los labels describen **capacidades** (`java17`, `arm64`, `has-docker`), no identidades.

---

## 4. Kubernetes plugin: anatomía

Instalación: `kubernetes` plugin desde Update Center. Configuración (JCasC o UI):

- **Kubernetes URL**: el API server del cluster. Si el controller corre dentro del cluster, se auto-detecta vía service account.
- **Jenkins URL**: cómo el Pod ve al controller (service DNS, `http://jenkins.jenkins.svc.cluster.local:8080`).
- **Jenkins tunnel**: puerto para la conexión JNLP (típicamente `jenkins-agent.jenkins.svc.cluster.local:50000`).
- **Namespace**: dónde se crean los Pods (recomendado: namespace dedicado `jenkins-agents`).
- **Service account**: identidad del Pod. Mínimo privilegio; nunca `cluster-admin`.
- **PodTemplates**: lista de plantillas globales, cada una con un `label` reclamable.

Cada build sigue este ciclo:

1. Pipeline declara `agent { kubernetes { yaml '...' } }`.
2. Plugin crea un Pod según el YAML.
3. Pod arranca; `jnlp` se conecta al controller con un secret pasado por env var.
4. Steps corren en los contenedores declarados (`container('maven') { sh 'mvn test' }`).
5. Build termina; plugin borra el Pod.

---

## 5. PodTemplate: inline vs global

### 5.1 Global (en la configuración del cloud)

Útil para plantillas estándar de la org (`maven-build`, `node-build`). Centraliza y versiona vía JCasC. El pipeline solo pide el label.

```groovy
pipeline {
  agent { label 'maven-build' }
  stages {
    stage('build') { steps { sh 'mvn -B package' } }
  }
}
```

### 5.2 Inline (en el Jenkinsfile)

El pipeline embebe el YAML completo. Útil cuando el equipo necesita control fino y el `podTemplate` es específico de un repo.

```groovy
pipeline {
  agent {
    kubernetes {
      yaml '''
        apiVersion: v1
        kind: Pod
        spec:
          containers:
            - name: maven
              image: maven:3.9-eclipse-temurin-21
              command: ["sleep"]
              args: ["infinity"]
      '''
    }
  }
  stages {
    stage('build') {
      steps {
        container('maven') { sh 'mvn -B package' }
      }
    }
  }
}
```

Reglas:

- **Siempre** declarar el contenedor `jnlp` explícitamente si quieres fijar su versión o recursos; si lo omites, el plugin lo inyecta con defaults.
- Cada contenedor de build debe tener `command: ["sleep"]` + `args: ["infinity"]` o similar. El plugin asume contenedores *long-running* a los que ejecutar comandos con `exec`.
- `container('name') { ... }` dirige los `sh` al contenedor nombrado. Fuera del bloque, el default es `jnlp`.

---

## 6. Multi-container agents

El patrón potente: un build que necesita `maven` para compilar, `kaniko` para construir una imagen OCI y `kubectl` para desplegar — todo en el mismo Pod, compartiendo workspace.

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: maven
      image: maven:3.9-eclipse-temurin-21
      command: ["sleep"]; args: ["infinity"]
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ["sleep"]; args: ["infinity"]
    - name: kubectl
      image: bitnami/kubectl:1.30
      command: ["sleep"]; args: ["infinity"]
```

Y en el pipeline:

```groovy
stage('build-jar')  { steps { container('maven')   { sh 'mvn -B -DskipTests package' } } }
stage('build-img')  { steps { container('kaniko')  { sh '/kaniko/executor ...' } } }
stage('deploy')     { steps { container('kubectl') { sh 'kubectl apply -f k8s/' } } }
```

El workspace (`/home/jenkins/agent/workspace/...`) es un `emptyDir` montado en todos los contenedores. Lo que el `mvn` deja en `target/`, el `kaniko` lo ve.

---

## 7. Comparación con ARC (GitHub Actions Runner Controller)

Mismo patrón arquitectónico, distinto plano de control:

| Dimensión | Jenkins + Kubernetes plugin | GitHub Actions + ARC |
|-----------|------------------------------|-----------------------|
| Control plane | Controller Jenkins (self-hosted) | GitHub.com (SaaS) o GHES |
| Agent plane | Pods efímeros | Pods efímeros |
| Config | JCasC + `podTemplate` | Helm chart + `RunnerScaleSet` |
| Escalado | Driven por cola Jenkins + plugin | Driven por webhook GitHub + ARC |
| Networking | Controller debe ver API server; Pod debe ver controller (JNLP) | Pod inicia pull desde GitHub (más fácil detrás de NAT) |
| Multi-tenant | Shared controller, labels | Shared GitHub, runner groups |
| Observabilidad | Prometheus plugin + logs | Métricas ARC + Actions logs |

Conclusión: si ya corres K8s **y** tus repos están en GitHub, ARC suele ser el camino nuevo. Jenkins + Kubernetes plugin sigue siendo la opción correcta en brownfield con pipelines complejos ya escritos y Shared Libraries maduras.

---

## 8. Cuándo preferir ephemeral (y cuándo no)

Preferir **ephemeral** cuando:

- La reproducibilidad importa (todos los equipos de prod lo necesitan).
- Hay riesgo de contamination (builds que escriben caches globales, Docker-in-Docker sucio).
- La carga es variable (horario laboral + picos de merge).
- Hay auditoría (cada build en un entorno fresco es un entorno auditable).

Mantener **permanent** cuando:

- Hardware específico atado al nodo (GPU, Mac para iOS, licencias por MAC).
- Cold-start inaceptable para builds muy cortos (< 30 s) y con imagen de 2 GB.
- No tienes K8s ni cloud, y añadir infra es más coste que beneficio.

---

## 9. Troubleshooting típico

| Síntoma | Causa probable | Mitigación |
|---------|----------------|------------|
| Pods *Pending* indefinidos | Node pool sin capacity, requests imposibles de satisfacer, `PodDisruptionBudget` bloqueando | Revisar `kubectl describe pod`, bajar requests, habilitar autoscaler |
| Build cuelga en "Waiting for agent" | `Jenkins URL` o `tunnel` mal configurado; red Pod → controller rota | Verificar DNS interno, probar `kubectl exec` + `nc` al tunnel |
| `jnlp` crashea al arrancar | Imagen `jnlp` incompatible con versión del controller | Pinnear `jenkins/inbound-agent` a versión conocida |
| Image pull lento → builds largos | Imagen enorme (2–5 GB), sin cache en nodo | Pre-pull en `DaemonSet`, usar registry regional, slim images |
| Workspace vacío en siguiente stage | Olvido de usar el mismo Pod (ephemeral se destruyó) | Mantener todas las stages del pipeline bajo el mismo `agent { kubernetes { ... } }` |
| Controller OOM | Demasiados Pods concurrentes, logs enormes en memoria | Limitar `global throttle`, aumentar heap, offload logs |

---

## 10. Criterios de elección: resumen operativo

- **Nuevo cluster K8s + repos modernos:** evalúa ARC primero. Si no cuaja (p.ej. no estás en GitHub), Jenkins + Kubernetes plugin.
- **Jenkins existente + K8s nuevo:** migra agents a Kubernetes plugin, deja controller como está. Ganancia inmediata en limpieza.
- **Jenkins existente + sin K8s:** Docker on host como paso intermedio. Introducir K8s solo si trae más valor que el coste operativo.
- **Hardware especial:** permanent agents con labels descriptivos (`gpu`, `macos-arm64`). Minoriza su número.

---

## 11. Checklist de verificación requerida en Fase 4

- Versión actual del `kubernetes` plugin y breaking changes recientes.
- Versión actual de `jenkins/inbound-agent` compatible con el LTS actual.
- Estado de **ARC** (Actions Runner Controller) oficial y su madurez para producción.
- Compatibilidad del Kubernetes plugin con `restricted` Pod Security Standard.
- Nuevas features del plugin: `inheritFrom`, `yamlMergeStrategy`, Pod retention post-fallo.
