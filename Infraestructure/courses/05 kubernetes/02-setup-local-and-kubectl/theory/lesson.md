# k8s-02 — Lección: Setup local y `kubectl`

> Lección profunda del módulo. Léela antes de tocar comandos.

## 1. Por qué un cluster local importa

Podrías aprender Kubernetes contra EKS o GKE desde el día uno. **No lo hagas.** Un cluster local tiene tres ventajas que un managed no te da:

- **Iteración rápida.** Levantar y destruir en < 60 s. Equivocarte sale gratis.
- **Visibilidad total.** El API server, etcd, el scheduler y el controller-manager corren como procesos (o contenedores) a los que puedes `exec`, mirar logs y hasta trazar llamadas. En EKS el control plane es una caja negra.
- **Sin AWS/GCP en el camino.** Cuando algo no funciona, no tienes que distinguir "¿es K8s? ¿es IAM? ¿es la VPC?". Si falla en kind, falla en K8s.

El cluster local no reemplaza a producción, pero es donde **se forma el modelo mental** que luego aplicas a managed. Un ingeniero que opera managed sin haber roto y reparado un cluster local nunca entiende qué está pasando "dentro".

## 2. Opciones de cluster local

### kind — Kubernetes IN Docker (recomendado)

- Cada "nodo" del cluster es un contenedor Docker que corre `kubelet`, `kube-proxy`, un containerd anidado y los componentes del control plane.
- Arranca en 20–40 s. Multi-nodo nativo (`--config` con lista de nodos).
- Mantenido por el proyecto Kubernetes mismo. Es lo que usa el *release testing* oficial.
- Instalación: `brew install kind` (macOS), `go install sigs.k8s.io/kind@latest`, o binario precompilado.

### k3d — k3s en Docker

- Envuelve **k3s** (distribución ligera de Rancher) en contenedores Docker.
- Más rápido aún que kind (~15 s). Soporte nativo para LoadBalancer local vía ServiceLB.
- Trade-off: k3s es un sabor minimalista — reemplaza etcd por SQLite por default, embute varios controllers en un solo binario. Es K8s conformant, pero **no es exactamente lo mismo**. Para aprender fundamentos puros, kind es más fiel al estándar.
- Instalación: `brew install k3d`.

### minikube

- El veterano. Soporta VM (hyperkit, virtualbox, hyperv) o driver docker.
- Más lento al arrancar (1–3 min) y más pesado.
- Hoy se usa principalmente para probar features específicas que requieren un driver particular o un addon preempaquetado.

### Recomendación operativa

Para este curso: **kind**. Para experimentar con GitOps y LoadBalancer locales: **k3d**. Minikube solo si tienes un motivo concreto.

## 3. Instalación

### `kubectl`

Es un binario Go estático. Las opciones:

```bash
# macOS
brew install kubectl

# Linux (binario oficial)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Windows
choco install kubernetes-cli
```

**Regla de compatibilidad**: `kubectl` soporta un cluster hasta ±1 minor version. Un `kubectl 1.30` habla bien con clusters 1.29, 1.30, 1.31. Más allá puede fallar en campos nuevos.

### `kind`

```bash
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
```

### `kubectx` / `kubens` (opcional pero recomendado)

Dos scripts que te dan `kubectx` para cambiar contexto y `kubens` para cambiar namespace, con autocompletado y menú interactivo (`fzf` si está instalado).

```bash
brew install kubectx       # macOS, incluye kubens
```

Alternativa pura: aliases.

```bash
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'
```

### Verificación

```bash
kubectl version --client     # debería imprimir la versión
kind version                 # idem
docker info >/dev/null       # kind necesita Docker vivo
```

## 4. Anatomía del kubeconfig

Un **kubeconfig** es un YAML que `kubectl` lee para saber a qué cluster hablar, con qué credencial, y en qué namespace por default. Es, literalmente, el único estado que `kubectl` tiene en disco.

Ubicación por default: `~/.kube/config`. Precedencia:

1. `--kubeconfig <file>` en la línea de comandos (gana).
2. `$KUBECONFIG` (puede ser `a:b:c` — una lista; se fusionan en memoria).
3. `~/.kube/config`.

Estructura:

```yaml
apiVersion: v1
kind: Config
current-context: kind-dev     # cuál usar si no pasas --context

clusters:
  - name: kind-dev
    cluster:
      server: https://127.0.0.1:63421
      certificate-authority-data: LS0tLS1CRUdJTi...   # CA que firma el cert del server

users:
  - name: kind-dev
    user:
      client-certificate-data: LS0tLS1CRUdJTi...     # mi cert
      client-key-data: LS0tLS1CRUdJTi...             # mi llave privada

contexts:
  - name: kind-dev
    context:
      cluster: kind-dev
      user: kind-dev
      namespace: default
```

