# Lesson — Sources en Argo CD

> 12 secciones. La idea que atraviesa todo el módulo: **Argo CD no "corre" Helm ni Kustomize; los renderiza y aplica el resultado**. Interiorizarlo evita horas de confusión.

---

## 1. El modelo mental: render → diff → apply

El `application-controller` reconcilia *estado deseado* contra *estado actual*. El *estado deseado* es siempre **YAML plano de Kubernetes**. Nunca es "un release de Helm" ni "un overlay de Kustomize" — son herramientas para **producir** ese YAML.

Flujo canónico, para cualquier source:

```
┌─────────────────┐    git clone/pull    ┌──────────────────┐
│  Repos Git /    │ ───────────────────► │  repo-server     │
│  OCI charts     │                      │  render pipeline │
└─────────────────┘                      └────────┬─────────┘
                                                  │  manifests planos (YAML)
                                                  ▼
                                         ┌────────────────────┐
                                         │ application-ctrl   │
                                         │  diff vs cluster   │
                                         │  apply (SSA/CSA)   │
                                         └────────────────────┘
```

El `repo-server` corre `helm template`, `kustomize build`, `jsonnet` o el plugin configurado. Si tu herramienta no es nativa, se envuelve en un **Config Management Plugin (CMP)**. El resultado es siempre el mismo: una secuencia de documentos YAML que el controller compara y aplica.

Consecuencia inmediata: **todo lo que la herramienta hacía "aparte" del YAML — gestión de ownership propia, bases de datos locales, hooks activos — queda fuera**.

---

## 2. Source más simple: plain YAML / directory

Lo más minimalista. `spec.source` apunta a un directorio con `.yaml`/`.yml`/`.json` y Argo CD aplica lo que encuentre.

```yaml
spec:
  source:
    repoURL: https://github.com/acme/infra
    path: envs/dev/raw
    targetRevision: main
    directory:
      recurse: true          # bajar a subdirectorios
      include: '**/*.yaml'   # glob
      exclude: 'skip/**'
      jsonnet:               # opcional, si hay .jsonnet aquí dentro
        tlas:
          - name: env
            value: dev
```

Puntos clave:

- `recurse: false` por defecto. Si tu árbol tiene subcarpetas, se olvidan silenciosamente — bug común.
- `include/exclude` son globs relativos a `path`.
- Un directorio **mezcla** manifests: todos se consideran parte de la misma Application. Si no quieres que algo se despliegue, muévelo o excluyelo.

Cuándo usarlo: configuraciones manifiestamente estáticas (CRDs upstream, policies de admisión, un `Namespace` + `NetworkPolicy`). Para apps reales, casi siempre quieres Helm o Kustomize.

---

## 3. Helm como source: los campos del CR

Argo CD soporta charts tanto desde **repos Git** (`chart/` como path) como desde **repos Helm clásicos** (HTTP) o **registries OCI** (`oci://ghcr.io/acme/charts`).

```yaml
spec:
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 18.1.14      # SemVer del chart
    helm:
      releaseName: web           # define el "release" al renderizar
      valueFiles:
        - values-prod.yaml       # resuelto RELATIVO al chart
      values: |                  # YAML inline — útil, menos revisable
        service:
          type: ClusterIP
      parameters:
        - name: image.tag
          value: "1.27.3"
        - name: replicaCount
          value: "3"
        - forceString: true      # fuerza string aunque parezca número
          name: podAnnotations.build
          value: "20261013"
      fileParameters:
        - name: tls.cert
          path: certs/tls.crt    # lee el archivo y pasa el contenido
      passCredentials: false     # heredar creds del repo (OCI con auth)
```

Equivalencias útiles para quien viene de la CLI de Helm:

| CLI de Helm                           | Argo CD                              |
|---------------------------------------|--------------------------------------|
| `-f values.yaml`                      | `helm.valueFiles: ["values.yaml"]`   |
| `--set key=value`                     | `helm.parameters`                    |
| `--set-file key=path`                 | `helm.fileParameters`                |
| `--set-string key=val`                | `parameters[].forceString: true`     |
| `--release-name foo`                  | `helm.releaseName: foo`              |
| `--atomic`, `--wait`, `--timeout`     | **no aplican** — ver sección 5       |

> **`values` inline vs `valueFiles`.** El bloque inline es tentador y vive dentro del `Application` (que a su vez vive en Git). Es "GitOps-aceptable", pero mezcla configuración de la aplicación con configuración del CR de Argo CD. En equipos reales, preferir `valueFiles` o multi-source (sección 7).

---

