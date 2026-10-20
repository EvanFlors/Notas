# Ejercicio operativo — Argo CD hands-on

- **Peso:** 40 puntos (OP-1..OP-5 × 8 pts)
- **Tiempo sugerido:** 55 minutos
- **Entorno obligatorio:** `kind` (Kubernetes-in-Docker) + Argo CD instalado por el candidato
- **Modalidad:** take-home, con validación por script `validate.sh`

> Prose/documentación en **español**. Comandos, manifests, nombres de recursos y mensajes de commit en **inglés**.

---

## 0. Prerrequisitos y SKIP policy

Necesitas en tu equipo:

- Docker Desktop / Docker Engine running
- `kind` ≥ 0.20
- `kubectl` ≥ 1.28
- `argocd` CLI ≥ 2.9
- `helm` ≥ 3.12
- `jq`, `yq`, `bash` 4+

Si **no puedes** cumplir estos prerrequisitos (sin acceso a Docker, sin permisos para instalar binarios, sin recursos locales), **SKIP el operativo** declarándolo en `submission/operative/SKIP.md` con la razón. Los 40 puntos se redistribuyen según `EXAM.md §3`. La certificación se emite con nota "sin validación hands-on" y 6 meses para retomar la parte práctica.

---

## 1. Bootstrap del entorno

Crea el cluster y despliega Argo CD con un repo local (el que entregarás) servido por un sidecar `git-sync` o commiteado a un repo tuyo (GitHub privado también vale).

```bash
# cluster
kind create cluster --name argocd-exam --config kind-config.yaml

# argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait -n argocd deploy/argocd-server --for=condition=Available --timeout=180s

# password inicial
argocd admin initial-password -n argocd

# port-forward (en otra terminal)
kubectl -n argocd port-forward svc/argocd-server 8080:443
argocd login localhost:8080 --username admin --password <PWD> --insecure
```

Tu repo de ejercicio tendrá esta estructura inicial (ver `starter/`):

```
starter/
  apps/
    broken-app/              # OP-1: Application rota
    hpa-app/                 # OP-2: convive con un HPA
    staged-app/              # OP-3: necesita waves + PreSync
    env-apps/                # OP-4: 3 apps hermanas (dev/stg/prod) a colapsar en ApplicationSet
  bootstrap/
    root-apps.yaml           # Application que apunta a apps/
  hardening/
    README.md                # instrucciones de OP-5
  kind-config.yaml
  Makefile                   # make verify ejecuta validate.sh
```

> Si no se incluye `starter/` en esta release del examen, el instructor lo genera a partir de `courses/argocd-gitops/02-install-and-first-application/activities/01-bootstrap-argocd/` y las actividades hermanas de los módulos 03, 04, 05, 07.

---

## 2. Tareas

### OP-1 — Diagnosticar y reparar `broken-app` (8 pts)

En `starter/apps/broken-app/` hay una Application + manifests que, tras el primer `argocd app sync`, queda `OutOfSync` y luego `Degraded`. Los síntomas son múltiples (puede ser **más de un** error introducido). Al menos uno de los errores es:

- `targetRevision: HEAD` apuntando a un branch que no existe, **o**
- un `Deployment` con `image: nginx:bogus-tag-that-does-not-exist`, **o**
- un `Service` con `selector` que no matchea los labels del pod, **o**
- una combinación.

**Entregables:**

- `apps/broken-app/` con el manifest reparado y commiteado.
- `operative/diagnosis.md` con una narrativa breve (≤ 20 líneas) describiendo:
  - qué comandos usaste (`argocd app get`, `argocd app diff`, `kubectl -n broken-app get events`, logs del `repo-server` o `application-controller`),
  - cuál fue tu hipótesis inicial y cómo la validaste,
  - cuál fue el fix mínimo.

**Validación automática:**

```bash
argocd app get broken-app -o json | jq -r '.status.sync.status, .status.health.status'
# debe imprimir: Synced  Healthy
```

**Red flag:** aplicar `kubectl apply` o `kubectl edit` para "arreglar" sin tocar Git (GitOps-washing).

---

### OP-2 — Convivir con un HPA sin fight-loop (8 pts)

En `starter/apps/hpa-app/` hay un `Deployment` (`replicas: 2` en Git) + `HorizontalPodAutoscaler` que escalará a 4 bajo carga sintética que el ejercicio simula con un Job. Con `syncPolicy.automated.selfHeal=true` ya habilitado, se produce fight-loop.

**Entregables:**

- Añadir `spec.ignoreDifferences` a la Application para que Argo CD no revierta `/spec/replicas`.
- No modificar el `Deployment` para hardcodear replicas al número del HPA.

**Validación automática:**

```bash
# Simula carga + espera 90s + comprueba
./validate.sh --task OP-2
# verifica: HPA escaló > 2, Application sigue Synced, no hay > 3 reconciliaciones por minuto
```

**Red flag:** desactivar `selfHeal` globalmente como "solución".

---

