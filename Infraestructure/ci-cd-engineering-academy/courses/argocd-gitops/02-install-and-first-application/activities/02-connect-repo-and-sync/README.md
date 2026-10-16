# argo-02-02 — Conectar un repo y sincronizar la primera Application

## 1. Identificación

- **ID:** `argo-02-02-connect-repo-and-sync`
- **Tecnología:** argocd-gitops
- **Módulo:** `02-install-and-first-application`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Con Argo CD ya corriendo (actividad 01), vas a crear tu **primera Application** apuntando al repo público `argoproj/argocd-example-apps`, directorio `guestbook/` (plain YAML: 1 `Deployment` + 1 `Service`). La vas a sincronizar y verificar que queda `Synced + Healthy`. Después vas a introducir drift a mano para ver cómo Argo CD lo refleja: `sync` y `health` cambian de forma independiente.

El validador verifica el estado final: Application `guestbook` existe en el namespace `argocd`, apunta al repo correcto, está `Synced + Healthy`, y el `Deployment guestbook-ui` del namespace `default` existe y está Ready.

## 3. Objetivos

Al terminar deberías poder:

- Loguearte en Argo CD por CLI usando port-forward + password inicial.
- Crear una Application contra un repo público usando `argocd app create`.
- Diagnosticar un `OutOfSync` con `argocd app diff`.
- Diferenciar `sync` de `health` con un caso real.

## 4. Prerrequisitos

- Haber completado `argo-02-01-bootstrap-argocd` (cluster `kind-argo-02` con Argo CD operativo).
- `argocd` CLI instalada (`brew install argocd` en macOS; binario oficial en Linux/Windows).
- Acceso a internet (para clonar el repo público desde el `repo-server`).

Si falta `argocd`, `kubectl`, `kind` o Docker, el validador imprime `SKIP` con instrucciones.

## 5. Instrucciones

Trabaja en `/tmp/argo-02-02/`.

### Paso 1 — port-forward y login

En una terminal:

```bash
mkdir -p /tmp/argo-02-02 && cd /tmp/argo-02-02
kubectl -n argocd port-forward svc/argocd-server 8080:443 \
  >/tmp/argo-02-02/pf.log 2>&1 &
echo $! > /tmp/argo-02-02/pf.pid
sleep 2
```

Login:

```bash
ARGO_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"
argocd login localhost:8080 \
  --username admin \
  --password "$ARGO_PASS" \
  --insecure
```

### Paso 2 — Application `guestbook`

Crea la Application contra el repo público (**estos parámetros son los que verifica el validador**):

- `name`: `guestbook`
- `repo`: `https://github.com/argoproj/argocd-example-apps.git`
- `path`: `guestbook`
- `revision`: `HEAD`
- `dest-server`: `https://kubernetes.default.svc`
- `dest-namespace`: `default`

Comando sugerido:

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --revision HEAD \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

### Paso 3 — estado antes de sync

```bash
argocd app get guestbook
#   Sync Status:   OutOfSync
#   Health Status: Missing
```

### Paso 4 — sync

```bash
argocd app sync guestbook
argocd app wait guestbook --health --timeout 180
argocd app get guestbook
#   Sync Status:   Synced
#   Health Status: Healthy
```

### Paso 5 — provoca drift (opcional pero recomendado)

```bash
# Escala a 0 réplicas a mano (operación que GitOps considera 'drift').
kubectl -n default scale deploy guestbook-ui --replicas=0
sleep 3
argocd app get guestbook
#   Sync Status:   OutOfSync
#   Health Status: Degraded

argocd app diff guestbook
#   Verás un diff en 'spec.replicas'.

# Reconcilia y vuelve a Healthy.
argocd app sync guestbook
argocd app wait guestbook --health --timeout 120
```

### Paso 6 — snapshot

Guarda `/tmp/argo-02-02/snapshot.md` con **estas secciones** (el validador busca los encabezados):

