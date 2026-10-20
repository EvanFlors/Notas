# Capstone — Etapa 9: Helm chart propio + Argo CD

> Fase 5 del programa · Dominios tocados: D8 (Kubernetes + GitOps).
> Stack: **kind local + Helm 3 + Argo CD v2.12** sobre la app FastAPI ya portada en la etapa 8.
> Esta etapa sigue siendo **local-first**: todo corre en `kind`, sin cloud.

---

## 1. Resumen de la etapa

**Objetivo.** Empaquetar la app FastAPI del capstone como un chart Helm propio
(`charts/fastapi-app/`) con `values.yaml`, `values.schema.json`, `_helpers.tpl`,
`NOTES.txt` y un test de smoke; instalar Argo CD en el cluster kind; y
registrar el chart via una `Application` CR con policy automated + selfHeal,
asi la app se despliega y se mantiene reconciliada por GitOps en vez de
`kubectl apply` manual.

**Delta vs. etapa 8.**

- Etapa 8 desplegaba la app con `kubectl apply -f` sobre manifests estaticos.
- Ahora los manifests son plantillas Helm parametrizadas por `values*.yaml`
  y la fuente de verdad para dev es una `Application` que Argo CD reconcilia.
- Aparece la nocion de "release" (`fastapi` en namespace `fastapi-dev`) y de
  "app of apps" para escalar a mas Applications sin manifests sueltos.

**Fuera de scope (siguientes etapas).**

- Multi-ambiente con `ApplicationSet` + overlays por env → etapa 10.
- Progressive delivery con Argo Rollouts (canary/blue-green) → etapa 10.
- Observabilidad del chart (Prometheus Operator, ServiceMonitor) → etapa 11.
- External Secrets para el `DATABASE_URL` → etapa 12.
- Firma del chart con cosign + verificacion en Argo CD → etapa 12.

---

## 2. Arquitectura al cierre de esta etapa

```
+----------------------+        git push         +----------------------+
|  Developer laptop    |  --------------------> |  Git repo (chart +   |
|  helm lint/template  |                        |  argocd/*.yaml)      |
+----------+-----------+                        +----------+-----------+
           |                                               |
           | kubectl apply argocd/app-of-apps.yaml         | poll (3 min)
           v                                               v
+-------------------------------------------------------------------+
|                     kind cluster "capstone"                       |
|                                                                   |
|  +------------------+        +---------------------------------+  |
|  |  argocd ns       |        |  fastapi-dev ns                 |  |
|  |                  | sync   |                                 |  |
|  |  argocd-server   +------> |  Deployment fastapi             |  |
|  |  repo-server     |        |  Service    fastapi (ClusterIP) |  |
|  |  app-controller  |        |  ConfigMap  fastapi-env         |  |
|  |                  |        |  Secret     fastapi-db (dummy)  |  |
|  +------------------+        +---------------------------------+  |
+-------------------------------------------------------------------+
```

**Entradas.** Cambios en el chart (valores, templates) empujados a git →
Argo CD los detecta y reconcilia. Manual: `kubectl apply` del `app-of-apps`.

**Salidas.** Pods `fastapi-*` respondiendo `/healthz` y `/readyz`; UI de
Argo CD mostrando la Application en `Synced + Healthy`.

**Resource list (local).** 1 cluster kind, 1 namespace `argocd` (controller,
server, repo-server, redis, dex, applicationset-controller, notifications),
1 namespace `fastapi-dev` (Deployment + Service + ConfigMap + Secret). Cero
recursos cloud.

---

## 3. Prerrequisitos verificados

Checklist consumido de etapas anteriores:

- [ ] Etapa 1-7 cerradas (app funcional, imagen publicada, IaC/cloud opcional).
- [ ] Etapa 8 cerrada: la app corre en `kind` con manifests estaticos y responde
      `/healthz`. Namespace y nombre coinciden con los que este chart asume.
- [ ] `kind` + `kubectl` disponibles. Cluster `capstone` creado.
- [ ] `helm` v3.14+ instalado (`helm version`).
- [ ] Opcional pero recomendado: `kubeconform` o `kube-linter` para validar.

Si falta algo, cerrar la etapa anterior primero. El `validate.sh` reporta
`SKIP` cuando `helm` o `kubectl` no estan.

---

## 4. Implementacion guiada

### 4.1 Esqueleto del chart

```bash
cd projects/capstone/stages/09-helm-chart-argocd
helm lint charts/fastapi-app
helm template fastapi charts/fastapi-app --values charts/fastapi-app/values-dev.yaml \
  | head -40
```

