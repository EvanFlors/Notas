# Lección: Pods, ReplicaSets y Deployments

> **ID:** `k8s-03-pods-deployments-replicasets` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `k8s-02-setup-local-and-kubectl`.

---

## 1. Introducción intuitiva

En `k8s-02` creaste un cluster local y aprendiste `kubectl`. Ahora toca correr algo útil encima. La pregunta ingenua es: "¿cómo arranco un contenedor en Kubernetes?". La respuesta larga —la que importa— es que en K8s **nunca se arranca un contenedor** directamente. Se declara el **estado deseado** de un workload y un controller lo mantiene. Para una API web típica, ese "workload" se declara con un **Deployment**.

El modelo tiene tres niveles encadenados:

```
Deployment  ──gestiona──▶  ReplicaSet  ──crea──▶  Pod  ──contiene──▶  Container(s)
```

El **Pod** es la unidad de scheduling: uno o más contenedores pegados que comparten red (misma IP, mismos puertos) y volúmenes. El **ReplicaSet** mantiene N copias de un Pod template. El **Deployment** gestiona ReplicaSets para permitir **actualizaciones graduales con rollback**. Este módulo entra en los tres y en el pegamento que los une: **labels**.

Si al final del módulo entiendes por qué una actualización crea *dos* ReplicaSets conviviendo durante unos segundos, y por qué `kubectl rollout undo` funciona sin tener que reconstruir nada, ya tienes el modelo mental de los workloads sin estado en K8s.

---

## 2. Fundamentos

### 2.1 Qué es un Pod (y qué no)

Un Pod es **un grupo de uno o más contenedores que comparten**:

- El mismo **network namespace** (misma IP del Pod, mismos puertos).
- Los mismos **volúmenes** (declarados a nivel de Pod, montados por cada container).
- El mismo ciclo de vida de scheduling: o todos van al nodo A, o ninguno.

Un Pod **no** es "un contenedor envuelto". Puedes meter varios contenedores que colaboran estrechamente (app + log shipper, app + proxy, app + migrator). La regla práctica: si los dos procesos tendrían que escalar por separado o fallar por separado, no van en el mismo Pod — van en Pods distintos.

### 2.2 Por qué un Pod bare no es la respuesta

Un Pod creado con `kubectl apply -f pod.yaml`:

- **No se reprograma** si su nodo muere. Desaparece.
- **No se auto-reemplaza** si crashea con `restartPolicy: Never`. Queda en estado `Failed`.
- **No tiene réplicas**. Si quieres 3, haces 3 YAMLs. Si quieres 10, haces 10.
- **No tiene revisiones**. Si cambias la imagen, borras y recreas; durante ese tiempo no hay nada corriendo.

Por eso en producción casi nadie crea Pods directamente. Se crean a través de **controllers** (Deployment, StatefulSet, DaemonSet, Job) que mantienen Pods como su "output".

### 2.3 ReplicaSet y Deployment

- **ReplicaSet (RS)** mantiene N Pods vivos según un template. Si borras uno, crea otro. Es el controller "de réplicas".
- **Deployment** gestiona ReplicaSets. Cada vez que cambias el template del Deployment, crea un **nuevo RS** y escala viejo→nuevo según una estrategia. Guarda los RS viejos (hasta `revisionHistoryLimit`) para poder revertir.

Rara vez escribes un ReplicaSet a mano; casi siempre usas Deployment y K8s crea el RS por ti.

---

## 3. Contexto histórico

- **2014–2015** — Kubernetes 1.0: existía ReplicationController (abuelo del ReplicaSet) y Pod. No había Deployment; actualizar un servicio requería scripts externos o `kubectl rolling-update` (deprecado en 2016).
- **2016** — Se introduce **Deployment** (`apps/v1beta1`) para orquestar rolling updates como objeto declarativo.
- **2017** — ReplicaSet reemplaza a ReplicationController (soporta selectores set-based). Deployment usa ReplicaSets como backing.
- **2018** — `apps/v1` GA. Deployment, ReplicaSet, StatefulSet, DaemonSet consolidados.
- **2019** — `kubectl rollout undo --to-revision=N` estable y usable sin flags experimentales.
- **2021–2023** — Se abandona el flag `--record` (deprecado) para marcar causa de cambio; se promueve la anotación `kubernetes.io/change-cause` explícita.
- **2024** — Se estabilizan los **sidecar containers nativos** (initContainer con `restartPolicy: Always`): corren en paralelo al main pero con lifecycle de init (arrancan antes, terminan después, Jobs los ignoran para "completion"). Reemplazo moderno del patrón sidecar clásico.