## 4. Cómo Argo CD renderiza Helm (y por qué importa)

Argo CD **nunca** ejecuta `helm install` ni `helm upgrade`. Lo que hace el `repo-server` es:

```
helm template <releaseName> <chart> \
  -f values.yaml \
  --set key=value \
  --namespace <destination.namespace>
```

Y entrega el YAML resultante al `application-controller`, que:

1. Diff contra el cluster.
2. `kubectl apply` (Client-Side Apply por defecto, Server-Side Apply si se activa `ServerSideApply=true` en `syncOptions`).

**Lo que esto implica**, en orden de impacto operativo:

1. **No existe el Secret `sh.helm.release.v1.<name>.v<N>`**. Es el objeto donde Helm guarda metadata del release. Argo CD no lo crea. `helm list -n <ns>` **no verá nada**. Esto rompe cualquier integración o script que asume "si Helm no ve el release, no está instalado".
2. **Rollback no es `helm rollback`**. Es `argocd app rollback` (que apunta la Application a una revisión Git anterior y re-sincroniza) o `git revert` en el repo.
3. **`helm test` no se ejecuta automáticamente**. Si tu chart trae `templates/tests/*.yaml` con `helm.sh/hook: test`, esos manifests son renderizados pero quedan huérfanos (y pueden tratar de aplicarse como recursos normales si no están tagueados correctamente).
4. **Flags de la CLI** (`--atomic`, `--wait`, `--timeout`) **no tienen equivalente directo**. Lo más cercano:
   - "atomic" → `syncPolicy.retry` + `selfHeal: true`.
   - "wait" → Argo CD evalúa health status; si una Deployment no se vuelve Healthy, la Application queda `Progressing`.
   - "timeout" → `syncPolicy.retry.backoff.maxDuration`.
5. **CRDs** del chart deben estar en `templates/` o en `crds/` — Argo CD aplica ambas, pero no entiende el flag `--skip-crds` de Helm; para ignorarlos usa `syncOptions: [SkipDryRunOnMissingResource=true]` combinado con un ordering explícito.

---

## 5. Hooks de Helm bajo Argo CD: lo que funciona y lo que no

Un chart Helm "normal" puede traer hooks:

```yaml
# templates/migrate-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    "helm.sh/hook": "pre-install,pre-upgrade"
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
```

Qué pasa cuando ese chart se usa como source de Argo CD:

- Argo CD reconoce las anotaciones `helm.sh/hook` y las **traduce internamente** a sus propias fases:
  - `pre-install` + `pre-upgrade` → `PreSync`.
  - `post-install` + `post-upgrade` → `PostSync`.
  - `test` → **no se ejecuta** (no hay fase equivalente).
- Los **weights** se mapean a `argocd.argoproj.io/sync-wave` con el mismo número.
- Los **delete-policies** se mapean a `argocd.argoproj.io/hook-delete-policy`, pero **no todos**: `before-hook-creation` y `hook-succeeded` sí; `hook-failed` tiene semántica distinta.
- Hooks sin equivalente (`crd-install` en Helm 2, `rollback` en Helm 3) se **ignoran silenciosamente**.

> **Regla práctica.** Si el chart es tuyo, no uses hooks de Helm; usa directamente anotaciones nativas de Argo CD:
> ```yaml
> metadata:
>   annotations:
>     argocd.argoproj.io/hook: PreSync
>     argocd.argoproj.io/sync-wave: "-5"
>     argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
> ```
> Si el chart viene de upstream y usa hooks, inspecciona qué fase mapea Argo CD y verifica en un ambiente de staging *antes* de confiar en migraciones críticas.

---

## 6. Kustomize como source

Kustomize es nativo. Si `path` contiene un `kustomization.yaml`, Argo CD corre `kustomize build` y aplica el resultado.

```yaml
spec:
  source:
    repoURL: https://github.com/acme/infra
    path: envs/dev
    targetRevision: main
    kustomize:
      namePrefix: dev-
      nameSuffix: -v2
      images:
        - ghcr.io/acme/api:1.4.2      # reemplaza image completo
        - name: redis
          newName: redis
          newTag: 7.4.1-alpine
      commonLabels:
        app.kubernetes.io/env: dev
      commonAnnotations:
        argocd.argoproj.io/tracking-id: dev-api
      replicas:
        - name: api
          count: 3
      patches:
        - target: {kind: Deployment, name: api}
          patch: |
            - op: add
              path: /spec/template/spec/nodeSelector
              value: {role: workload}
      components:
        - ../../components/network-policy
      forceCommonLabels: false
      forceCommonAnnotations: false
```