### OP-3 — Sync waves + PreSync migration (8 pts)

En `starter/apps/staged-app/` hay un `Deployment` de app + una `Secret` + un `ConfigMap`. Debes:

1. Añadir un **Job PreSync** llamado `db-migrate` que simule una migración (puede ser `busybox` con `sleep 5 && echo "migrated"`).
2. Garantizar que el `Deployment` **no** arranque hasta que el Job termine OK, usando `sync-waves`.
3. Si el Job falla (añade variante `db-migrate-fail` con `exit 1`), el `Deployment` nuevo **no** debe aplicarse — demostrar con una segunda rama/branch que esto se cumple.
4. Añadir `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` para no acumular Jobs.

**Entregables:**

- `apps/staged-app/db-migrate-job.yaml`
- `apps/staged-app/deployment.yaml` con la anotación `sync-wave` apropiada
- Breve nota en `diagnosis.md` explicando el orden de waves elegido.

**Validación automática:**

```bash
./validate.sh --task OP-3
# verifica:
#   1) kubectl -n staged get jobs | grep db-migrate -> exists
#   2) order: Job completed BEFORE Deployment rollout started (compara timestamps)
#   3) hook-delete-policy presente
#   4) escenario db-migrate-fail: Deployment NO avanza, Application en Degraded/SyncFailed
```

---

### OP-4 — Colapsar `env-apps/` en un ApplicationSet (8 pts)

En `starter/apps/env-apps/` hay 3 Applications casi idénticas: `web-dev`, `web-stg`, `web-prod`, apuntando a `envs/dev/`, `envs/stg/`, `envs/prod/` del repo de ejercicio. Debes reemplazarlas por **un** `ApplicationSet` con **Git generator** (directories) que descubra automáticamente los entornos y genere las 3 Applications.

**Entregables:**

- `apps/env-apps/applicationset.yaml` con `goTemplate: true`.
- Eliminar las 3 Applications individuales (o moverlas a `apps/env-apps/.deprecated/` para auditoría).
- El `AppProject` asociado debe restringir `destinations` solo a los namespaces `web-dev`, `web-stg`, `web-prod`.

**Validación automática:**

```bash
./validate.sh --task OP-4
# verifica:
#   1) kubectl -n argocd get applicationset web-envs
#   2) kubectl -n argocd get applications | grep -c '^web-' == 3
#   3) cada Application generada tiene project=web
#   4) AppProject.destinations NO contiene '*' en namespace
```

**Red flag:** `AppProject` con `destinations: '*/*'`.

---

### OP-5 — Hardening mínimo (8 pts)

Aplicar a la instalación de Argo CD:

1. **Deshabilitar admin local**: `argocd-cm` con `admin.enabled: "false"` (asumiendo que configuraste un token/SSO alternativo para el corrector; para el ejercicio basta con documentar el procedimiento y aplicar la clave en el `argocd-cm`).
2. **Pod Security `restricted`** al namespace `argocd` (labels `pod-security.kubernetes.io/enforce=restricted`, `warn`, `audit`).
3. **Documentar**: `hardening/README.md` con qué cambiaste, cómo lo verificaste, qué rompería y qué plan de rollback aplica si rompe algo.

> Antes de deshabilitar admin, verifica que los pods de Argo CD siguen arrancando bajo `restricted` (puede que haga falta ajustar `securityContext` del chart; documentarlo).

**Validación automática:**

```bash
./validate.sh --task OP-5
# verifica:
#   1) kubectl get ns argocd -o jsonpath='{.metadata.labels}' contiene pod-security.*=restricted
#   2) kubectl -n argocd get cm argocd-cm -o yaml | grep 'admin.enabled: "false"'
#   3) kubectl -n argocd get pods -> todos Running
#   4) hardening/README.md existe y no está vacío
```

**Red flag:** aplicar `restricted` sin verificar que los pods arrancan y entregar un cluster roto.

---

## 3. Validación agregada

```bash
make verify
# equivalente a:
# ./validate.sh --all --submission ./
```

El script imprime:

```
OP-1  diagnose-broken-app ...... [PASS/FAIL]  (0..8 pts)
OP-2  hpa-ignore-differences .... [PASS/FAIL]  (0..8 pts)
OP-3  sync-waves-presync ......... [PASS/FAIL]  (0..8 pts)
OP-4  applicationset-env ......... [PASS/FAIL]  (0..8 pts)
OP-5  hardening .................. [PASS/FAIL]  (0..8 pts)
-------------------------------------------------------------
TOTAL ................................ XX/40
```

Score por tarea sigue la rúbrica de `EXAM.md §5.2` (no es puramente binario; parcialmente funcional = 4-6 pts).

---

## 4. Qué entregar

```
submission/operative/
  repo/                      # El repo de ejercicio completo y commiteado
  diagnosis.md               # Narrativa de OP-1, waves de OP-3, hardening de OP-5
  validate-output.txt        # Output literal de `make verify`
  SKIP.md                    # Solo si no pudiste correr el entorno
```