---

## 4. Funcionamiento interno

### 4.1 Qué pasa cuando aplicas un Deployment

```
kubectl apply -f deployment.yaml
       │
       ▼
kube-apiserver (authn/authz → mutating → validating → persist en etcd)
       │
       ▼
Deployment controller (en kube-controller-manager)
   - Ve nuevo Deployment en etcd.
   - Crea un ReplicaSet con hash en el nombre: nginx-7c9f8b6d5
   - Marca el RS con las labels del template.
       │
       ▼
ReplicaSet controller
   - Ve nuevo RS con replicas=3.
   - Crea 3 Pod objects (sin nodo asignado).
       │
       ▼
kube-scheduler
   - Ve 3 Pods sin nodeName.
   - Asigna cada uno a un nodo (filter + score).
       │
       ▼
kubelet (en cada nodo elegido)
   - Ve "su" Pod en la API.
   - Pide a containerd que haga pull de la imagen y arranque el contenedor.
   - Reporta Status de vuelta al API.
```

Nadie "manda" al kubelet un Pod. El kubelet lo descubre consultando al apiserver. Esto es el **reconciliation loop**: cada controller lee `spec` + estado observado y actúa para converger.

### 4.2 Qué pasa en un rolling update

Cambias `image: myapp:v2`. El Deployment controller:

1. Crea un **nuevo RS** `myapp-xxxxxx-v2` con `replicas: 0`.
2. Lo escala **+maxSurge** (default: 25% hacia arriba del `replicas`). Si `replicas: 10` y `maxSurge: 25%`, arranca 3 Pods nuevos (puede haber 13 Pods a la vez momentáneamente).
3. Cuando esos Pods están **Ready**, escala el **RS viejo** `-maxUnavailable` (default 25% hacia abajo). Baja 3 Pods viejos.
4. Repite hasta que el RS nuevo tenga `replicas: 10` y el viejo `replicas: 0`.
5. El RS viejo **permanece** con replicas=0 para poder revertir (hasta `revisionHistoryLimit`, default 10).

Durante todo el proceso se respetan dos invariantes simultáneos:

- Total Pods ≤ `replicas + maxSurge`.
- Pods **disponibles** ≥ `replicas - maxUnavailable`.

"Disponible" = Pod en estado Ready por al menos `minReadySeconds` segundos (default 0). Sin readiness probe, un Pod se cuenta como Ready en cuanto el contenedor arranca — lo cual puede ser engañoso. Las probes a fondo en `k8s-10`.

### 4.3 Labels y selectors: el contrato

Un Deployment tiene un `selector.matchLabels`. El `template.metadata.labels` del Pod debe coincidir (o incluir) ese selector. Cuando el Deployment controller lista "mis Pods", busca por `selector`. Un Service hará lo mismo para enrutarles tráfico.

**Regla operativa**: nunca cambies `selector` de un Deployment existente. Es inmutable en `apps/v1` por diseño: cambiarlo "huerfanaría" los Pods existentes (quedarían sin dueño) y crearía otros nuevos. Si necesitas cambiar selector, borra y recrea el Deployment.

### 4.4 Sidecar nativo vs sidecar clásico

Antes de 2024, un "sidecar" era un segundo container normal en el mismo Pod. Problemas:

- En un `Job`, si el sidecar nunca termina, el Job nunca completa.
- En shutdown, los containers se terminan "en paralelo"; un log-shipper sidecar podía morir *antes* que el app, perdiendo los últimos logs.
- No había orden garantizado al arrancar.

Un **sidecar nativo** es un `initContainer` con `restartPolicy: Always`. El kubelet:

- Lo arranca **antes** de los containers normales (orden de init garantizado).
- Lo mantiene vivo durante toda la vida del Pod (reinicia si crashea).
- Lo termina **después** de que los normales ya salieron (shutdown ordenado).
- En un Job, lo ignora para calcular "completion" (el Job termina cuando los containers normales terminan).