Tres listas (`clusters`, `users`, `contexts`) y un puntero (`current-context`). Un **contexto es una tripleta** `(cluster, user, namespace)` con un nombre. Esto es poderoso: un mismo cluster, dos usuarios distintos (admin / viewer), dos namespaces → cuatro contextos sobre dos entradas de `clusters` y dos de `users`.

### Fusión de archivos

```bash
export KUBECONFIG=~/.kube/config:~/.kube/eks.yaml:~/.kube/gke.yaml
kubectl config view --merge --flatten > ~/.kube/config.merged
```

**Precaución**: si dos archivos tienen un contexto con el mismo nombre, el primero gana silenciosamente. Renombra antes.

### Autenticación: cómo se demuestra la identidad

Opciones comunes en el `users[].user`:

- **Cert cliente** (`client-certificate-data` + `client-key-data`) — así funciona kind. El apiserver confía en certs firmados por su CA; el CN del cert es el username, el Organization es el grupo.
- **Token bearer** (`token:`) — un string opaco; el apiserver lo valida contra ServiceAccounts, OIDC o un webhook.
- **Exec plugin** (`exec: command: aws`) — kubectl ejecuta un comando externo que imprime un token válido. Así es como EKS (`aws eks get-token`) y GKE (`gke-gcloud-auth-plugin`) funcionan hoy.

**Un kubeconfig con credenciales embebidas es una llave.** Trátalo como una SSH private key: `chmod 600`, nunca en git, nunca en un canal público.

## 5. Namespaces

Un **namespace** es una partición lógica del API. No es un sandbox de seguridad por sí mismo (sin NetworkPolicy + RBAC los Pods de dos namespaces se ven y se hablan).

- Por default: `default`, `kube-system` (control plane), `kube-public` (lectura anónima), `kube-node-lease` (heartbeats de nodos).
- Recursos **namespaced**: Pods, Deployments, Services, ConfigMaps, Secrets, PVCs, etc.
- Recursos **cluster-scoped**: Nodes, PersistentVolumes, StorageClasses, ClusterRoles, Namespaces mismos.

```bash
kubectl get pods                    # namespace actual
kubectl get pods -n kube-system     # otro
kubectl get pods -A                 # --all-namespaces
kubectl api-resources --namespaced=true | head
```

Cambiar el namespace por default del contexto:

```bash
kubectl config set-context --current --namespace=mi-app
# o
kubens mi-app
```

## 6. Sintaxis general de `kubectl`

```
kubectl [verb] [resource] [name] [flags]
```

- **verb**: `get`, `describe`, `create`, `apply`, `delete`, `patch`, `replace`, `logs`, `exec`, `port-forward`, `explain`, `rollout`, `scale`, `wait`, `label`, `annotate`, `cp`, `proxy`, `top`, `debug`.
- **resource**: singular (`pod`), plural (`pods`), abreviatura (`po`, `deploy`, `svc`, `ns`, `cm`, `sa`). Lista completa: `kubectl api-resources`.
- **name**: opcional; si falta en `get`, lista todos.

Ejemplos:

```bash
kubectl get pods
kubectl get po -o wide                       # añade IP y nodo
kubectl describe pod web-xyz
kubectl logs web-xyz
kubectl logs web-xyz -c mi-contenedor        # multi-contenedor
kubectl logs -f --tail=50 web-xyz            # follow
kubectl exec -it web-xyz -- sh               # proceso adicional
kubectl port-forward pod/web-xyz 8080:80     # túnel local
kubectl delete pod web-xyz                   # borra (y se recrea si hay Deployment)
```

## 7. Create vs apply vs replace

Tres verbos que modifican, con consecuencias muy distintas.

### `create` — imperativo

```bash
kubectl create deployment nginx --image=nginx:alpine
# o desde archivo:
kubectl create -f deploy.yaml
```

- Falla con `AlreadyExists` si el objeto ya está.
- No deja rastro de "qué pediste tú" — no hay `last-applied-configuration`.

### `replace` — reemplazo total

```bash
kubectl replace -f deploy.yaml
```

- Falla si NO existe (hay `--force` que lo convierte en delete+create).
- El YAML debe ser **completo**: cualquier campo que omitas se pierde (incluso defaults que el server había añadido).

### `apply` — declarativo, idempotente

```bash
kubectl apply -f deploy.yaml
```

- Crea si no existe, actualiza si existe.
- Preserva campos no gestionados: lo que el controller o un operador haya añadido no se borra.
- **Cómo**:
  - **Client-side apply** (histórico): kubectl guarda tu YAML en el annotation `kubectl.kubernetes.io/last-applied-configuration`. En el siguiente apply calcula un diff tri-vía: `last-applied` ↔ `actual-del-server` ↔ `nuevo-yaml`. Genera un strategic merge patch y lo envía como `PATCH`.
  - **Server-side apply** (`--server-side`, estable desde 1.22): el apiserver mantiene *managed fields* por `fieldManager`. Cada campo recuerda quién lo escribió. Si dos managers escriben el mismo campo → **conflicto explícito**. Mucho más seguro para automatización (GitOps, operadores).

