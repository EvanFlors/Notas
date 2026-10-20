# Lección — ApplicationSets y Generators

> Nivel intermedio. 12 secciones. Léela entera antes de las actividades.

---

## 1. El problema que resuelve `ApplicationSet`

En `argo-03` creaste **una** `Application` a mano. Con dos ambientes todavía es manejable; con **30 microservicios × 3 ambientes × 5 clusters** no lo es.

El patrón clásico pre-2021 era **"app-of-apps"**: una `Application` cuyo `source` apunta a un directorio con *más* manifests `Application`. Funciona pero:

- Cada nuevo servicio exige escribir y mantener un YAML más.
- Añadir un cluster implica duplicar directorios enteros.
- Los campos compartidos (`project`, `destination.server`, `syncPolicy`) se repiten en N manifests y se desvían con el tiempo (drift documental).

`ApplicationSet` resuelve esto desde dentro de Argo CD: un controller aparte, el **`applicationset-controller`**, lee un CR `ApplicationSet` que combina **generators** (fuentes de datos) + **template** (plantilla parametrizada) y **sintetiza** las `Application` resultantes en el cluster. Si mañana aparece un nuevo folder, un nuevo cluster, o un nuevo PR, la Application correspondiente aparece *sola*; si desaparece, se borra.

**Clave mental:** ApplicationSet no es "una Application grande". Es un **generador** de Applications. Las Applications generadas son recursos reales, visibles con `kubectl get applications -n argocd`, y Argo CD las trata exactamente como las que escribirías a mano.

---

## 2. Arquitectura del `applicationset-controller`

El `applicationset-controller` corre como Deployment separado en el namespace `argocd` (viene con la instalación oficial desde Argo CD 2.3+). Su loop:

1. Lista los `ApplicationSet` en el cluster.
2. Para cada uno, ejecuta sus **generators** y obtiene una lista de "elementos" (cada elemento es un dict de variables).
3. Para cada elemento, renderiza el **template** sustituyendo variables → produce un objeto `Application`.
4. Hace *reconcile* contra las Applications existentes: crea las que faltan, actualiza las que cambiaron, borra las que ya no corresponden (si `syncPolicy.preserveResourcesOnDeletion: false`, el default).

```
            ┌────────────────────────┐
            │ ApplicationSet CR      │
            │  generators: [...]     │
            │  template: {...}       │
            └──────────┬─────────────┘
                       │
                       ▼
            ┌────────────────────────┐
            │ applicationset-ctrl    │
            │  render loop (polling) │
            └──────────┬─────────────┘
                       │ genera N
                       ▼
            ┌────────────────────────┐
            │ Application #1 ... #N  │
            └──────────┬─────────────┘
                       │ reconcilia (otro controller)
                       ▼
                 cluster(s) target
```

El **application-controller** sigue siendo quien hace el `apply` real. El `applicationset-controller` sólo *produce* Applications.

---

