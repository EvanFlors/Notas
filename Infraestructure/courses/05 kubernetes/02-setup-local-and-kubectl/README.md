# k8s-02 — Setup local y `kubectl`

## Identificación

- **ID:** `k8s-02-setup-local-and-kubectl`
- **Curso:** `kubernetes`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `k8s-01-mental-model-and-architecture`. Docker funcional en la máquina (`docker info` responde).

## Objetivo

Levantar un cluster local reproducible y manejar `kubectl` con precisión quirúrgica: contextos, namespaces, modos de output, y la diferencia operativa entre `apply`, `create` y `replace`. Al terminar deberías poder abrir un kubeconfig ajeno, entender qué habla con qué, y aplicar un manifiesto sabiendo exactamente qué va a mutar.

## Alcance

Este módulo cubre:

- Opciones de cluster local: **kind**, **k3d**, **minikube** — con recomendación explícita hacia **kind** o **k3d** por velocidad y realismo (ambos usan el API server real, no un simulador).
- Instalación de `kubectl`, `kind` / `k3d`, y los complementos `kubectx` / `kubens`.
- **kubeconfig** anatomizado: `clusters`, `users`, `contexts`, `current-context`, y cómo se autentica cada request.
- Namespaces como unidad lógica de aislamiento (no de seguridad por sí misma).
- Sintaxis de `kubectl`: `get`, `describe`, `apply`, `create`, `replace`, `delete`, `logs`, `exec`, `port-forward`, `explain`.
- Server-side apply vs client-side apply y por qué el primero es el futuro.
- Modos de output: `-o yaml`, `-o json`, `-o jsonpath`, `-o custom-columns`.

Lo que **no** cubre (se verá después):