Notas finas:

- **`images:`** admite dos formas. La forma string (`"image:tag"`) sólo funciona si el `deployment` referencia ese `image` tal cual. La forma objeto (`{name, newName, newTag}`) es más robusta.
- **`commonLabels`** se añade al selector del Deployment, lo cual puede romper deployments existentes (los selectors son inmutables). `forceCommonLabels: true` lo requiere explícitamente. Peligroso.
- Los `patches` siguen la sintaxis estándar de Kustomize (JSON Patch RFC 6902 o Strategic Merge).
- **`components`** permite composición horizontal — útil para "añadir Istio sidecar a este overlay".

Kustomize no tiene concepto de "release" ni "hooks" propios; se lleva mejor con Argo CD que Helm.

---

## 7. Multi-source Applications

Problema real: quieres consumir un **chart upstream** (p. ej. `bitnami/postgresql`) pero tu `values.yaml` vive en tu repo privado, no en el repo del chart. Antes de multi-source había tres caminos malos:

1. Forkear el chart (deuda de mantenimiento eterna).
2. Crear un *wrapper chart* que importe el upstream como dependency (indirección fea).
3. Guardar los values como `source.helm.values` inline (acopla config a la Application).

**Multi-source** (GA desde Argo CD 2.6) permite declarar múltiples sources, uno de los cuales lleva `ref:` para que otro lo referencie:

```yaml
spec:
  sources:
    # 1. El chart upstream
    - repoURL: https://charts.bitnami.com/bitnami
      chart: postgresql
      targetRevision: 16.0.3
      helm:
        releaseName: pg
        valueFiles:
          - $values/apps/postgresql/values.yaml   # ← viene del otro source

    # 2. El repo con los values propios
    - repoURL: https://github.com/acme/infra
      targetRevision: main
      ref: values                                  # ← alias
```

Puntos a cuidar:

- El source con `ref:` **no genera manifests por sí mismo**; es solo un contenedor de archivos a referenciar.
- `$values` es el nombre del `ref`. Puedes elegir cualquier identificador.
- Hay **dos `targetRevision` que seguir** ahora: el del chart (semver, inmutable) y el del repo de values (branch mutable). La promoción entre ambientes puede ser por branch del repo de values.
- Argo CD UI muestra ambos sources; `argocd app sync` dispara reconciliación de los dos.
- Multi-source **no** reemplaza wrapper charts en todos los casos: si necesitas cambiar `templates/`, sigue necesitando wrapper. Multi-source resuelve solo "chart intacto + values propios".

---

## 8. Jsonnet (vista rápida)

Jsonnet se soporta nativo cuando el `path` contiene un `.jsonnet` o `.libsonnet`:

```yaml
spec:
  source:
    directory:
      jsonnet:
        extVars:
          - name: env
            value: prod
        tlas:
          - name: replicas
            value: "5"
            code: true     # evaluar como código, no string
        libs:
          - vendor
```

- `extVars` = `--ext-str`; `tlas` = `--tla-str`/`--tla-code`.
- `libs` apunta a carpetas de librerías (`vendor/` de jsonnet-bundler).
- Jsonnet era popular hacia 2019 (Grafana, Databricks). En 2026, para proyectos nuevos la recomendación es **no introducirlo** salvo que ya exista base de código Jsonnet.

Alternativa moderna comparable: **CUE** o **cdk8s**, que requieren CMP.

---

## 9. Config Management Plugins (CMPs)

Para herramientas no soportadas nativamente (`cdk8s`, `cue`, `tanka`, `helmfile`, scripts bash propios) se usa un **CMP**. Dos esquemas:

- **Sidecar en el `repo-server`** — el enfoque recomendado desde 2023. Un contenedor adicional expone un socket y responde "¿este path es tuyo?" + "renderiza este path".
- **ConfigManagementPlugin en `argocd-cm`** (legacy, deprecated) — comando configurado globalmente.

Esqueleto de `plugin.yaml` para un sidecar:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ConfigManagementPlugin
metadata:
  name: helmfile
spec:
  version: v1.0
  discover:
    find:
      command: [sh, -c, "find . -name helmfile.yaml -maxdepth 2"]
  generate:
    command: [sh, -c, "helmfile template"]
