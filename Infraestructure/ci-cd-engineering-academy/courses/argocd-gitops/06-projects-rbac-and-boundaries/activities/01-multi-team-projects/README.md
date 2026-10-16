# Actividad 01 — Multi-team projects con boundaries verificados

## 1. Identificación

- **ID:** `argo-06-01-multi-team-projects`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `06-projects-rbac-and-boundaries`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Dos equipos (`team-payments` y `team-checkout`) comparten el mismo cluster y la misma instalación de Argo CD. **Nadie debe poder desplegar en los namespaces del otro, ni por accidente ni a propósito.**

En esta actividad construyes esos dos `AppProject`, los Applications de ejemplo, y demuestras — con un intento *fallido explícito* — que los boundaries funcionan. Es un lab guiado paso a paso.

## 3. Objetivos

Al terminar deberías poder:

- Crear un `AppProject` con `sourceRepos`, `destinations`, `clusterResourceWhitelist` y `namespaceResourceWhitelist` acotados.
- Explicar qué significa el error `is not permitted in project`.
- Verificar un boundary intentando violarlo y leer la condición de la Application.
- Diferenciar un boundary del `AppProject` de un `RoleBinding` nativo de K8s.

## 4. Prerrequisitos

- **Conocimientos:** `argo-01`, `argo-02`, `argo-03` completados. Módulo `k8s-12` del curso de Kubernetes.
- **Software:** `kind` ≥ 0.20, `kubectl` ≥ 1.28, `argocd` CLI ≥ 2.9, `bash`, `jq`.
- **Infraestructura:** un cluster `kind` con Argo CD instalado y accesible (`argocd login`).
- **Costos:** 0 €. Todo local.

Si no tienes el cluster, los scripts **skipean con mensaje claro** en lugar de romper.

## 5. Instrucciones

### 5.1 Preparar el entorno de trabajo

```bash
mkdir -p /tmp/argo-06-01
cp -r <ruta-de-la-actividad>/starter/* /tmp/argo-06-01/
cd /tmp/argo-06-01
```

### 5.2 Revisar los manifests del starter

Hay dos `AppProject` **incompletos** y dos `Application`. Tu trabajo:

1. Edita `project-team-payments.yaml` para que:
   - Solo acepte el repo `https://github.com/argoproj/argocd-example-apps.git`.
   - Solo permita destinos en `payments-*` del in-cluster.
   - Permita crear `Namespace` (cluster-scoped) y todo lo necesario namespace-scoped.
   - Prohíba al equipo crear `ResourceQuota` y `LimitRange` (que lo haga Platform).
2. Edita `project-team-checkout.yaml` para que:
   - Mismo repo whitelisteado.
   - Solo destinos en `checkout-*`.
   - Sin permiso de `Namespace` cluster-scoped (platform crea los namespaces de checkout).

### 5.3 Aplicar y crear las Applications

```bash
kubectl apply -f project-team-payments.yaml
kubectl apply -f project-team-checkout.yaml
kubectl apply -f app-payments-good.yaml      # debe sincronizar OK
kubectl apply -f app-checkout-crossing.yaml  # debe FALLAR con 'not permitted'
```

### 5.4 Observar el rechazo

```bash
kubectl -n argocd get application checkout-crossing -o yaml \
  | yq '.status.conditions'
```

Debes ver una condición cuyo `message` contiene `is not permitted in project`.

### 5.5 Validar

```bash
bash tests/validate.sh
```

El script verifica:

- Que ambos `AppProject` existen y tienen `sourceRepos` no vacío y distinto de `['*']`.
- Que `team-payments.destinations` restringe namespace a `payments-*`.
- Que `team-checkout.destinations` restringe namespace a `checkout-*`.
- Que la Application `payments-good` existe y su project es `team-payments`.
- Que la Application `checkout-crossing` tiene al menos una condición cuyo mensaje contiene `not permitted`.

## 6. Resultado esperado

- Dos `AppProject` sanos, acotados, en el namespace `argocd`.
- Una Application sincronizada (`payments-good`).
- Una Application en estado inválido con condición `not permitted` (`checkout-crossing`).
- `tests/validate.sh` termina con `OK`.

## 7. Criterios de aceptación

- [ ] `team-payments.sourceRepos` no contiene `*`.
- [ ] `team-payments.destinations[].namespace` es `payments-*` (no `*`).
- [ ] `team-checkout.destinations[].namespace` es `checkout-*`.
- [ ] `team-checkout.clusterResourceWhitelist` **no** permite crear `Namespace` (ejemplo intencional de responsabilidad delegada a Platform).
- [ ] La Application `checkout-crossing` tiene una condición con `not permitted`.
- [ ] La Application `payments-good` reporta `Synced` o al menos `OutOfSync` **sin** error de project.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

Responde en `/tmp/argo-06-01/REFLECTION.md`:

1. ¿Qué pasaría si en `team-payments.destinations` pones `namespace: '*'`? Pruébalo (recuerda deshacerlo) y describe el comportamiento.
2. ¿Qué cambia si eliminas la entrada `kind: Namespace` del `clusterResourceWhitelist` y la Application tiene `SyncOption: CreateNamespace=true`?
3. Si un atacante tomara control de la cuenta de un developer del equipo payments y creara una Application en el project `default`, ¿los boundaries de `team-payments` seguirían protegiendo a checkout?
4. ¿Dónde quedaría registrada esta auditoría en Argo CD si quisieras investigar un intento? (`argocd admin audit`, `audit logs del server`, eventos de la Application…)

## 10. Extensiones

- **E1** — Añade un tercer project `team-shared` que *sí* comparta el namespace `shared-tools` con ambos equipos. Verifica que las policies permiten lectura pero no sync.
- **E2** — Añade `signatureKeys` al project `team-payments` y verifica que una Application cuyo commit no está firmado por esa key es rechazada.
- **E3** — Configura `permitOnlyProjectScopedClusters: true` y añade un segundo cluster "fake" (otro kind). Observa que `team-payments` no puede desplegar ahí aunque figure en Argo CD.

## 11. Limpieza

```bash
bash tests/cleanup.sh
rm -rf /tmp/argo-06-01
```