**Por que un chart propio y no `helm create` + edicion.** `helm create`
inyecta ServiceAccount con `automountServiceAccountToken: true` por default,
no respeta `readOnlyRootFilesystem`, y mete un `tests/` que apunta a NGINX.
Para una app real preferimos escribir el chart desde cero: menos codigo, mas
intencion visible y los defaults ya son production-friendly.

### 4.2 Decisiones materiales del chart

- `_helpers.tpl` define `name`, `fullname`, `chart`, `labels`,
  `selectorLabels` y `serviceAccountName`. Los helpers evitan repetir las
  mismas 6 lineas en cada template.
- Deployment usa `checksum/config` y `checksum/secret` como anotaciones del
  pod: cuando cambia el ConfigMap o Secret, el hash cambia y el rollout
  se dispara automaticamente (truco canonico de Helm).
- `securityContext` + `podSecurityContext` siguen baseline Pod Security
  Standards *restricted*: `runAsNonRoot`, `readOnlyRootFilesystem`,
  drop ALL caps, `seccompProfile: RuntimeDefault`. Monta `emptyDir` en
  `/tmp` porque uvicorn necesita escribir temporales.
- `values.schema.json` valida el shape de los values al momento de
  `helm template|install|upgrade`. Esto convierte errores de tipeo
  (p.ej. `replicaCount: "two"`) en fallos tempranos antes de llegar a
  Kubernetes.
- `templates/tests/test-connection.yaml` es un `helm.sh/hook: test` que
  Argo CD puede ejecutar via `helm test` para smoke despues de un sync.

### 4.3 Render local y verificacion

```bash
helm lint charts/fastapi-app
helm template fastapi charts/fastapi-app \
  --values charts/fastapi-app/values-dev.yaml \
  --namespace fastapi-dev \
  --output-dir /tmp/cap-09-render
```

Validacion opcional con `kubeconform`:

```bash
helm template fastapi charts/fastapi-app --values charts/fastapi-app/values-dev.yaml \
  | kubeconform -strict -summary -ignore-missing-schemas
```

### 4.4 Instalar Argo CD

```bash
./scripts/install-argocd.sh
```

El script es idempotente, imprime SKIP si `kubectl` o el cluster no estan.

### 4.5 Registrar la Application fastapi-dev

```bash
# Primero publica el chart al repo git (o OCI) real; para la demo basta con
# dejarlo en este repo y apuntar la Application a este path.
kubectl apply -f argocd/applications/fastapi-dev.yaml
kubectl -n argocd get applications
```

