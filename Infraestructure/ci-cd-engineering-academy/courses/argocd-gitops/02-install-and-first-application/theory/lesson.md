# argo-02 — Lección: instalar Argo CD y gestionar la primera Application

> 12 secciones. Lee con un cluster kind abierto en otra terminal: todo lo que se afirma aquí se verifica en segundos con `kubectl`, `argocd` o la UI.

---

## 1. El modelo mental: Argo CD es un operador de Kubernetes

Argo CD no es un pipeline. No corre jobs. No tiene un "runner". Es un **operador** clásico de Kubernetes: un conjunto de controllers que leen Custom Resources (`Application`, `AppProject`, `ApplicationSet`), observan el cluster, y actúan para hacer converger la realidad hacia lo que dicen los CRs. El estado deseado para cada Application vive **en Git**; el estado para Argo CD mismo (projects, repos, apps) vive **en el API server del cluster** como objetos K8s.

La implicancia práctica: todo lo que hagas por UI o CLI al final crea, modifica o borra un CR en el namespace `argocd`. Puedes operar Argo CD **100% con `kubectl apply -f app.yaml`**; la CLI y la UI son solo frontends amables. Esto es lo que permite el patrón "self-managed Argo CD" (`argo-08`).

---

## 2. Instalación: `install.yaml` vs chart Helm vs `core`

Argo CD publica varios manifests oficiales en `https://raw.githubusercontent.com/argoproj/argo-cd/<TAG>/manifests/`:

| Manifest | Qué instala | Cuándo elegir |
|---|---|---|
| `install.yaml` | Instalación completa en namespace `argocd` (todos los componentes). | Default. Para labs y la mayoría de instalaciones no-HA. |
| `ha/install.yaml` | HA: 3 réplicas de `argocd-server`, `repo-server`, `applicationset-controller`, Redis con sentinel. | Producción. |
| `core-install.yaml` | Solo `application-controller` + `repo-server` + `redis`. Sin UI, sin API server, sin dex. | GitOps "austero": todo por `kubectl` sobre los CRs; sin acceso humano al cluster. |
| `namespace-install.yaml` | Instalación **limitada a un namespace** (sin ClusterRoles). | Multi-tenant estricto donde Argo CD solo puede ver su propio namespace. |

El **chart Helm** oficial (`argo/argo-cd`) es equivalente pero más configurable (p. ej. integrar `ingress`, OIDC values, extra args) y es el camino preferido en producción. Para una primera instalación de aprendizaje, el `install.yaml` es más honesto porque dejas ver qué objetos aparecen en el cluster.

Patrón de instalación recomendado para labs:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.1/manifests/install.yaml
```

Siempre **pinnea el tag**. `stable` cambia bajo tus pies; `master` puede romperse.

---

## 3. Los 7 componentes (y quién los corre)

Después del `apply` del `install.yaml`, el namespace `argocd` queda con:

```
Deployment  argocd-server                       (UI + API gRPC/HTTP)
Deployment  argocd-repo-server                  (clona repos y renderiza)
Deployment  argocd-redis                        (caché; también usado como pub/sub)
Deployment  argocd-applicationset-controller    (ApplicationSet → N Applications)
Deployment  argocd-notifications-controller     (triggers → Slack / webhook / etc.)
Deployment  argocd-dex-server                   (OIDC federation; opcional)
StatefulSet argocd-application-controller       (reconcilia Applications; sharded)
```

Por qué `application-controller` es **StatefulSet** y los demás **Deployment**: cada réplica del application-controller es responsable de un **shard** del universo de Applications, y el shard se asigna por índice ordinal (0, 1, 2...). Los pods de StatefulSet tienen identidad estable (`argocd-application-controller-0`, `-1`...), lo que hace trivial decir "shard 0 → pod -0". Un Deployment, con nombres aleatorios y re-creaciones, no da esa garantía.

Por qué `repo-server` es Deployment: es stateless. Cada réplica puede clonar cualquier repo bajo demanda (con un cache local efímero en `/tmp`). Si una réplica muere, otra toma el pedido sin coordinación.

Por qué hay un Redis: cachea el **resultado del rendering** del repo-server y es el canal de **invalidación** entre réplicas del application-controller. Sin Redis, cada ciclo de reconciliación re-renderizaría el repo (lento, caro).

---

## 4. Acceso inicial: port-forward + contraseña

Fresh install, no hay LoadBalancer ni Ingress. La forma estándar en labs:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
```

La **contraseña inicial del admin** se genera aleatoriamente y se guarda en un Secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

O, equivalente, desde la CLI:

```bash
argocd admin initial-password -n argocd
```

Con eso ya puedes:

```bash
argocd login localhost:8080 --username admin --password '<PASSWORD>' --insecure
```

El `--insecure` es por el certificado autofirmado del `argocd-server` (lo arreglas en producción con un Ingress + cert real + OIDC — `argo-11`).

Después del primer login, se recomienda:

1. Cambiar la contraseña: `argocd account update-password`.
2. Borrar el Secret: `kubectl -n argocd delete secret argocd-initial-admin-secret`. Argo CD lo busca al arrancar; si existe, lo usa como fuente de la "initial password". Borrarlo evita que un atacante con acceso de lectura al namespace la recupere.

En producción el admin local se **deshabilita** vía `argocd-cm`: `admin.enabled: "false"` y toda identidad entra por SSO.

---

## 5. La CLI `argocd`: contratos del día a día

Instalación en macOS: `brew install argocd`. En Linux, binario estático desde releases. En Windows, `choco install argocd-cli`.

La CLI es stateless salvo por un archivo de config en `~/.config/argocd/config` con los contextos (igual que `kubectl`). `argocd context` lista; `argocd context <name>` cambia.

Comandos esenciales por categoría:

| Categoría | Comando |
|---|---|
| Sesión | `argocd login <HOST>`, `argocd logout <HOST>`, `argocd context` |
| Clusters | `argocd cluster list`, `argocd cluster add <CTX>` |
| Repos   | `argocd repo list`, `argocd repo add <URL> [--username ... --password ...]` |
| App CRUD | `argocd app create <NAME> --repo ... --path ... --dest-server ... --dest-namespace ...` |
| App read | `argocd app list`, `argocd app get <NAME>` |
| Sync | `argocd app sync <NAME>`, `argocd app diff <NAME>`, `argocd app wait <NAME>` |
| Historia | `argocd app history <NAME>`, `argocd app rollback <NAME> <ID>` |

Una regla importante: **cualquier flag de `app create` corresponde a un campo del CR `Application`**. `argocd app create --dry-run -o yaml` imprime el YAML que iría al cluster. Es la mejor forma de aprender la forma del CR sin leer la docs.

---

## 6. La primera Application: `guestbook` desde el repo oficial