### Resumen operativo

| Caso | Verbo |
|------|-------|
| Script "quick, no me importa", one-shot. | `create` |
| GitOps / archivo fuente de verdad. | `apply` (preferible `--server-side`) |
| Nunca, salvo que entiendas por qué. | `replace` |

## 8. Modos de output

```bash
kubectl get pods -o yaml                              # YAML completo (incluye status)
kubectl get pods -o json                              # idem en JSON
kubectl get pods -o wide                              # tabla + IP + nodo
kubectl get pods -o name                              # solo "pod/web-xyz"
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
kubectl get pods -o custom-columns=NAME:.metadata.name,IMG:.spec.containers[*].image
```

Scripting serio: `jsonpath` o `-o json | jq`. Humano: `-o wide` + `describe`.

## 9. `kubectl explain` — el manual del API

```bash
kubectl explain pod
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
kubectl explain deployment.spec.strategy.rollingUpdate.maxSurge
kubectl explain pod --recursive | head -40
```

Esto NO lee docs externas. El apiserver publica su OpenAPI schema en `/openapi/v3`; `kubectl explain` lo consulta y formatea. **Siempre está sincronizado con tu cluster**: si tienes CRDs instaladas, también funciona sobre ellas (`kubectl explain certificate.spec` si tienes cert-manager).

Regla: antes de buscar en Google el nombre de un campo, prueba `kubectl explain`.

## 10. port-forward, logs, exec — qué pasa por debajo

### `kubectl logs <pod>`

- `GET /api/v1/namespaces/.../pods/.../log` al apiserver.
- El apiserver proxea al `kubelet` del nodo donde corre el Pod.
- El `kubelet` lee del logging driver del container runtime (containerd suele escribir a `/var/log/pods/...`).
- **Si el Pod ya no existe pero el apiserver mantiene registro**: `logs --previous` para el contenedor anterior tras un restart.

### `kubectl exec -it <pod> -- sh`

- Abre un stream SPDY/websocket contra el apiserver.
- El apiserver proxea al kubelet, que llama al CRI (`containerd`) para hacer `exec` dentro de los namespaces del contenedor.
- No es SSH. No hay demonio sshd. Es el runtime quien lanza el proceso.

### `kubectl port-forward pod/<p> 8080:80`

- Stream SPDY: tu kubectl ↔ apiserver ↔ kubelet ↔ socket interno del Pod.
- El puerto 8080 se abre **en tu máquina**, en 127.0.0.1 por default. No hay puerto en el nodo ni en el cluster.
- Si el apiserver se corta, el forward se corta.
- Para desarrollo / debugging. Para producción: Service + Ingress.

## 11. Errores comunes y cómo diagnosticarlos

| Síntoma | Causa típica |
|---------|--------------|
| `error: You must be logged in to the server (Unauthorized)` | Credencial expirada (token OIDC caduco; `aws eks update-kubeconfig` requerido). |
| `Unable to connect to the server: dial tcp ...: connect: connection refused` | El cluster no está corriendo (apagaste kind) o el kubeconfig apunta a un endpoint equivocado. |
| `error: context "foo" does not exist` | Fusionaste kubeconfigs mal o borraste el contexto. `kubectl config get-contexts`. |
| `the server could not find the requested resource` | Resource name mal escrito, o la CRD no está instalada, o estás usando una `apiVersion` incorrecta. `kubectl api-resources | grep -i foo`. |
| `exec plugin ... not found` | kubeconfig espera `aws`/`gke-gcloud-auth-plugin` y no está en PATH. |

**Regla heurística**: si `kubectl` se comporta raro, el 80 % de las veces es kubeconfig. Mira `kubectl config view --minify` (muestra solo el contexto actual).

## 12. Checklist y preguntas de autoevaluación

Antes de pasar al módulo siguiente, deberías poder responder sin consultar:

1. ¿Qué contiene exactamente un kubeconfig y qué secuencia sigue `kubectl` para decidir contra qué apiserver habla?
2. ¿Por qué perder un kubeconfig con `client-key-data` es equivalente a perder una llave SSH privada?
3. Dado un `deploy.yaml`, ¿qué pasa diferente al correr `create`, `apply` y `replace`? ¿Qué queda en el server tras cada uno?
4. ¿Qué diferencia hay entre client-side apply y server-side apply? ¿Qué resuelve el segundo?
5. ¿Cómo verifica el apiserver que un `kubectl explain` sobre una CRD está sincronizado con la versión instalada?
6. ¿Qué sucede físicamente cuando corres `kubectl exec -it pod/x -- sh`? ¿Qué proceso termina ejecutando `sh` y en qué namespaces?
7. ¿Por qué `kubectl port-forward` no es un reemplazo de un Service para producción?

Si alguna te duda, releer la sección correspondiente antes de abordar `k8s-03`.