Ejemplo mínimo (log shipper):

```yaml
spec:
  initContainers:
    - name: log-shipper
      image: fluent/fluent-bit:3.1
      restartPolicy: Always       # ← esto lo convierte en sidecar nativo
      volumeMounts:
        - { name: logs, mountPath: /var/log/app }
  containers:
    - name: app
      image: myapp:1.0
      volumeMounts:
        - { name: logs, mountPath: /var/log/app }
  volumes:
    - name: logs
      emptyDir: {}
```

---

## 5. Ejemplo mínimo

El Deployment más chico útil, con las piezas comentadas:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello                                 # nombre del Deployment
  labels:
    app: hello                                # labels del propio objeto Deployment
spec:
  replicas: 3                                 # cuántos Pods queremos
  revisionHistoryLimit: 5                     # cuántos RS viejos conservar para rollback
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1                             # 1 Pod extra como máximo durante el rollout
      maxUnavailable: 0                       # 0 Pods caídos durante el rollout (más seguro, más lento)
  selector:
    matchLabels:
      app: hello                              # qué Pods son "míos"
  template:                                   # ← plantilla de los Pods
    metadata:
      labels:
        app: hello                            # DEBE incluir las del selector
    spec:
      containers:
        - name: web
          image: nginxdemos/hello:plain-text
          ports:
            - containerPort: 80
```

Despliegue y verificación:

```bash
kubectl apply -f hello.yaml
kubectl rollout status deployment/hello     # bloquea hasta terminar
kubectl get deploy,rs,pods -l app=hello
```

Deberías ver:

- 1 Deployment `hello` con `3/3` ready.
- 1 ReplicaSet `hello-<hash>` con `3` desired/current/ready.
- 3 Pods `hello-<hash>-<suffix>`.

Actualiza la imagen:

```bash
kubectl set image deployment/hello web=nginx:1.27-alpine
kubectl rollout status deployment/hello
kubectl get rs -l app=hello                 # verás DOS ReplicaSets, uno con 3 y otro con 0
```

---

## 6. Implementación progresiva

### 6.1 Primer paso: un Pod bare (anti-patrón consciente)

```yaml
apiVersion: v1
kind: Pod
metadata: { name: lonely, labels: { app: lonely } }
spec:
  containers:
    - name: web
      image: nginxdemos/hello:plain-text
      ports: [{ containerPort: 80 }]
```

`kubectl apply -f lonely.yaml` → el Pod corre. Ahora bórralo: `kubectl delete pod lonely`. **Desaparece**. Nadie lo recrea.

### 6.2 Segundo paso: envolver en Deployment

Cambia `kind: Pod` por un Deployment con `replicas: 1` y el mismo template. Ahora `kubectl delete pod <nombre>` → aparece **otro** Pod en segundos. Ese es el valor de un controller.

### 6.3 Tercer paso: escalar

```bash
kubectl scale deployment/hello --replicas=5
kubectl get pods -l app=hello                # 5 Pods
```

### 6.4 Cuarto paso: actualizar

```bash
kubectl set image deployment/hello web=nginx:1.27-alpine
kubectl rollout status deployment/hello
```

### 6.5 Quinto paso: historia y rollback

```bash
kubectl rollout history deployment/hello
kubectl rollout undo deployment/hello                       # vuelve a la anterior
kubectl rollout undo deployment/hello --to-revision=1       # vuelve a la primera
```

### 6.6 Sexto paso: anotar la causa de cambio

El flag `--record` está deprecado. Documenta la causa con una anotación:

```bash
kubectl annotate deployment/hello \
  kubernetes.io/change-cause="bump to nginx 1.27-alpine" \
  --overwrite
```

Aparece en `kubectl rollout history` como `CHANGE-CAUSE`.

### 6.7 Séptimo paso: pausar y combinar cambios

```bash
kubectl rollout pause deployment/hello
kubectl set image     deployment/hello web=nginx:1.27-alpine
kubectl set resources deployment/hello -c=web --requests=cpu=50m,memory=64Mi
kubectl rollout resume deployment/hello                     # dispara UN solo rollout con ambos cambios
```

### 6.8 Octavo paso: añadir un sidecar nativo

Agrega al `template.spec`:

```yaml
initContainers:
  - name: log-tail
    image: busybox:1.36
    restartPolicy: Always
    command: ["sh", "-c", "while true; do echo tailing...; sleep 5; done"]