**Por que `syncPolicy.automated: {prune: true, selfHeal: true}`.** `prune`
borra lo que ya no esta en git (evita leftovers), `selfHeal` revierte
cambios hechos a mano con `kubectl edit` (hace cumplir "git es la fuente de
verdad"). En prod suele empezar en `false` para que un humano apruebe el
primer sync, pero en dev molesta mas de lo que ayuda.

### 4.6 App-of-apps

```bash
kubectl apply -f argocd/app-of-apps.yaml
```

A partir de aqui, cualquier Application nueva que agregues a
`argocd/applications/` sera descubierta por `capstone-root` y sincronizada
sin pasos manuales extra.

---

## 5. Actividades del estudiante

Viven bajo `activities/`. Cada una es ejecutable independientemente con su
`tests/validate.sh`.

| ID activity | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-09-01-build-helm-chart` | guided-lab | 60 min | Construir el chart desde cero: `_helpers.tpl`, Deployment+Service+Ingress, `values.schema.json`, `helm lint` + `helm template` verdes. |
| `cap-09-02-register-argocd-app` | independent | 50 min | Instalar Argo CD en kind, escribir la `Application` CR del chart (git o OCI), observar sync + self-heal borrando un pod a mano. |

Cumple el criterio "al menos una `independent` o `debug`" con la 2.

---

## 6. Entregables

Al cerrar la etapa el estudiante debe poder mostrar:

1. `charts/fastapi-app/` completo (`Chart.yaml`, `values.yaml`,
   `values.schema.json`, `templates/`, `_helpers.tpl`, `NOTES.txt`,
   `tests/`), con `helm lint` sin warnings bloqueantes y
   `helm template` renderizando sin errores.
2. Argo CD corriendo en el namespace `argocd` del cluster kind.
3. `argocd/applications/fastapi-dev.yaml` aplicado y la Application
   reportando `Sync Status: Synced` + `Health Status: Healthy`.
4. `argocd/app-of-apps.yaml` aplicado y gestionando la Application hija.
5. Evidencia: screenshot (o `kubectl` dump) de `kubectl -n argocd
   get applications` + `kubectl -n fastapi-dev get all`.
6. Las 2 actividades con sus `validate.sh` en verde (o `SKIP` justificado
   si `helm`/`kubectl` no estan instalados).

---

## 7. Pruebas y criterios de aceptacion

Chequeos automaticos:

- [ ] `helm lint charts/fastapi-app` sale en 0.
- [ ] `helm template fastapi charts/fastapi-app --values charts/fastapi-app/values-dev.yaml`
      genera YAML parseable.
- [ ] `values.schema.json` rechaza un `replicaCount: "dos"` (prueba
      intencional).
- [ ] `kubectl -n argocd get deploy argocd-server` reporta `AVAILABLE 1/1`.
- [ ] `kubectl -n argocd get applications fastapi-dev` reporta
      `Synced` + `Healthy`.
- [ ] `helm test fastapi -n fastapi-dev` sale en 0.
- [ ] Si borras un pod a mano (`kubectl delete pod ...`) Argo CD lo
      recrea sin intervencion (selfHeal demostrado).

Criterios de calidad:

- [ ] Cero secretos reales (todo `DATABASE_URL` es `dummy_*`).
- [ ] Chart respeta Pod Security Standard *restricted*.
- [ ] Templates idempotentes: `helm upgrade` sin cambios no reinicia pods.
- [ ] `.helmignore` presente para no empaquetar basura.
- [ ] `README.md` del chart no se publica como artefacto, pero el chart
      incluye `description` y `maintainers` en `Chart.yaml`.

---

## 8. Costos y limpieza

**Costo cloud:** $0.00 — todo corre en el laptop (kind + Argo CD).

**Limpieza:**

```bash
# App primero
kubectl delete -f argocd/applications/fastapi-dev.yaml --ignore-not-found
kubectl delete namespace fastapi-dev --ignore-not-found

# App-of-apps
kubectl delete -f argocd/app-of-apps.yaml --ignore-not-found

# Argo CD completo
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.12.3}"
kubectl delete -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  --ignore-not-found
kubectl delete namespace argocd --ignore-not-found

# Opcional: tumbar el cluster entero (si no lo necesitas para la etapa 10)
kind delete cluster --name capstone
```

Sin recursos cloud no hay nada que destruir con `terraform` o similar.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigacion |
|---|---|
| Loop de reconciliacion si `selfHeal: true` y alguien hace `kubectl edit` sin querer. | Documentar en el README que dev usa selfHeal; en staging/prod se baja a `false` y se exige PR. |
| `Application` apuntando a `HEAD` → cambio sin querer en main deshace el deploy. | Pinnear `targetRevision` a un tag o SHA en entornos no-dev. |
| Chart no valida tipos y produce manifests invalidos aguas abajo. | `values.schema.json` + `helm lint` + `kubeconform` en CI (etapa 10). |
| Secreto del `DATABASE_URL` queda en git. | El Secret del chart es DUMMY. En staging/prod viene de External Secrets Operator (etapa 12). |

**Hints progresivos:**

1. `helm template` falla? Corre con `--debug` para ver el YAML a medio
   renderizar.
2. Argo CD queda en `OutOfSync` perpetuo? Mira `kubectl -n argocd describe
   application fastapi-dev`, el error suele estar en `spec.source.path`.
3. El selfHeal no revierte? Revisa que la Application NO tenga
   `syncPolicy.automated.prune: false` por error.

---

## 10. Puente con la siguiente etapa

**Que habilita esta etapa.** La etapa 10 (GitOps multi-ambiente + Argo
Rollouts) necesita dos cosas que esta etapa deja listas: (a) un chart
parametrizable por `values*.yaml` por ambiente, y (b) una conexion sana
entre git y el cluster via Argo CD. Sin un chart propio bien definido no
podemos razonar sobre canary/blue-green mas adelante.

**Que dejamos corriendo.** Argo CD en el cluster kind, mas la Application
`fastapi-dev` en estado `Synced + Healthy`. Si no vas a seguir hoy,
`kind delete cluster --name capstone` libera recursos.

**Cliffhanger.** Ya tenemos **un** ambiente dev gestionado por Argo CD.
Pero el capstone necesita dev + staging + prod, cada uno con su
`values-<env>.yaml`, su promocion por git tag y su estrategia de release
distinta. Clonar `fastapi-dev.yaml` tres veces escala mal. ¿Como generamos
una familia de Applications sin copiar YAMLs? Esa es la etapa 10
(`ApplicationSet` + Argo Rollouts).