- Pods y Deployments como workload → `k8s-03`.
- Services y DNS → `k8s-04`.
- RBAC y creación de usuarios reales → `k8s-12`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-kind-cluster/` — crear un cluster kind, verificar nodos, leer el kubeconfig que generó.
  - `02-kubectl-common-operations/` — paseo por `get/describe/logs/exec/port-forward` sobre un Pod real.
  - `03-explain-as-api-docs/` — usar `kubectl explain` como documentación en línea del API (`Deployment.spec.strategy`).
- **`activities/`**:
  - `01-create-local-cluster/` (guided-lab) — crear un cluster kind y validar que `kubectl` lo opera.
  - `02-kubeconfig-two-contexts/` (independent) — crear dos clusters, fusionar kubeconfigs, alternar contextos con disciplina.
- **`resources/links.md`** — documentación oficial y lecturas complementarias.

## Temas y subtemas

1. Opciones de cluster local
   - kind (Kubernetes-IN-Docker): nodos son contenedores Docker.
   - k3d: envuelve k3s en Docker; aún más ligero.
   - minikube: VM o Docker; mayor histórico, más lento.
   - Comparativa breve: tiempo de arranque, soporte multi-nodo, LoadBalancer local.
2. Instalación de herramientas
   - `kubectl` (binario cliente, versiones compatibles ±1 minor con el server).
   - `kind` / `k3d` (binario único).
   - `kubectx` / `kubens` (QoL para cambiar context/namespace).
3. kubeconfig
   - Estructura YAML: `clusters[]`, `users[]`, `contexts[]`, `current-context`.
   - Precedencia: `--kubeconfig` > `$KUBECONFIG` > `~/.kube/config`.
   - Multi-archivo con `KUBECONFIG=a:b:c` y `kubectl config view --merge --flatten`.
   - Autenticación: cert cliente, token bearer, OIDC, exec plugin (aws/gcloud).
4. Sintaxis de `kubectl`
   - Verbos CRUD: `get`, `create`, `apply`, `replace`, `patch`, `delete`.
   - Lectura: `describe`, `logs`, `events`.
   - Interactivos: `exec`, `attach`, `port-forward`, `cp`, `proxy`.
   - Diagnóstico: `explain`, `api-resources`, `api-versions`.
5. Namespaces
   - `kubectl -n`, `--all-namespaces`.
   - Recursos namespaced vs cluster-scoped.
6. Apply vs create vs replace
   - `create`: imperativo; falla si existe.
   - `replace`: reemplaza el objeto entero (debes traer todos los campos).
   - `apply`: declarativo; calcula un diff tri-vía con `last-applied-configuration` (client-side) o con managed fields (server-side).
   - Server-side apply: cada campo tiene un *field manager*; conflictos son explícitos.
7. Output
   - `-o yaml` / `-o json` para ver el objeto completo (incluye `status`).
   - `-o jsonpath='{.items[*].metadata.name}'` para scripting.
   - `-o custom-columns=NAME:.metadata.name,IMG:.spec.containers[*].image`.
   - `-o wide` como atajo humano.

## Conceptos internos (fundamentos)

- **`kubectl` no es mágico.** Es un cliente HTTP que arma peticiones REST contra el `kube-apiserver`. Carga el kubeconfig, resuelve `current-context`, construye credenciales, y hace `GET /api/v1/namespaces/default/pods`. Cuando algo "no funciona" casi siempre es un problema de kubeconfig, no del cluster.
- **La autenticación es del cliente, no del servidor.** El apiserver confía en lo que el cliente presenta: cert firmado por su CA, token con firma válida, o el stdout de un `exec` plugin (aws, gcloud, azure). Perder un kubeconfig con `client-key-data` es equivalente a perder una llave SSH privada.
- **`kubectl explain` es el manual del API.** No lee documentación externa; lee el OpenAPI schema que el apiserver publica en `/openapi/v3`. Por eso siempre está sincronizado con la versión real del cluster, aunque uses CRDs custom.
- **`apply` es idempotente porque preserva campos no gestionados.** Si un controller añade `status`, el próximo `apply` no lo pisa. Si un operador añade un annotation, tu `apply` lo respeta mientras tú no lo declares. Server-side apply formaliza esto con *field managers*: cada campo del objeto recuerda quién lo escribió por última vez.
- **`kubectl port-forward` NO abre un puerto en el nodo.** Abre un túnel SPDY desde tu máquina al apiserver, y de ahí al kubelet del nodo, y de ahí a un socket dentro del Pod. Si el apiserver cae, tu port-forward cae. Es solo para desarrollo.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar cómo `kubectl` autentica una request, por qué `apply` preserva campos no gestionados, y qué diferencia hay entre server-side y client-side apply. |
| Operativa | Crear y destruir un cluster kind; alternar entre dos contextos sin confundirse; extraer campos con `jsonpath` y `custom-columns`; usar `explain` en lugar de buscar en Google. |
| Arquitectónica | Decidir entre kind / k3d / minikube para un escenario dado; justificar por qué el kubeconfig es una credencial sensible y no un archivo de configuración. |

## Entregables

- Un cluster local kind funcional (`kubectl get nodes` responde Ready).
- Un kubeconfig con **al menos 2 contextos** (dos clusters kind), con `kubectl config get-contexts` mostrándolos.
- Los `tests/validate.sh` de las dos actividades deben pasar.

## Criterios de evaluación

- **Diferencia `apply` vs `create` vs `replace`**: explicarla con un ejemplo donde cada verbo tenga consecuencias distintas sobre el mismo recurso.
- **Disciplina de contextos**: nunca "¿en qué cluster estoy?" — el prompt o el hábito te lo dice.
- **Lectura de kubeconfig**: dado un archivo ajeno, poder decir qué clusters contacta, con qué credenciales, y qué context usa por defecto.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Instala `kubectl` y `kind` (sección 2 de la lección).
3. Reproduce `examples/01-kind-cluster/`.
4. Haz `activities/01-create-local-cluster/`.
5. Reproduce `examples/02-kubectl-common-operations/` y `examples/03-explain-as-api-docs/`.
6. Haz `activities/02-kubeconfig-two-contexts/`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `k8s-03-pods-deployments-replicasets`: dejamos de solo mirar y empezamos a desplegar workloads reales.