## 3. El CR `ApplicationSet` — anatomía mínima

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: envs
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - list:
        elements:
          - env: dev
            revision: HEAD
          - env: stg
            revision: HEAD
  template:
    metadata:
      name: 'myapp-{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/acme/myapp-config
        path: 'envs/{{.env}}'
        targetRevision: '{{.revision}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'myapp-{{.env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Observaciones:

- `goTemplate: true` activa el motor **Go template** (sintaxis `{{.env}}`); sin él, Argo usa el motor viejo **`fasttemplate`** (sintaxis `{{env}}`), que no soporta funciones, condicionales, ni manejo seguro de nulos. **Siempre usa `goTemplate: true` en código nuevo.**
- `goTemplateOptions: ["missingkey=error"]` convierte un typo de variable en un fallo del render, no en un string vacío que ensucia Applications.
- Dentro del `template`, cualquier `string` del `spec` es parametrizable, no sólo `metadata.name`.

---

## 4. Generators (I) — List y Cluster

### 4.1 `list`

El más simple. Enumeras los elementos. Útil para pocos datos muy estables:

```yaml
generators:
  - list:
      elements:
        - cluster: dev-eu
          url: https://1.2.3.4
        - cluster: prod-us
          url: https://5.6.7.8
```

### 4.2 `clusters`

Itera sobre **todos los clusters registrados** en Argo CD (los `Secret` con `argocd.argoproj.io/secret-type: cluster`). Expone variables como `{{.name}}`, `{{.server}}`, `{{.metadata.labels.*}}`.

```yaml
generators:
  - clusters:
      selector:
        matchLabels:
          env: prod
```

Esto genera una Application por cluster `env=prod` sin que tengas que listarlos: cuando añadas un cluster nuevo con esa label, aparece.

**Trampa:** el "in-cluster" (`https://kubernetes.default.svc`) también cuenta. Si no lo quieres, excluye con `selector`.

---

## 5. Generators (II) — Git (directories y files)

### 5.1 `git.directories`

Descubre **subdirectorios** de un path en un repo Git. Es la base del patrón "env-per-folder":

```yaml
generators:
  - git:
      repoURL: https://github.com/acme/myapp-config
      revision: HEAD
      directories:
        - path: 'envs/*'
```

Si en el repo hay `envs/dev/`, `envs/stg/`, `envs/prod/`, obtiene tres elementos. Variables útiles:

- `{{.path.path}}` → `envs/dev`
- `{{.path.basename}}` → `dev`
- `{{.path.segments}}` → `["envs", "dev"]`

Puedes **excluir** con `exclude: true`:

```yaml
directories:
  - path: 'envs/*'
  - path: 'envs/_shared'
    exclude: true
```

### 5.2 `git.files`

Lee **archivos JSON/YAML** del repo y usa su contenido como diccionario de variables:

```yaml
generators:
  - git:
      repoURL: https://github.com/acme/platform-config
      revision: HEAD
      files:
        - path: 'tenants/*/config.yaml'
```

Si `tenants/alpha/config.yaml` tiene `{tenant: alpha, chart: v1.3.2, replicas: 3}`, esas claves son `{{.tenant}}`, `{{.chart}}`, `{{.replicas}}` en el template. **Ideal para catálogos** gestionados por equipos de plataforma.

---

## 6. Generators (III) — Matrix, Merge

### 6.1 `matrix`

**Producto cartesiano** de dos (o más) generators. Útil para "cada app × cada cluster":

```yaml
generators:
  - matrix:
      generators:
        - git:
            repoURL: https://github.com/acme/apps
            directories:
              - path: 'apps/*'
        - clusters:
            selector:
              matchLabels:
                env: prod
```

Si hay 10 apps y 5 clusters prod → 50 Applications. **Este es el momento donde se explota la cosa.** Usa labels de cluster y filtros de directorio con disciplina.

### 6.2 `merge`

Hace **inner-join** de dos generators por una clave común. Útil para enriquecer datos de un generator con metadatos de otro:

```yaml
generators:
  - merge:
      mergeKeys: [cluster]
      generators:
        - clusters: {}
        - list:
            elements:
              - cluster: dev-eu
                tier: free
              - cluster: prod-us
                tier: paid
```

El resultado por cluster lleva su `tier`. Si un cluster no está en el `list`, **se omite** (inner-join).

---

## 7. Generators (IV) — SCM Provider y Pull Request

Ambos requieren credenciales a GitHub/GitLab/Bitbucket (token).

### 7.1 `scmProvider`

Descubre **repos** de una organización por filtros:

```yaml
generators:
  - scmProvider:
      github:
        organization: acme
        tokenRef:
          secretName: github-token
          key: token
      filters:
        - repositoryMatch: ^svc-.*
          pathsExist: [kubernetes/]
```

Genera una Application por cada repo que empiece con `svc-` y contenga un directorio `kubernetes/`. Ideal para plataformas donde "si tu repo tiene `kubernetes/` lo desplegamos".

### 7.2 `pullRequest`

Descubre **PRs abiertos** de un repo y genera una Application por PR, para preview environments:

```yaml
generators:
  - pullRequest:
      github:
        owner: acme
        repo: myapp
        tokenRef:
          secretName: github-token
          key: token
        labels: ['preview']
      requeueAfterSeconds: 60
```

Variables disponibles: `{{.number}}`, `{{.branch}}`, `{{.head_sha}}`, `{{.labels}}`.

Al **cerrar el PR**, el generator deja de emitirlo → la Application se borra → los recursos se purgan (si `syncPolicy.preserveResourcesOnDeletion: false`). Ese es el ciclo de vida del preview env.

---

## 8. El `template` — convertir elementos en Applications

El `template` del `ApplicationSet` es un objeto `Application` casi completo, con placeholders:

```yaml
template:
  metadata:
    name: '{{.name}}-{{.env}}'
    labels:
      env: '{{.env}}'
    annotations:
      notifications.argoproj.io/subscribe.on-sync-failed.slack: '#deploys-{{.env}}'
  spec:
    project: '{{.env}}'
    source:
      repoURL: '{{.repoURL}}'
      path: '{{.path.path}}'
      targetRevision: '{{.revision}}'
      helm:
        valueFiles:
          - 'values-{{.env}}.yaml'
    destination:
      server: '{{.server}}'
      namespace: '{{.name}}-{{.env}}'
    syncPolicy:
      automated: { prune: true, selfHeal: true }
      syncOptions: [CreateNamespace=true, ServerSideApply=true]
```

Con `goTemplate: true` dispones de funciones estándar de Go template y, además, de los helpers de Sprig (`default`, `trimSuffix`, `lower`, `upper`, `trunc`, etc.):

```yaml
name: '{{ .name | lower | trunc 50 | trimSuffix "-" }}'
```

**Nunca** generes nombres >63 chars (límite DNS de labels/namespaces). Usa `trunc 50` + sufijo determinista si vas a concatenar múltiples variables.

### `templatePatch`

Opcional. Te permite **patchar** el template renderizado con un snippet de YAML por elemento (p. ej. añadir `syncPolicy: null` sólo para producción). Más poderoso que condicionales dentro del template, pero menos legible — úsalo cuando el template se vuelve ilegible por tanto `if`.

---

## 9. `goTemplate: true` — por qué sí, siempre

El motor viejo (`fasttemplate`) hace **string replacement textual**:

- No tiene condicionales (`if`), bucles (`range`), ni funciones.
- Si una variable es `nil`, inserta `<nil>`. Si no existe, inserta la cadena literal `{{foo}}`.
- No escapa YAML — un valor con comillas rompe el documento.

Con `goTemplate: true`:

- Dispones de `{{- if eq .env "prod" }} ... {{- end }}`.
- `missingkey=error` convierte en error cualquier referencia a variable inexistente.
- Las funciones de Sprig están disponibles.

En código nuevo, **siempre** `goTemplate: true` + `goTemplateOptions: ["missingkey=error"]`. Añadir esto después de que haya ApplicationSets en producción es traumático (toca cambiar sintaxis de `{{env}}` a `{{.env}}` en todos los templates).

---

## 10. Evitar explosión y bugs comunes

**Explosión combinatoria.** `matrix` sin filtros puede generar cientos de Apps. Síntomas: `applicationset-controller` consumiendo CPU, UI de Argo CD lenta, `kubectl get application` tardando. Mitigaciones:

- Siempre `selector` en `clusters` dentro de un matrix.
- `directories` con `exclude` para carpetas de scaffolding.
- Pre-filtrar en el repo (p. ej. una label `argocd: enabled` dentro del `config.yaml` del tenant).

**Nombres duplicados.** Dos elementos distintos pueden producir el mismo `metadata.name`. El controller rechaza el duplicado y emite un evento. Diseña nombres **determinísticamente únicos** combinando *todas* las dimensiones del generator.

**Borrado accidental.** Si cambias el `path` o el selector del generator y los elementos previos dejan de aparecer, las Applications correspondientes **se borran** (y, por default, también sus recursos en el cluster). Usa `syncPolicy.preserveResourcesOnDeletion: true` cuando quieras conservarlos; usa `ignoreApplicationDifferences` cuando esperes diffs de otros controllers tocando la Application.

**Sync global simultáneo.** Si tu ApplicationSet genera 50 Apps nuevas con `syncPolicy.automated`, se sincronizan todas a la vez. Para evitarlo → **progressive sync**.

---

## 11. Progressive Sync (`strategy: RollingSync`)

Permite ordenar la activación de Applications generadas por "waves" según labels del template:

```yaml
spec:
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - { key: envLabel, operator: In, values: [dev] }
        - matchExpressions:
            - { key: envLabel, operator: In, values: [stg] }
          maxUpdate: 100%
        - matchExpressions:
            - { key: envLabel, operator: In, values: [prod] }
          maxUpdate: 25%
  template:
    metadata:
      labels:
        envLabel: '{{.env}}'
```

El controller sincroniza primero `dev`, cuando están **Healthy** pasa a `stg`, y en `prod` sólo actualiza 25% simultáneo. Esto convierte al ApplicationSet en un rollout multi-ambiente *gobernado por salud*.

**Precaución:** Progressive sync está marcado como *beta/alpha* en algunas versiones; verifica el flag `--enable-progressive-syncs` en el `applicationset-controller` para tu versión.

---

## 12. app-of-apps vs ApplicationSet — cuándo cada uno

| | app-of-apps | ApplicationSet |
|---|---|---|
| Fuente de verdad | manifests `Application` en un repo | un sólo CR + generators |
| Añadir un servicio | nuevo YAML en el repo | aparece *solo* si cumple el generator |
| Repetición | alta (hay un YAML por app) | baja (template único) |
| Multi-cluster | copias por cluster | `clusters` generator |
| Preview envs | manual o custom | `pullRequest` generator nativo |
| Simplicidad | muy explícito, cero magia | requiere entender el controller |
| Debug | fácil (es YAML) | medio (hay que leer events del controller) |

**Regla práctica:** empieza con app-of-apps mientras haya <10 Applications estables. En cuanto necesites multi-cluster, preview envs, o un catálogo que varía, pásate a ApplicationSet. **Puedes mezclar**: un ApplicationSet raíz que genera varios Application "de bootstrap" y, dentro de cada uno, apps gestionadas al estilo clásico.

---

## Preguntas de evaluación

1. ¿Por qué `goTemplate: true` + `missingkey=error` es defensivo y qué clase de bug previene?
2. En un `matrix(apps × clusters)` sin filtros, ¿qué pasa cuando añades un cluster nuevo? ¿y cuándo retiras uno?
3. Diferencia operativa entre `git.directories` y `git.files`. ¿Cuándo elegirías cada una?
4. El `pullRequest` generator cierra un PR y borra la App — pero el namespace de preview tenía datos de prueba valiosos. ¿Cómo preservarías los recursos sin romper la limpieza automática?
5. ¿Por qué `app-of-apps` sigue teniendo lugar incluso en orgs con ApplicationSet maduro?