```markdown
# snapshot argo-02-02

## application
<salida de: argocd app get guestbook>

## resources
<salida de: argocd app resources guestbook>

## kube-view
<salida de: kubectl -n default get deploy,svc -l app.kubernetes.io/instance=guestbook>

## sync-vs-health
<2–3 líneas en prosa explicando con tu caso del paso 5 por qué una app puede estar
 Synced + Degraded, u OutOfSync + Healthy>
```

### Paso 7 — validar

```bash
bash courses/argocd-gitops/02-install-and-first-application/activities/02-connect-repo-and-sync/tests/validate.sh
```

## 6. Resultado esperado

- `argocd app get guestbook` muestra `Sync Status: Synced` y `Health Status: Healthy`.
- `argocd app list` muestra la app con `PROJECT default`, `CLUSTER https://kubernetes.default.svc`, `NAMESPACE default`.
- `kubectl -n default get deploy guestbook-ui` existe y está `1/1 READY`.
- `kubectl -n default get svc guestbook-ui` existe (ClusterIP).
- `/tmp/argo-02-02/snapshot.md` existe con las 4 secciones.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- La Application apunta exactamente al repo y path indicados (el validador verifica el `spec.source` del CR).
- `destination.namespace` es `default` y `destination.server` es `https://kubernetes.default.svc`.
- El snapshot incluye las 4 secciones (incluyendo la de `sync-vs-health` con tu propio texto).

## 8. Validación

```bash
bash courses/argocd-gitops/02-install-and-first-application/activities/02-connect-repo-and-sync/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si el repo `argocd-example-apps` cambia el `Deployment` de `guestbook/` mañana (p. ej. bump de image tag) y tú no haces nada, ¿cambia el `sync status`? ¿Cada cuánto se da cuenta Argo CD? (Pista: `argocd-cm.timeout.reconciliation`, default 3 min).
2. En el paso 5 dejaste el Deployment en 0 réplicas. ¿Por qué `Sync` pasa a `OutOfSync` pero `Health` no es `Missing` sino `Degraded`? ¿Qué diferencia hace el controller entre "no existe" y "existe pero no sirve"?
3. Si borras el Deployment con `kubectl delete deploy guestbook-ui -n default`, ¿Argo CD lo re-crea automáticamente? ¿Qué `syncPolicy` necesitarías para que sí? (Spoiler: `syncPolicy.automated.selfHeal` — tema de `argo-05`).
4. Mira el CR real: `kubectl -n argocd get application guestbook -o yaml | grep -A 10 'spec:'`. Compara los campos con lo que pasaste a `argocd app create`. ¿Qué flag → qué campo?
5. ¿Por qué `targetRevision: HEAD` es peligroso en producción? ¿Qué pondrías en su lugar para dev vs stg vs prod?

## 10. Extensiones

- Borra el CR Application sin cascade (`argocd app delete guestbook --cascade=false --yes`) y observa que el Deployment y el Service siguen vivos en `default`. ¿Por qué podrías querer esto en producción?
- Añade el repo a mano con `argocd repo add https://github.com/argoproj/argocd-example-apps.git` y mira el Secret que se crea en `argocd` (`kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=repository`).
- Crea una segunda Application `helm-guestbook` contra el mismo repo, `path helm-guestbook`, y observa que Argo CD detecta automáticamente que es Helm.

## 11. Limpieza

```bash
# Mata el port-forward.
kill "$(cat /tmp/argo-02-02/pf.pid 2>/dev/null)" 2>/dev/null || true

# Borra la app y sus recursos.
argocd app delete guestbook --cascade --yes 2>/dev/null || \
  kubectl -n argocd delete application guestbook --ignore-not-found

# Si quieres borrar todo el entorno:
# kubectl delete namespace argocd
# kind delete cluster --name argo-02

rm -rf /tmp/argo-02-02
```