```

Costo del CMP:

- Imagen custom del `repo-server` o sidecar que mantengas.
- El tiempo de render se añade al reconcile loop → latencia extra.
- Debugging difícil (logs del sidecar vs logs del controller).

Úsalo cuando el beneficio supera el costo: por ejemplo, si tu organización ya está profundamente invertida en Helmfile para múltiples equipos y migrar a Helm "puro" o a ApplicationSet sería más costoso que un CMP.

---

## 10. Elegir source: criterios

| Situación                                            | Source recomendado                     |
|------------------------------------------------------|-----------------------------------------|
| Manifests estáticos (CRDs, policies, Namespaces)     | **directory** (`source.directory`)      |
| App propia con pocas variantes por entorno           | **Kustomize** (overlays por env)        |
| Chart upstream (Bitnami, Prometheus, Ingress)        | **Helm** + `valueFiles`                 |
| Chart upstream + values propios en otro repo         | **Multi-source**                        |
| App propia con muchísimos entornos / templating rico | **Helm propio** (si ya hay cultura)     |
| Herramienta exótica, imposible migrar                | **CMP**                                 |

Un pattern explícitamente **a evitar**: múltiples sources Helm en una Application (no soportado tal cual; cada "chart" debería ser una Application diferente).

---

## 11. Operación: comandos esenciales

Con la CLI de Argo CD:

```bash
# Ver el manifest renderizado SIN aplicarlo
argocd app manifests my-app

# Diff contra el cluster
argocd app diff my-app

# Forzar re-render del repo-server (bust cache)
argocd app get my-app --hard-refresh

# Sync con dry-run (muestra qué haría)
argocd app sync my-app --dry-run

# Sync forzado (ignora window / project policy — con cuidado)
argocd app sync my-app --force

# Para Helm específicamente, inspeccionar los values efectivos
argocd app get my-app -o yaml | yq '.spec.source.helm'
```

Y la equivalencia útil al debuggear:

```bash
# "¿Qué YAML está mandando mi chart?" sin pasar por Argo
helm template my-app <chart> -f values-prod.yaml \
  --namespace my-ns \
  --release-name my-app > /tmp/rendered.yaml
diff <(argocd app manifests my-app) /tmp/rendered.yaml
```

Si ambos difieren, Argo CD probablemente está pasando `parameters` adicionales — revisa `spec.source.helm.parameters`.

---

## 12. Errores comunes y cómo evitarlos

1. **`targetRevision: HEAD` en un chart OCI/HTTP**. En Helm no significa "última versión" — significa "HEAD del Git subyacente", lo cual no aplica. Para charts OCI o HTTP, siempre SemVer explícito. Para charts en Git, prefiere tag o commit.
2. **Mezclar `values` inline + `valueFiles` + `parameters`**. El merge order es: `valueFiles` (en orden) → `values` inline → `parameters`. Si no lo tienes claro, un `argocd app manifests` lo revela — pero el bug ya está en el ambiente.
3. **`forceCommonLabels: true` en Kustomize sobre una Deployment ya desplegada**. El selector es inmutable; Argo CD intentará recrear la Deployment, lo cual puede fallar con un error oscuro ("field is immutable").
4. **Confiar en `helm test` para humo post-deploy**. No corre. Reemplázalo con un `Job` + `argocd.argoproj.io/hook: PostSync`.
5. **Hook de Helm con `delete-policy: hook-failed`**. No se traduce. El Job queda en el cluster hasta que lo borras a mano.
6. **Dos sources Helm en la misma Application**. No soportado — divide en dos Applications.
7. **`$values/path/to/file.yaml` sin `ref:` definido**. Error silencioso en algunas versiones. Verifica siempre con `argocd app get`.
8. **CMP sin recursos limitados**. El sidecar puede OOM-killear al `repo-server`. Pon `resources.limits` desde el día uno.
9. **Multi-source con dos branches mutables**. Si tanto `targetRevision` del chart como del repo de values son `main`, perdiste la reproducibilidad. Al menos uno de los dos debe ser inmutable (tag o commit).
10. **Esperar que `helm list -n X` muestre lo que Argo CD aplicó**. No lo hará. Si necesitas inventario, usa `argocd app list` o `kubectl get application -A`.

---

## Resumen de una página

- **Render → diff → apply**: Argo CD no instala Helm releases; renderiza y aplica.
- **Helm**: `valueFiles` para config revisable, `parameters` para `--set`, nunca esperes `helm list`.
- **Kustomize**: cómodo, nativo, cuidado con `commonLabels` sobre deployments existentes.
- **Multi-source**: upstream chart + values en otro repo, sin forks ni wrappers.
- **CMPs**: puerta de escape; costo real, úsalos solo si lo compensa.
- **Hooks de Helm**: parciales. Para operaciones críticas usa anotaciones nativas de Argo CD.
