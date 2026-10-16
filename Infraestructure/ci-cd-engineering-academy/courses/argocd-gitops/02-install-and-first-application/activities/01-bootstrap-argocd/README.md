# argo-02-01 — Bootstrap de Argo CD en kind

## 1. Identificación

- **ID:** `argo-02-01-bootstrap-argocd`
- **Tecnología:** argocd-gitops
- **Módulo:** `02-install-and-first-application`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a levantar Argo CD en un cluster local kind, verificar que los 7 componentes del sistema aparecen, y extraer la contraseña inicial del admin. Es la base sobre la que corre todo el resto del curso.

El validador comprueba el estado final: cluster accesible, namespace `argocd` existe, los 6 Deployments y el StatefulSet están presentes y Ready, las CRDs instaladas, el Secret `argocd-initial-admin-secret` presente, y el snapshot con las 4 secciones.

## 3. Objetivos

Al terminar deberías poder:

- Crear un cluster kind con nombre explícito.
- Aplicar el `install.yaml` de Argo CD **pinneado a un tag** (no `stable`).
- Enumerar y explicar los 7 componentes del namespace `argocd`.
- Recuperar la contraseña inicial del admin desde el Secret `argocd-initial-admin-secret`.

## 4. Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, Docker corriendo.
- Acceso a internet para descargar el manifest y las imágenes.
- Sin costo monetario (todo local).

Si falta `kind`, `kubectl` o Docker, el validador imprime `SKIP` con instrucciones. Si el cluster `kind-argo-02` no existe, también.

## 5. Instrucciones

Trabaja en `/tmp/argo-02-01/`.

### Paso 1 — cluster

```bash
mkdir -p /tmp/argo-02-01 && cd /tmp/argo-02-01
kind create cluster --name argo-02
kubectl config use-context kind-argo-02
kubectl get nodes
```

### Paso 2 — namespace y manifest

Instala Argo CD **versión `v2.13.1`** (el validador verifica que estés en una versión conocida):

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.1/manifests/install.yaml
```

### Paso 3 — esperar readiness

```bash
kubectl -n argocd wait --for=condition=Available deploy --all --timeout=5m
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=5m
```

### Paso 4 — inspección

```bash
kubectl -n argocd get deploy
kubectl -n argocd get sts
kubectl -n argocd get crd | grep argoproj
```

### Paso 5 — contraseña inicial

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### Paso 6 — snapshot

Guarda `/tmp/argo-02-01/snapshot.md` con **estas secciones** (el validador busca los encabezados):

```markdown
# snapshot argo-02-01

## deployments
<salida de: kubectl -n argocd get deploy>

## statefulsets
<salida de: kubectl -n argocd get sts>

## crds
<salida de: kubectl get crd | grep argoproj>

## admin-password
<primera línea de 'kubectl ... | base64 -d'; una sola línea sin saltos>
```

### Paso 7 — validar

```bash
bash courses/argocd-gitops/02-install-and-first-application/activities/01-bootstrap-argocd/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl -n argocd get deploy` muestra los 6 Deployments (`argocd-server`, `argocd-repo-server`, `argocd-redis`, `argocd-applicationset-controller`, `argocd-notifications-controller`, `argocd-dex-server`), todos `Available`.
- `kubectl -n argocd get sts` muestra `argocd-application-controller` con `READY 1/1`.
- `kubectl get crd` incluye `applications.argoproj.io`, `applicationsets.argoproj.io`, `appprojects.argoproj.io`.
- Existe el Secret `argocd-initial-admin-secret` en el namespace `argocd`.
- `/tmp/argo-02-01/snapshot.md` existe con las 4 secciones.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Usaste `v2.13.1` explícito (no `stable`, no `master`).
- Dejaste que `kubectl create namespace argocd` creara el namespace (parte de la práctica — no lo pre-creaste con otro tooling).
- El snapshot tiene las 4 secciones (no basta con el título).

## 8. Validación

```bash
bash courses/argocd-gitops/02-install-and-first-application/activities/01-bootstrap-argocd/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `argocd-application-controller` es `StatefulSet` y los demás son `Deployment`? Pista: `kubectl -n argocd get pod | grep application-controller` muestra un nombre con sufijo `-0`.
2. Mira el Secret: `kubectl -n argocd get secret argocd-initial-admin-secret -o yaml`. ¿Qué pasa si lo borras y haces logout + login? ¿Cambia la password?
3. ¿Por qué pinnear a `v2.13.1` en vez de `stable`? ¿Qué problema real genera `stable` en un repo de GitOps?
4. ¿Qué pasaría si aplicaras el manifest `ha/install.yaml` en vez de `install.yaml`? ¿Qué cambia en el output del paso 4?
5. Mira los recursos cluster-wide: `kubectl get clusterrolebinding | grep argocd`. ¿Por qué Argo CD necesita permisos cluster-wide? Relación con el principio "pulled automatically".

## 10. Extensiones

- Instala también el CRD de ApplicationSet manualmente (ya viene en `install.yaml`, pero prueba con `applicationset-install.yaml` solo).
- Expón `argocd-server` con `kubectl -n argocd patch svc argocd-server -p '{"spec":{"type":"NodePort"}}'` y accede sin port-forward.
- Mira los logs del controller tras arranque: `kubectl -n argocd logs sts/argocd-application-controller --tail 50`. Observa el mensaje de sharding.

## 11. Limpieza

```bash
# Si solo quieres borrar Argo CD y conservar el cluster:
kubectl delete namespace argocd

# Si no vas a hacer la actividad 02 ahora:
kind delete cluster --name argo-02

rm -rf /tmp/argo-02-01
```