El equipo de Argo CD mantiene un repo didáctico con apps de ejemplo: [`argoproj/argocd-example-apps`](https://github.com/argoproj/argocd-example-apps). Dentro, el directorio `guestbook/` contiene dos manifests plain YAML: un `Deployment` y un `Service`.

Comando mínimo:

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --revision HEAD
```

El equivalente YAML (lo que podrías `kubectl apply`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    path: guestbook
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

Nota: `dest-server: https://kubernetes.default.svc` es la forma canónica de decir "**el mismo cluster** donde corre Argo CD". Esta string es un alias interno; no es una URL que resuelvas con `curl`.

Después del `create`, la Application existe pero está en `OutOfSync` (nada se desplegó aún). Un `argocd app sync guestbook` dispara el apply.

---

## 7. Sync status: lo que Argo CD cree que debería estar

**Sync** es un **diff estructural** entre:

- *Desired*: los manifests renderizados por el `repo-server` a partir del commit en `targetRevision`.
- *Live*: los manifests que trae `kubectl get -o yaml` del cluster target.

Resultados posibles:

- `Synced` — para cada recurso definido en Git, el objeto live tiene los mismos campos relevantes.
- `OutOfSync` — hay al menos una diferencia (campo distinto, recurso faltante, recurso con drift).
- `Unknown` — Argo CD no pudo clonar el repo o renderizar.

`argocd app diff <NAME>` imprime exactamente las diferencias (como un `diff -u`). Es *la* herramienta para entender por qué una app está `OutOfSync`.

Lo que **no** mira el sync: la salud real del Pod. Un `Deployment` con `replicas: 3` y los 3 Pods en `CrashLoopBackOff` sigue siendo `Synced` — el manifest coincide. Lo que no coincide es el *mundo real*; eso lo mide el **health**.

---

## 8. Health status: lo que de verdad está pasando

**Health** es un juicio semántico sobre cada recurso: ¿está sirviendo bien?

Argo CD trae **health checks** builtin por `kind`:

- `Deployment` — `Healthy` si `status.availableReplicas == spec.replicas`.
- `StatefulSet` — igual con `readyReplicas`.
- `Service type: LoadBalancer` — `Healthy` si tiene `status.loadBalancer.ingress`.
- `Pod` — `Healthy` si `Running` o `Succeeded`; `Progressing` si `Pending`; `Degraded` si `Failed`.
- `Job` — `Healthy` cuando `Complete`.
- `Ingress`, `Certificate` (cert-manager), `Rollout` (Argo Rollouts), etc.

Resultados por recurso: `Healthy | Progressing | Degraded | Suspended | Missing | Unknown`. La Application agrega el *peor* de sus recursos.

Para checks custom hay **resource customizations** en Lua (`argocd-cm` → `resource.customizations.health.<group>_<kind>`). Es como se enseña a Argo CD a entender tus CRDs.

La matriz sync × health es rica:

| Sync | Health | Significado |
|---|---|---|
| Synced | Healthy | Estado ideal. |
| Synced | Progressing | Acabas de aplicar; está arrancando. |
| Synced | Degraded | El manifest es el correcto pero la app está rota (bad image, crash). |
| OutOfSync | Healthy | Alguien tocó algo a mano o el repo cambió y no sincronizaste. |
| OutOfSync | Degraded | Doble problema; divergencia + runtime roto. |

Confundir sync con health es el error #1 de operadores nuevos. "Está Synced ¿no?" no significa "funciona".

---

## 9. `app sync`: qué hace exactamente

`argocd app sync guestbook` ejecuta:

1. `repo-server` clona el repo en `targetRevision` y renderiza los manifests.
2. `application-controller` calcula el diff vs live.
3. Para cada recurso con diferencia, hace un **`kubectl apply`** server-side (si está activado `ServerSideApply=true`) o client-side (default).
4. Opcionalmente ejecuta hooks (`PreSync`, `Sync`, `PostSync`) — tema de `argo-05`.
5. Espera a que el health converja (si pasaste `--wait`) o retorna inmediato.

Flags útiles de aprendizaje:

- `--dry-run` — no aplica, solo imprime qué haría.
- `--prune` — borra recursos que están en el cluster pero ya no en Git. **Peligroso sin saberlo**; por eso no está activado por default.
- `--force` — fuerza replace donde Argo CD no se atrevería (`immutable fields`).

El `app sync` **no** modifica Git. Argo CD **nunca** escribe a Git. Si estás `OutOfSync` porque el live diverge, `sync` **sobreescribe el live con lo de Git**. Si tu intención era lo opuesto (promover el drift a Git), eso lo haces tú con un commit; Argo CD no tiene ese flujo.

---

## 10. `app history` y `app rollback`: rollback real

Cada vez que una Application sincroniza, Argo CD graba una entrada en el **history**:

```bash
argocd app history guestbook
# ID  DATE                      REVISION
# 0   2026-10-15 10:12:00 UTC   53e16d8
# 1   2026-10-15 10:30:12 UTC   af1b47a
```

Cada entrada apunta al commit SHA. Un `argocd app rollback guestbook 0` **vuelve a aplicar la revisión 0** — es decir, sincroniza contra ese commit viejo. **No** toca Git; el repo sigue teniendo `af1b47a` en `HEAD`, pero el cluster vuelve a `53e16d8`.

El efecto esperado: a los pocos segundos, auto-sync (si está activado) o la próxima reconciliación detecta que `HEAD` sigue siendo `af1b47a` y vuelve a aplicar `af1b47a` → tu rollback dura 3 minutos.

Por eso **el verdadero rollback en GitOps es `git revert`**: creas un commit que deshace el anterior; `HEAD` apunta al estado deseado-tras-rollback y Argo CD lo aplica. `argocd app rollback` es útil para incidentes (una ventana corta mientras preparas el revert en Git), no como mecanismo permanente.

---

## 11. `app diff`: el comando que más vas a usar

```bash
argocd app diff guestbook
```

Imprime, para cada recurso con drift, un diff unificado entre live y desired. Útil para:

- Entender por qué una app está `OutOfSync` sin tener que `kubectl get -o yaml` cada recurso.
- Previsualizar un cambio **antes** de sincronizar (`argocd app diff` tras `git push` pero antes de `sync`).
- Automatizar comentarios en PRs (`argocd app diff --revision $PR_SHA` en un workflow de CI que comenta el diff en el PR del repo de infra — patrón de `argo-12`).

Flags clave:

- `--revision <SHA>` — compara contra ese commit en vez de `HEAD`.
- `--local <path>` — compara contra un checkout local (útil cuando aún no has pusheado).
- `--server-side-generate` — delega el rendering al server (más fiel al flujo real).

Códigos de salida: `0` si no hay diff, `1` si hay. Útil en CI (`argocd app diff && echo "en sync"`).

---

## 12. Lo que no estamos haciendo (y por qué todavía no)

Este módulo deliberadamente **no** cubre:

- **Políticas automatizadas de sync** (`syncPolicy.automated`, `prune`, `selfHeal`). Son el salto cualitativo de "GitOps como botón" a "GitOps como reconciliación continua"; se tratan en `argo-05` con el peso que merecen.
- **Projects y RBAC**. Toda esta lección opera en el project default, que permite cualquier cosa. Eso es inaceptable fuera de un lab local y se arregla en `argo-06`.
- **Helm o Kustomize como source**. Aquí usamos plain YAML para que la relación "manifest en Git → objeto en cluster" sea directa. Las fuentes templatizadas y multi-source se tratan en `argo-04`.
- **Ingress / OIDC / HA**. El port-forward y el admin local son correctos para aprender; para prod se endurece en `argo-11`.
- **ApplicationSet**. Es la forma correcta de generar muchas Applications; aquí creamos *una* a mano para entender la pieza atómica. ApplicationSet llega en `argo-07`.

Internaliza bien estas 12 secciones y el resto del curso te costará la mitad: todo lo demás son variaciones sobre "Application + source + sync + health" con más capas de orquestación.
