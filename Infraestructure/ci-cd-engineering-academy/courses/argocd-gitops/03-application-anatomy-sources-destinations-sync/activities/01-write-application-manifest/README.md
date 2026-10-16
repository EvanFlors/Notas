# Actividad 01 — Escribir un manifiesto `Application` para el capstone

## 1. Identificación

- **ID:** `argo-03-01-write-application-manifest`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-03-application-anatomy-sources-destinations-sync`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** guided-lab

## 2. Contexto

Toca escribir *tu* primer `Application` CR, no copiarlo de un tutorial. El manifiesto que produzcas aquí es el que usarás como base para el capstone en los módulos siguientes.

Escenario: tu equipo mantiene una API (`capstone-api`) y la va a desplegar en un cluster `kind` local, en el namespace `capstone-dev`, desde el repo `https://github.com/acme/capstone-infra.git`, carpeta `envs/dev/api/`. Dev auto-sincroniza, prune activo, selfHeal activo, y el `Deployment` tiene un HPA.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `Application` CR sintácticamente válido y semánticamente correcto.
- Justificar la elección de `targetRevision` (branch, no `HEAD`).
- Añadir `ignoreDifferences` para `/spec/replicas` **y** `RespectIgnoreDifferences=true`.
- Validar el manifiesto con `kubectl --dry-run=client` (siempre) y server-side (si hay cluster).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` del módulo.
- `kubectl` instalado.
- Editor de texto.
- Opcional: `kind` + Argo CD del módulo `argo-02` para validación server-side.
- Opcional: `kubeconform` para validación offline del schema.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar scratch dir

```bash
rm -rf /tmp/argo-03-01 && mkdir -p /tmp/argo-03-01
cp courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/activities/01-write-application-manifest/starter/application.yaml /tmp/argo-03-01/application.yaml
cd /tmp/argo-03-01
```

Abre `application.yaml` en tu editor. Verás un esqueleto con `TODO:` en los campos que debes completar.

### 5.2 Completar el `source`

Reemplaza los `TODO:` del bloque `source` con:

- `repoURL`: `https://github.com/acme/capstone-infra.git`
- `path`: `envs/dev/api`
- `targetRevision`: una **branch**. **No** uses `HEAD`. Para dev, `main` es razonable.

> ¿Por qué `main` y no `HEAD`? Repasa `theory/lesson.md` §4.2 si no lo tienes claro.

### 5.3 Completar el `destination`

- `server`: `https://kubernetes.default.svc` (cluster local, in-cluster).
- `namespace`: `capstone-dev`.

### 5.4 Completar el `syncPolicy`

- `automated.prune: true`
- `automated.selfHeal: true`
- `syncOptions` debe incluir **al menos**:
  - `CreateNamespace=true`
  - `ServerSideApply=true`
  - `RespectIgnoreDifferences=true`

### 5.5 Añadir `ignoreDifferences`

Para que el HPA pueda escalar `capstone-api` sin que Argo CD lo pelee:

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    name: capstone-api
    jsonPointers:
      - /spec/replicas
```

### 5.6 Validar

```bash
# Validación client-side (siempre disponible)
kubectl apply --dry-run=client -f /tmp/argo-03-01/application.yaml

# Si tienes kind + Argo CD del módulo argo-02:
kubectl apply --dry-run=server -f /tmp/argo-03-01/application.yaml

# Validador oficial de la actividad:
bash courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/activities/01-write-application-manifest/tests/validate.sh /tmp/argo-03-01/application.yaml
```

Debe terminar con `OK: actividad completada correctamente.`

## 6. Resultado esperado

- `/tmp/argo-03-01/application.yaml` existe, sin ningún `TODO:` restante.
- `kubectl --dry-run=client` lo acepta.
- `tests/validate.sh` imprime `OK` final.

## 7. Criterios de aceptación

- [ ] `apiVersion`, `kind`, `metadata.name`, `metadata.namespace: argocd` presentes y correctos.
- [ ] `targetRevision` no es `HEAD`.
- [ ] `syncPolicy.automated.prune` y `selfHeal` activos.
- [ ] `syncOptions` incluye `CreateNamespace=true`, `ServerSideApply=true`, `RespectIgnoreDifferences=true`.
- [ ] `ignoreDifferences` incluye `/spec/replicas` sobre `apps/Deployment`.
- [ ] `destination.server` y `destination.namespace` correctos.
- [ ] `validate.sh` termina en `OK`.

## 8. Validación

```bash
bash courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/activities/01-write-application-manifest/tests/validate.sh /tmp/argo-03-01/application.yaml
```

El script verifica estructura, campos obligatorios, ausencia de `HEAD`, presencia de `RespectIgnoreDifferences=true` y `ignoreDifferences` sobre `/spec/replicas`, y hace `kubectl --dry-run=client` si `kubectl` está disponible.

## 9. Preguntas de reflexión

1. Si cambias `targetRevision: main` por `targetRevision: v1.4.2`, ¿qué cambia operacionalmente?
2. ¿Qué pasaría si quitaras `RespectIgnoreDifferences=true` pero dejaras `ignoreDifferences`? ¿Qué verías en la UI y qué ocurriría en el cluster?
3. ¿Por qué `metadata.namespace: argocd` y no `capstone-dev`?
4. Si `destination.namespace` fuera `capstone-prod` pero el YAML del repo trajera `metadata.namespace: capstone-stg` explícito en un recurso, ¿dónde se aplicaría ese recurso?
5. Para `prod`, ¿cambiarías `syncPolicy.automated`? Justifica.

## 10. Extensiones (opcional)

- **E1** — Añade una segunda entrada en `ignoreDifferences` para ignorar `/metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration` en todos los Deployments.
- **E2** — Añade `spec.info` con un `Runbook` y un `On-call` URL ficticios.
- **E3** — Convierte el manifiesto para `stg` con `targetRevision: release/stg` y `selfHeal: false`. Diff con `diff -u` ambos manifiestos.
- **E4** — Si tienes `kind` + Argo CD: `kubectl apply -f application.yaml` y mira la Application en la UI (`argocd app get`).

## 11. Limpieza

```bash
rm -rf /tmp/argo-03-01
# Si extendiste E4 y creaste la Application real en el cluster:
# kubectl -n argocd delete application capstone-api-dev
```
