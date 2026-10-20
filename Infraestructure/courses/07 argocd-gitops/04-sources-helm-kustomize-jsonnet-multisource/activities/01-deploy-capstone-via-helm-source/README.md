# Actividad 01 — Desplegar un capstone vía Helm source en Argo CD

## 1. Identificación

- **ID:** `argo-04-01-deploy-capstone-via-helm-source`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `04-sources-helm-kustomize-jsonnet-multisource`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a instalar Argo CD en un cluster `kind` local, publicar una `Application` que consume un chart Helm **público** (`podinfo`, un chart ligero y bien conocido), e inspeccionar cómo Argo CD renderiza y aplica — sin ejecutar `helm install`. Terminarás comprobando que `helm list` **no ve** el release y entendiendo exactamente por qué.

Esto reproduce el patrón "capstone desplegado por GitOps vía chart Helm", que es la columna vertebral del curso.

## 3. Objetivos

Al terminar deberías poder:

- Instalar Argo CD con los manifiestos oficiales.
- Escribir una `Application` que use **Helm source** con `releaseName`, `valueFiles` y `parameters`.
- Verificar que Argo CD aplica recursos **sin** crear el Secret `sh.helm.release.v1.*`.
- Modificar un parámetro y observar la reconciliación continua.

## 4. Prerrequisitos

- Docker Desktop o engine corriendo.
- `kind` ≥ 0.20 instalado (`kind version`).
- `kubectl` ≥ 1.28 instalado.
- `helm` ≥ 3.14 instalado.
- `argocd` CLI (opcional pero recomendado).
- Acceso a Internet para descargar imágenes y el chart.

**Costos**: ninguno — todo local.

Si falta alguna herramienta, los tests harán **SKIP** gracioso.

## 5. Instrucciones

### 5.1 Crear el cluster kind

```bash
cd starter/
bash 01-create-cluster.sh
```

El script usa `/tmp/argo-04-01/` como scratch. Si ya hay un cluster `argo-04-01`, lo reutiliza.

### 5.2 Instalar Argo CD

```bash
bash 02-install-argocd.sh
```

Esto crea el namespace `argocd`, aplica el manifest de `install.yaml` oficial y espera a que todos los pods estén `Ready`. Tarda ~2 min la primera vez.

### 5.3 Escribir la Application

Edita `starter/application.yaml`. Esqueleto incompleto:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  destination:
    namespace: podinfo
    server: https://kubernetes.default.svc
  source:
    repoURL: https://stefanprodan.github.io/podinfo
    chart: podinfo
    targetRevision: 6.7.1
    helm:
      releaseName: # <-- TODO
      values: |
        # <-- TODO (inline values: habilitar hpa=false, replicaCount=2)
      parameters:
        - name: # <-- TODO: image.tag
          value: # <-- TODO: pin a 6.7.1
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Completa los `TODO`:

- `releaseName`: `podinfo`.
- `values` inline: `replicaCount: 2` y `hpa.enabled: false`.
- `parameters`: fija `image.tag` a `6.7.1`.

### 5.4 Aplicar la Application y sincronizar

```bash
kubectl apply -f application.yaml
# Esperar a que Argo CD cree los recursos
kubectl -n podinfo wait --for=condition=available deployment/podinfo --timeout=180s
```

### 5.5 Inspeccionar — la observación clave

```bash
# Lo que Argo CD aplicó
kubectl get all -n podinfo

# Lo que ve Helm
helm list -n podinfo
# ↑ vacío. No hay release de Helm. Argo CD hizo `helm template` + apply.

# Lo que confirma el renderizado:
kubectl get application podinfo -n argocd -o yaml | grep -A3 'helm:'
```

### 5.6 Modificar un parámetro y observar

Cambia `replicaCount` a `3` en `values` inline, re-aplica el manifest de la Application y observa:

```bash
kubectl apply -f application.yaml
# Esperar que Argo CD reconcilie (auto-sync activo)
sleep 10
kubectl get deployment podinfo -n podinfo -o jsonpath='{.spec.replicas}{"\n"}'
# -> 3
```

### 5.7 Ejecutar la validación

```bash
cd ..
bash tests/validate.sh
```

## 6. Resultado esperado

- Cluster `kind` llamado `argo-04-01` corriendo.
- Namespace `argocd` con todos los pods de Argo CD en `Ready`.
- Namespace `podinfo` con el Deployment `podinfo` en 3 réplicas.
- `helm list -n podinfo` vacío (ésta es la observación de la lección).
- La Application `podinfo` en estado `Synced` + `Healthy`.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: Deployment `podinfo` con 3 réplicas y la imagen `ghcr.io/stefanprodan/podinfo:6.7.1`.
- [ ] **Calidad**: la Application usa `valueFiles` o `values` (no todo por `parameters`).
- [ ] **Correctitud GitOps**: `helm list -n podinfo` sigue vacío — demuestra que entiendes que Argo CD no instala releases de Helm.
- [ ] **Reproducibilidad**: `kind delete cluster --name argo-04-01` + volver a correr los pasos reproduce todo.

## 8. Validación

```bash
bash tests/validate.sh
```

El script hace checks aislados; cada uno reporta PASS/FAIL. Si falta alguna herramienta imprescindible, hace SKIP y sale 0 (para no romper CI de materiales).

## 9. Preguntas de reflexión

1. ¿Por qué `helm list -n podinfo` sale vacío si evidentemente la app corre? ¿Qué objeto crearía `helm install` que Argo CD **no** crea?
2. Si quisieras ejecutar una migración de DB antes de desplegar, el chart ofrece un hook `pre-install`. ¿Funcionaría tal cual bajo Argo CD? ¿Cuál es la alternativa idiomática?
3. ¿Qué pasaría si fijaras `targetRevision: HEAD`? ¿Tiene sentido con un chart HTTP?
4. ¿Qué precede en caso de conflicto: `values` inline, `valueFiles` o `parameters`?
5. Si borras la Application con `kubectl delete application podinfo -n argocd`, ¿qué pasa con el namespace `podinfo` y por qué juega aquí el `finalizer`?

## 10. Extensiones

- **E1** — Añade un `AnalysisRun` manual: antes de pasar `replicaCount` a 3, ejecuta `argocd app diff` desde la CLI y predice qué cambiará.
- **E2** — Cambia el chart por `bitnami/nginx` y adapta los `values`. Observa que la operativa es idéntica.
- **E3** — Convierte la Application en **multi-source** (actividad 02 lo cubre).

## 11. Limpieza

```bash
cd starter/
bash 99-cleanup.sh
```

Esto elimina el cluster `kind` y limpia `/tmp/argo-04-01/`.
