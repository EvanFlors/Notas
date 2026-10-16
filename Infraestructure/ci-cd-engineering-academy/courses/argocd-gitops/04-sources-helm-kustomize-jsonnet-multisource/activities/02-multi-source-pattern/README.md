# Actividad 02 — Patrón multi-source

## 1. Identificación

- **ID:** `argo-04-02-multi-source-pattern`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `04-sources-helm-kustomize-jsonnet-multisource`
- **Dificultad:** intermediate
- **Duración estimada:** 75–90 min
- **Tipo:** independent

## 2. Contexto

En proyectos reales el chart "upstream" que te interesa (p. ej. `ingress-nginx`, `cert-manager`, `prometheus-community/kube-prometheus-stack`, `bitnami/postgresql`) vive en el repo de sus mantenedores. Tu `values.yaml` propio vive en **tu repo de infra**. Forkear el chart es deuda; crear un wrapper que lo importe como dependency es indirección. **Multi-source** (GA desde Argo CD 2.6) permite declarar los dos sources en una sola `Application` y referenciar archivos del segundo desde el primero.

Tu misión: diseñar y validar una Application multi-source. El solution se te da **a ciegas** — no lo mires hasta terminar.

## 3. Objetivos

- Declarar `spec.sources` con dos entradas (chart + repo de values).
- Usar `ref:` y `$values` correctamente.
- Elegir `targetRevision` para **cada** source y justificarlo.
- Validar la configuración sin necesariamente desplegarla.

## 4. Prerrequisitos

- Haber completado `argo-04-01` (idealmente aún con el cluster `kind` operativo — no es obligatorio).
- `helm` y `python3` instalados (para validaciones locales).
- Opcional: cluster con Argo CD ≥ 2.6 corriendo para probar la Application viva.

**Costos**: ninguno.

## 5. Instrucciones

> No reveles la solución. Si te atascas, consulta `theory/lesson.md` sección 7 y `examples/03-multi-source-chart-plus-values/`.

### 5.1 Elige un chart upstream

Para esta actividad usa **`podinfo`** (`https://stefanprodan.github.io/podinfo`, chart `podinfo`, versión `6.7.1`). Es el mismo que usaste en la actividad 01, lo que te permite comparar.

### 5.2 Prepara tu "repo de values"

En esta actividad, simulamos el segundo source **con este mismo repositorio**. Usa:

- `repoURL`: cualquier repo público que controles (o deja el placeholder documental).
- `ref`: `values`.
- Archivo de values: `apps/podinfo/values.yaml` (ruta ilustrativa dentro del repo de values).

### 5.3 Escribe la Application

Completa `starter/application.yaml`. Debe cumplir:

1. Dos entradas en `spec.sources`.
2. La primera entrada: chart `podinfo` v`6.7.1`, con `helm.releaseName: podinfo` y `helm.valueFiles` referenciando `$values/apps/podinfo/values.yaml`.
3. La segunda entrada: tu repo de values con `ref: values` y `targetRevision: main`.
4. `destination.namespace: podinfo` y `destination.server: https://kubernetes.default.svc`.
5. `syncPolicy.automated` con `prune` y `selfHeal`.

### 5.4 Escribe el `values.yaml`

Completa `starter/values.yaml` con **al menos**:

- `replicaCount: 2`
- `hpa.enabled: false`
- Un `resources.requests` y `resources.limits` sensatos.

### 5.5 Validación local

```bash
bash tests/validate.sh
```

El test verifica estructura, no despliegue — está diseñado para funcionar incluso sin cluster.

### 5.6 (Opcional) Despliegue real

Si tienes el cluster de la actividad 01 vivo:

```bash
# Asegúrate de borrar la Application anterior para no colisionar
kubectl --context kind-argo-04-01 -n argocd delete application podinfo --ignore-not-found
# Sube este repo (o tu fork) a algún lado accesible y ajusta repoURL del segundo source
kubectl --context kind-argo-04-01 -n argocd apply -f starter/application.yaml
```

## 6. Resultado esperado

- `starter/application.yaml` con dos sources, `ref: values`, y referencia `$values/...` consistente.
- `starter/values.yaml` con `replicaCount: 2` y `hpa.enabled: false`.
- `bash tests/validate.sh` termina con `0 failed`.
- Nota corta (en `starter/decisions.md`) explicando qué `targetRevision` usaste para cada source y por qué.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: `starter/application.yaml` es YAML válido con `spec.sources` (plural).
- [ ] **Correctitud del patrón**: hay exactamente un source con `ref:` y la referencia `$values/...` apunta a él.
- [ ] **Reproducibilidad**: `targetRevision` del chart está **pinneado** (no `HEAD`).
- [ ] **Justificación**: `decisions.md` razona por qué el chart va pinneado y los values vienen de una branch mutable.

## 8. Validación

```bash
bash tests/validate.sh
```

Checks estructurales:

1. `starter/application.yaml` parsea como YAML.
2. Tiene `spec.sources` como lista con ≥ 2 elementos.
3. Exactamente un source trae `ref:`.
4. Al menos un `valueFiles` referencia `$<ref-name>/`.
5. Al menos un `source.targetRevision` que es un chart es un SemVer pinneado (no `HEAD`).
6. `starter/values.yaml` parsea y contiene `replicaCount` y `hpa`.

## 9. Preguntas de reflexión

1. ¿Por qué el `targetRevision` del chart debería ser SemVer y el del repo de values puede ser `main`?
2. Si usaras `HEAD` en ambos, ¿qué pierdes?
3. ¿Qué pasa si cambias `ref: values` a `ref: v` sin actualizar `$values/...`?
4. En multi-source, ¿puedes tener dos sources de tipo chart Helm (dos charts en la misma Application)? Prueba la hipótesis.
5. Comparado con un *wrapper chart* que importa el upstream como dependency, ¿qué pierdes y qué ganas con multi-source?

## 10. Extensiones

- **E1** — Promueve el ambiente cambiando `targetRevision` del repo de values a un tag (`v2026.10.1`). Observa el diff.
- **E2** — Añade un tercer source con otro `ref:` para separar certificados (TLS) del `values.yaml` general.
- **E3** — Reproduce localmente la salida con `helm template podinfo ./podinfo -f values.yaml` y compárala con `argocd app manifests`.

## 11. Limpieza

```bash
# Si desplegaste contra el cluster de la actividad 01:
kubectl --context kind-argo-04-01 -n argocd delete application podinfo-multi --ignore-not-found

# Scratch local:
rm -rf /tmp/argo-04-02
```