```

`kubectl rollout status` → nuevo RS, Pods con 2 containers (`log-tail` + `web`), ambos vivos.

---

## 7. Aplicación profesional

### 7.1 Elección de estrategia

- **`RollingUpdate`** (default) → servicios de usuario sin downtime. Es lo que usarás 95% del tiempo.
- **`Recreate`** → mata todos los Pods viejos antes de crear los nuevos. Útil cuando:
  - Dos versiones **no pueden** convivir (migración de schema que rompe la vieja).
  - Un singleton (ej. GPU driver que exige exclusividad del device).
  - Dev/staging donde el downtime no cuesta nada.

### 7.2 Elección de maxSurge / maxUnavailable

- **Baseline conservador**: `maxSurge: 1`, `maxUnavailable: 0`. Nunca bajas la capacidad; pagas 1 Pod extra temporal. **Recomendado para servicios críticos**.
- **Baseline rápido**: `maxSurge: 25%`, `maxUnavailable: 25%` (los defaults). Rápido, pero puedes quedar al 75% durante la actualización.
- **Capacity-constrained**: `maxSurge: 0`, `maxUnavailable: 1`. Sin Pods extra; aceptas un hueco. Útil cuando los recursos del cluster son ajustados.

### 7.3 revisionHistoryLimit realista

Default 10. En práctica 5–10 es razonable. Más que eso infla etcd con ReplicaSets viejos. Menos de 3 te deja sin margen para rollbacks encadenados.

### 7.4 Deployments y Services van juntos

En la vida real nunca aplicas un Deployment solo. Siempre aplicas Deployment + Service (y a menudo + ConfigMap + Ingress/HTTPRoute). Las labels del Deployment template deben alinear con el `selector` del Service — por eso convertirlas en una convención (`app`, `component`, `version`) es más que estética.

### 7.5 Dónde empieza a quedarse corto un Deployment

- Workloads con **identidad estable** y almacenamiento por réplica → `StatefulSet` (`k8s-06`).
- Workloads que corren **uno por nodo** → `DaemonSet`.
- Trabajos de un solo paso → `Job`/`CronJob`.
- Rollout **progresivo con análisis automático de métricas** (canary, blue/green con shift gradual) → Argo Rollouts / Flagger (curso Argo CD).

---

## 8. Trade-offs

| Elección | A favor | En contra |
|----------|---------|-----------|
| `maxSurge: 0, maxUnavailable: 1` | No usa recursos extra | Caída transitoria de capacidad |
| `maxSurge: 1, maxUnavailable: 0` | Nunca pierdes capacidad | Necesitas 1 Pod de headroom |
| `Recreate` | Simple, dos versiones nunca conviven | Downtime garantizado |
| `revisionHistoryLimit: 10` (default) | Mucho margen para rollback | Infla etcd en Deployments muy activos |
| `revisionHistoryLimit: 3` | Historia compacta | Rollback encadenado limitado |
| Sidecar nativo | Shutdown ordenado, OK con Jobs | Requiere K8s ≥ 1.28–1.29 según madurez |
| Sidecar clásico | Portabilidad hacia atrás | Lifecycle problemático en Jobs y shutdown |

---

## 9. Errores frecuentes

1. **Modificar un Pod en vivo con `kubectl edit pod`** y asumir que la cambio "se queda". Si el Pod es gestionado por un Deployment, el próximo rollout lo pisa; si crashea y se recrea, también. **La verdad está en el template del Deployment**.
2. **Labels del `template` ≠ labels del `selector`**. El Deployment se crea pero no reclama a sus propios Pods, o el apiserver lo rechaza. Síntoma: `replicas: 3` desired pero `0` current, Pods huérfanos corriendo.
3. **Cambiar `selector` de un Deployment ya creado**. En `apps/v1` es inmutable. Borra y recrea.
4. **Olvidar que `kubectl set image` modifica solo el campo de imagen**. Si lo que querías era cambiar también `env` o `resources`, usa `kubectl apply` con el YAML completo (y guarda ese YAML en git).
5. **`kubectl rollout status` cuelga para siempre**. Causas típicas: imagen inexistente (`ImagePullBackOff`), readiness probe fallando, cluster sin recursos (Pending). Diagnóstico: `kubectl describe pod <nombre>`, `kubectl get events`.
6. **Usar `Recreate` para un servicio de usuario** porque "era más fácil". Baja todo, sube todo: downtime real.
7. **Crear Pods bare "porque es rápido"** y luego olvidar que no se reprograman. Si el nodo muere, el Pod se evapora.
8. **Confiar en que sin readiness probe el rollout es seguro**. Sin readiness, un Pod se cuenta Ready al minuto cero; `maxUnavailable: 0` no te protege de nada si tu app tarda 20 s en empezar a aceptar tráfico.

---

## 10. Buenas prácticas

- **Siempre** declara labels explícitas: al menos `app`, `component`, y una `version` cuando aplique.
- **Siempre** declara `strategy` explícito, aunque sea para dejar los defaults. Documenta la decisión.
- **Siempre** declara `revisionHistoryLimit` explícito. El default de 10 es defendible, pero haberlo pensado > haberlo heredado.
- Deja de usar `--record` (deprecado). Anota `kubernetes.io/change-cause` desde CI/CD.
- Cuando un rollout tenga que combinar múltiples cambios, usa `pause/resume` para disparar **un** solo rollout.
- Prefiere `kubectl apply -f` sobre `kubectl set image/edit`: el YAML en git es la fuente de verdad.
- Trata al Deployment como el **mínimo**: `+ Service` siempre, `+ PDB` cuando sea crítico (`k8s-09`), `+ probes` siempre que la app no sea trivial (`k8s-10`).
- Introduce **sidecar nativos** en workloads nuevos; migra los clásicos cuando toques el chart.

---

## 11. Ejercicios recomendados

1. Aplica el Deployment de la sección 5. Elimina un Pod con `kubectl delete pod`. Cuenta cuántos segundos tarda en volver a `3/3` ready.
2. Cambia `maxUnavailable: 0` por `maxUnavailable: 50%`. Haz un `set image` a una imagen inexistente. Observa cuántos Pods viejos quedaron, cuántos nuevos están Pending/ImagePullBackOff. Rollback.
3. Anota `kubernetes.io/change-cause` antes de un `set image`. Verifica que aparece en `rollout history`.
4. Convierte el Deployment a `strategy: Recreate` y repite un `set image`. Confirma con `kubectl get pods -w` que todos los viejos mueren antes de que nazca el primero nuevo.
5. Añade un sidecar nativo que escriba a `/var/log/app/hello.log` cada 5 s en un `emptyDir` compartido; verifica desde el main con `kubectl exec`.

---

## 12. Evaluación

Responde sin consultar documentación:

1. Un compañero crea un Pod con `kubectl apply -f pod.yaml`. El nodo donde corre muere. ¿Qué pasa con el Pod? ¿Qué cambiaría si lo hubiera envuelto en un Deployment con `replicas: 1`?
2. Describe paso a paso lo que ocurre cuando ejecutas `kubectl set image deployment/api web=api:v2` sobre un Deployment con `replicas: 10`, `maxSurge: 25%`, `maxUnavailable: 25%`. ¿Cuántos Pods pueden coexistir máximo? ¿Cuántos pueden estar no disponibles?
3. Tienes `revisionHistoryLimit: 3` y haces 5 actualizaciones consecutivas. ¿A qué revisión puedes volver con `kubectl rollout undo --to-revision=1`?
4. Un rollout se queda estancado. Lista en orden las tres primeras cosas que mirarías.
5. Un sidecar nativo y un sidecar clásico: dos diferencias observables al terminar el Pod y una diferencia observable dentro de un Job.
6. ¿Por qué el `selector` de un Deployment es inmutable en `apps/v1`? ¿Qué romperías si fuera mutable?

---

## Referencias

- Documentación oficial: `kubernetes.io/docs/concepts/workloads/pods/`.
- Documentación oficial: `kubernetes.io/docs/concepts/workloads/controllers/deployment/`.
- Documentación oficial: `kubernetes.io/docs/concepts/workloads/controllers/replicaset/`.
- Documentación oficial: `kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/`.
- `kubectl` reference: `kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout`.
- *Kubernetes Up & Running* (Burns/Beda/Hightower/Villalba) — capítulos de Pods y Deployments.
