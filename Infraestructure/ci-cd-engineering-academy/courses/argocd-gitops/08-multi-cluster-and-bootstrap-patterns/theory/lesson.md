# Multi-cluster y patrones de bootstrap en Argo CD

> Nivel avanzado. Supone que ya tenés un Argo CD funcionando (`argo-02`) y que entendés
> ApplicationSets con sus generators (`argo-07`). El foco acá es *topología* y
> *reproducibilidad* — menos sobre "cómo escribir un Application" y más sobre "cómo
> operar 10 clusters sin volverse loco".

---

## 1. ¿Por qué multi-cluster?

Una sola organización rápidamente tiene más de un cluster: dev / stg / prod es el mínimo,
y basta con que entre un requisito regulatorio (datos en EU y en US), un cliente dedicado,
o una necesidad de aislamiento por blast radius para que aparezcan 5, 10, 50 clusters.
Las razones típicas:

- **Aislamiento de ambientes**: romper prod no debe ser una posibilidad desde dev.
- **Soberanía / residencia de datos**: un cluster por región.
- **Multi-tenancy "hard"**: un cluster por tenant cuando el aislamiento namespace no alcanza.
- **Resiliencia**: si cae un cluster, no cae el servicio.
- **Edge / IoT**: un cluster chiquito por sitio.
- **Separación por team/BU**: cada equipo con su cluster, su propio ownership operativo.

El reto operativo no es desplegar en N clusters — con `kubectl` eso siempre fue posible.
El reto es **mantener consistencia** entre ellos (ingress-nginx igual en todos, versión de
cert-manager alineada, políticas Kyverno sincronizadas) **y** poder dar de alta/baja un
cluster sin ceremonias.

GitOps responde a eso con dos piezas: **registro declarativo de clusters** y **bootstrap
repo**. Argo CD las implementa de forma particularmente limpia; vamos pieza por pieza.

---

## 2. Las dos topologías canónicas

### 2.1 In-cluster (una instalación por cluster)

Cada cluster corre su propia instalación de Argo CD y se gestiona a sí mismo. El Secret
"in-cluster" que viene por defecto apunta a `https://kubernetes.default.svc` y usa el
ServiceAccount local del controller — cero credenciales cruzadas.

```
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│ cluster: dev   │   │ cluster: stg   │   │ cluster: prod  │
│  argo-cd       │   │  argo-cd       │   │  argo-cd       │
│   └→ apps dev  │   │   └→ apps stg  │   │   └→ apps prod │
└────────────────┘   └────────────────┘   └────────────────┘
       ▲                     ▲                     ▲
       └── repo infra ───────┴─────────────────────┘
```

- **Pros:** blast radius chico (un Argo CD caído solo afecta a su cluster);
  independencia operativa; latencia API-server local; recuperación independiente.
- **Contras:** N UIs, N instalaciones que actualizar, N backups, difícil ver el estado
  global; sync policies, Projects y RBAC repetidos; subir una versión = N PRs o un PR al
  chart común y N PRs de bump.

Pattern operativo: cada cluster corre su `argocd-manager` apuntando a *una carpeta
específica del repo* (`clusters/<env>/`), y hay un **ApplicationSet con Git generator**
que descubre todo lo que vive bajo esa carpeta. Un commit nuevo en la carpeta `dev/` solo
afecta al cluster `dev`.

### 2.2 Control-plane cluster (hub-and-spoke)

Una sola instalación de Argo CD vive en un cluster "hub" (habitualmente dedicado y chico)
y gestiona N clusters "spoke". El hub tiene registrados todos los targets como Secrets
tipo `cluster`.

```
                 ┌────────────────┐
                 │ hub cluster    │
                 │  argo-cd       │
                 └────┬───────────┘
      ┌───────────────┼───────────────┐
      ▼               ▼               ▼
 ┌─────────┐    ┌─────────┐    ┌─────────┐
 │ dev     │    │ stg     │    │ prod    │
 │ (spoke) │    │ (spoke) │    │ (spoke) │
 └─────────┘    └─────────┘    └─────────┘
```

- **Pros:** un panel único (UI y RBAC); una versión de Argo CD que mantener; un backup;
  ApplicationSet con **Cluster generator** aplica una misma plantilla a los N spokes de
  un plumazo; convergente con la realidad de las *plataformas internas*.
- **Contras:** blast radius grande (si cae el hub, nada reconcilia); el hub guarda
  tokens/credenciales de todos los spokes — es *el* activo que proteger; latencia hub↔spoke
  depende de red (relevante en multi-región); escalado del controller depende de nº de
  recursos * nº de clusters (sharding ayuda).

### 2.3 ¿Cuál elegir?

No hay respuesta universal. Como heurística:

| Factor                                | In-cluster | Control-plane |
|---------------------------------------|------------|---------------|
| Pocas apps, pocos clusters (≤3)       | ✓          | ✓ (indiferente) |
| Muchos clusters homogéneos (fleet)    |            | ✓             |
| Multi-tenant "hard"                   | ✓          |               |
| Equipo plataforma pequeño             |            | ✓             |
| Blast radius crítico (banco/salud)    | ✓          |               |
| Latencia inter-cluster alta           | ✓          |               |
| Requisito "pane of glass" ejecutivo   |            | ✓             |

Un patrón híbrido común: **control-plane por región** — un hub por región que gestiona
los spokes de esa región, y una capa de GitOps meta (que puede ser Flux, Argo, o un
pipeline) sincroniza los hubs entre sí.

---

## 3. Registro declarativo de clusters

El modo imperativo (`argocd cluster add <kube-context>`) es útil para explorar y
onboardear a mano, pero rompe la premisa GitOps en el momento en que lo usás: el cluster
registrado existe **en el estado del hub** pero no **en Git**. Para operar en serio: Secret
declarativo.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cluster-dev
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: dev            # usado por selectors en ApplicationSets
    region: us-east-1
type: Opaque
stringData:
  name: dev
  server: https://dev.k8s.example.internal:6443
  config: |
    {
      "bearerToken": "<REDACTED-SA-TOKEN>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca-bundle>"
      }
    }
```

Puntos clave:

- La **label** `argocd.argoproj.io/secret-type: cluster` es lo que hace que Argo CD lo
  reconozca; sin ella es un Secret cualquiera.
- `name` es el identificador por el que lo referís en `spec.destination.name` (preferible
  a `server`, que es la URL — menos frágil ante cambios de endpoint).
- Las labels extra (`env`, `region`, `tier`) habilitan el `clusterSelector` en
  **Cluster generator** de ApplicationSets.
- `bearerToken` es un **secreto** — nunca commitearlo en claro. Opciones: Sealed Secrets,
  External Secrets Operator (ESO), SOPS. (Lo vemos en `argo-09`; en este módulo lo tratamos
  como "placeholder" y lo inyectamos localmente para labs.)

### 3.1 ¿De dónde sale el `bearerToken`?

En el cluster target creamos un ServiceAccount con permisos amplios (Argo CD necesita
poder aplicar casi cualquier cosa) y extraemos su token:

```bash
# en el cluster target
kubectl create ns argocd-manager
kubectl create sa argocd-manager -n argocd-manager
kubectl create clusterrolebinding argocd-manager \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd-manager:argocd-manager
# K8s ≥1.24: tokens de SA no se crean automáticos — pedimos uno
kubectl create token argocd-manager -n argocd-manager --duration=8760h
```

Ese token (más la CA del cluster y la URL del API-server) es lo que va al Secret del hub.
Rotarlo es una operación delicada: significa generar uno nuevo, actualizar el Secret, y
*después* invalidar el viejo — nunca al revés.

En clouds hay alternativas limpias: en EKS, usar `aws-iam-authenticator` (el hub asume un
rol IAM que mapea a un RBAC subject en el target); en GKE, workload identity. Esas rutas
eliminan tokens de larga vida de Git. Son las preferidas en producción cloud.

### 3.2 El cluster "in-cluster" especial

Toda instalación tiene por defecto registrado el cluster donde vive Argo CD, con nombre
`in-cluster` y URL `https://kubernetes.default.svc`. Usa el ServiceAccount del controller
local, no un token. Es el único cluster sin Secret explícito — en topología hub-and-spoke
podés desactivarlo si querés que el hub *no* despliegue nada en sí mismo (práctica común
en setups estrictos).

---

## 4. El patrón "bootstrap repo"

Un bootstrap repo es el repositorio Git cuyo primer `kubectl apply` sobre un cluster
vacío lo lleva a su estado objetivo completo: add-ons, políticas, Projects, Applications
de app, y la propia instalación de Argo CD autogestionada.

### 4.1 Layout de referencia

```
bootstrap-repo/
├── bootstrap/
│   └── root.yaml                 # Application o ApplicationSet "raíz"
├── clusters/
│   ├── dev/
│   │   ├── cluster-secret.yaml   # Secret declarativo de este cluster
│   │   └── overrides.yaml        # values específicos (region, dns, etc.)
│   └── prod/
│       └── ...
├── addons/
│   ├── cert-manager/
│   │   └── application.yaml      # Argo Application que instala el chart
│   ├── ingress-nginx/
│   ├── external-dns/
│   └── prometheus-operator/
├── projects/
│   └── platform.yaml             # AppProject del equipo plataforma
└── apps/
    ├── appset-tenants.yaml       # ApplicationSet con Git generator sobre tenants/
    └── tenants/
        ├── team-a/
        └── team-b/
```

Convenciones que pagan:

- **`bootstrap/root.yaml` es la única cosa que se aplica a mano**; todo el resto emerge
  por reconciliación.
- Los directorios bajo `addons/` son **"una app por carpeta"** — un ApplicationSet con
  **Git generator** descubre cada subdirectorio y crea una Application por cada uno.
- Los `clusters/<env>/` tienen *data* (Secret del cluster + overrides) pero no *lógica* —
  la lógica vive en `addons/` y es común para todos los clusters.
- `projects/` define **AppProjects** antes que cualquier Application, para que la
  Application correspondiente pase su `project` field a algo que ya existe.

### 4.2 La root app

Dos formas en uso. Primera, **app-of-apps clásico**:

```yaml
# bootstrap/root.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/acme/bootstrap-repo
    path: addons                 # ¡una carpeta llena de Applications!
    targetRevision: main
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Argo CD lee la carpeta `addons/` como *manifests crudos*; cada archivo es una
`Application` CR; al aplicarlo, nacen Applications hijas que a su vez despliegan los
charts. Es el patrón original y el más fácil de entender; su contra es que para "N
addons × M clusters" tenés que duplicar YAML.

Segunda, **root ApplicationSet** (hoy preferido):

```yaml
# bootstrap/root.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: addons
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - clusters: {}                           # todos los clusters registrados
          - git:
              repoURL: https://github.com/acme/bootstrap-repo
              revision: main
              directories:
                - path: addons/*
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/acme/bootstrap-repo
        targetRevision: main
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: '{{path.basename}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ CreateNamespace=true ]
```

Resultado: N clusters × M addons → N·M Applications generadas automáticamente. Añadir un
cluster nuevo = un Secret nuevo + commit; añadir un add-on = una carpeta nueva + commit.
Nada que editar en Argo CD.

### 4.3 Orden de los add-ons: sync waves y dependencias

Varios add-ons tienen dependencias:

- **cert-manager** debe estar vivo antes de cualquier `Certificate` o `Issuer`.
- Los **CRDs** de un operator deben existir antes que los CRs de ejemplo.
- **ingress-nginx** antes que recursos `Ingress` que lo usen.
- **Prometheus Operator** antes que `ServiceMonitor`s.

Herramientas:

1. **`argocd.argoproj.io/sync-wave`** sobre cada manifest ordena *dentro* de una
   Application. Negativos van primero. Útil para ordenar CRDs → operator → CRs.
2. **`SyncOptions: ServerSideApply=true`** evita conflictos con CRDs grandes.
3. **ApplicationSet `strategy.rollingSync`** ordena *entre* Applications generadas: una
   "wave" entera (ej. todos los CRD-only addons) termina healthy antes de arrancar la
   siguiente. Útil para "cert-manager antes que el resto".

Ejemplo mínimo de wave en una Application:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-10"   # antes que todo
```

---

## 5. Argo CD self-managing

Instalar Argo CD con GitOps = aplicarlo una vez a mano, y después tener una `Application`
que lo gestione a sí mismo. Suena recursivo, y lo es.

### 5.1 Setup

```yaml
# addons/argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-cd
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-100"   # el primero
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 7.6.12
    helm:
      valueFiles: []
      values: |
        global:
          domain: argocd.example.com
        configs:
          params:
            server.insecure: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: false            # ← clave: nunca prunear a Argo CD
      selfHeal: false         # ← clave: deja el drift explícito
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas       # convive con HPA si lo pusieras
```

### 5.2 El problema chicken-and-egg

Secuencia típica cuando un cambio al chart de Argo CD **rompe**:

1. Alguien bumpea `targetRevision: 7.6.12` → `7.7.0`.
2. El `application-controller` corriendo (en 7.6.12) reconcilia y empieza a aplicar la
   7.7.0 sobre sí mismo.
3. El Deployment del `application-controller` se re-crea. Durante segundos no hay
   reconciler.
4. Si el nuevo Pod arranca sano, perfecto; si no (imagen rota, CRD incompatible, config
   inválida), **no queda nadie que revierta**.

Mitigaciones probadas:

- **`automated.selfHeal: false` y `prune: false`** en el root que gestiona Argo CD —
  obliga a sync manual (`argocd app sync argo-cd` o UI) para upgrades, y da ventana para
  cancelar.
- **Canary cluster**: el bump al chart entra primero por un cluster de staging dedicado
  a plataforma; solo cuando ese cluster queda healthy, el PR se mergea al branch de prod.
- **Snapshot pre-upgrade** del namespace `argocd` con **Velero** — restore devuelve el
  controller funcional.
- **Backups del state** (los CRs `Application`, `AppProject`, `ApplicationSet` son el
  state — un `kubectl get -o yaml` del namespace es casi todo lo que necesitás).
- **Nunca eliminar el namespace `argocd`** desde una Application (prune: false bloquea
  esto a nivel de root, pero añadí también `argocd.argoproj.io/sync-options:
  Delete=false` sobre el Namespace manifest si lo versionás).
- **Procedimiento documentado de "restaurar Argo CD a mano desde cero"**: el `kubectl
  apply -k` original debe seguir siendo válido *siempre*.

### 5.3 Cuando igual explota: recuperación

```bash
# 1) Reinstalar Argo CD imperativamente a la última versión conocida sana
kubectl -n argocd apply -k \
  "https://raw.githubusercontent.com/argoproj/argo-cd/<TAG>/manifests/"
# 2) Esperar que el controller levante
kubectl -n argocd rollout status deploy/argocd-server
# 3) Restaurar CRs desde el backup Velero (o re-aplicar los manifiestos del bootstrap)
velero restore create --from-backup argocd-pre-upgrade
# 4) Argo CD empieza a reconciliar desde los CRs restaurados; el estado del cluster
#    (apps, services) nunca se perdió — solo faltaba el reconciler.
```

El consuelo técnico: Argo CD casi no tiene *state* propio — los CRs son todo. Perder el
controller no pierde las apps desplegadas; solo pierde la capacidad de reconciliar
cambios futuros.

---

## 6. Discovery dinámico con Cluster API

Hasta acá, "añadir cluster = commitear un Secret". Esto escala a decenas, no a miles.
Para fleets grandes se usa **Cluster API (CAPI)**: un controller crea clusters desde CRs,
y un *plugin* de Argo CD descubre esos clusters y genera Secrets automáticamente.

El patrón: una `Cluster` CR de CAPI es la fuente de verdad; un adaptador
(`argocd-cluster-api-plugin`, Akuity, Rancher-fleet) genera el Secret de Argo CD cuando
el cluster se vuelve ready. Resultado: provisionar y onboardear un cluster son el mismo
PR.

Para la mayoría de las orgs (≤50 clusters) esto es overkill; el Secret declarativo + un
PR por cluster alcanza y sobra. Mencionado por completitud.

---

## 7. Antipatrones comunes

- **"Agrego el cluster con `argocd cluster add` y después pongo el Secret en Git"** —
  acabás con dos fuentes de verdad; Argo CD aplica una, operaciones aplican otra, drift
  silencioso. Elegí Git o CLI, nunca ambos.
- **Root Application con `syncPolicy.automated.selfHeal: true` que apunta al chart de
  Argo CD** — bomba de tiempo. Un commit malo a 3 AM, chau cluster.
- **`cluster-admin` eterno al ServiceAccount del hub en los targets** — correcto para
  empezar; en producción, scope-down con un ClusterRole propio que excluya cosas
  sensibles (secrets de otros tenants, resources que no gestionás).
- **Mezclar manifests de apps y de plataforma en el mismo repo con el mismo owner** —
  dev pushea a prod sin querer. CODEOWNERS por carpeta, o repos separados.
- **No testear la ruta de recuperación** — "nuestro bootstrap es GitOps" solo vale si el
  `apply` inicial sigue funcionando. Probalo cada quarter en un cluster descartable.

---

## 8. Convivencia con otros patrones

- Con **argo-09 (secrets)**: el `bearerToken` del Secret cluster es *el* secret que no
  podés versionar en claro. ESO desde AWS Secrets Manager es la ruta limpia; Sealed
  Secrets también sirve a nivel por-cluster.
- Con **argo-10 (Rollouts)**: Rollouts es un CRD más gestionado por el mismo bootstrap.
  Nada especial.
- Con **argo-11 (hardening)**: el hub cluster es "corona de la joya"; aplicá Pod
  Security *restricted*, OIDC obligatorio, admin local off.
- Con **argo-12 (platform patterns)**: el bootstrap repo típicamente *es* el repo de
  infra; promoción entre ambientes se expresa como estructura de ese repo (branches,
  overlays, o directories).

---

## 9. Costos operativos reales

| Operación                             | In-cluster       | Control-plane    |
|---------------------------------------|------------------|------------------|
| Añadir un cluster                     | Instalar Argo CD + PR | Un Secret + PR |
| Actualizar Argo CD                    | N PRs (uno por cluster) | 1 PR          |
| Perder el hub                         | No afecta nada   | Nada reconcilia  |
| Investigar un drift                   | UI del cluster   | UI del hub       |
| RBAC multi-equipo                     | Local a cluster  | Centralizado     |
| Costo de infra base                   | N × controller   | 1 × controller (más grande) |

El coste nominal del hub-and-spoke es menor; el coste de "estar siempre arriba" es
mayor. Trade-off clásico de disponibilidad vs simplicidad.

---

## 10. Checklist antes de ir a producción con multi-cluster

- [ ] Cada cluster target tiene su propio `argocd-manager` SA con token con **vencimiento**.
- [ ] Los tokens no viven en claro en Git (ESO / Sealed Secrets / SOPS).
- [ ] El bootstrap repo tiene un `root.yaml` que, aplicado contra un cluster vacío,
      produce estado objetivo completo — y lo probaste en un cluster descartable.
- [ ] El root Application que gestiona Argo CD tiene `selfHeal: false` y `prune: false`.
- [ ] Hay un AppProject distinto a `default` para los add-ons de plataforma.
- [ ] Hay backups Velero del namespace `argocd` del hub.
- [ ] Documentaste la ruta de recuperación "sin Argo CD" (kubectl + manifests originales).
- [ ] CODEOWNERS impide que un dev mergee cambios al chart de Argo CD sin plataforma.
- [ ] Alertas sobre `argocd_app_info{sync_status!="Synced"}` por cluster.

---

## 11. Qué mirar después

- **`argo-09`** si no gestionaste los secrets del bearerToken aún.
- **`argo-11`** para endurecer el hub (OIDC, RBAC, admin local off).
- **`argo-12`** para formalizar promoción entre ambientes sobre esta base.
- **Argo CD Autopilot** (`argo-cd/argocd-autopilot`): CLI que *genera* el bootstrap repo
  siguiendo convenciones oficiales. Útil para empezar; limita libertad de diseño.
- **Akuity Platform / Codefresh GitOps Runtime**: SaaS de hub-and-spoke gestionado — si
  no querés operar el hub, pagás que lo operen.

---

## 12. Resumen

- Dos topologías: **in-cluster** (blast radius chico, mantenimiento N×) y
  **control-plane** (hub único, mantenimiento 1× pero blast radius grande).
- Clusters se registran como **Secrets con label `argocd.argoproj.io/secret-type: cluster`**;
  CLI está bien para explorar, Git para operar.
- Un **bootstrap repo** con un **root ApplicationSet** convierte "cluster vacío →
  cluster listo" en un `kubectl apply` único + reconciliación.
- **Argo CD gestionado por sí mismo** cierra el ciclo GitOps, con la condición de aceptar
  los riesgos chicken-and-egg y aplicar mitigaciones (`selfHeal: false`, canary,
  Velero, procedimiento manual probado).
- Los add-ons se ordenan con **sync-waves** y **rollingSync** de ApplicationSet.
- La diferencia entre "nos funciona" y "operamos en serio" está en haber **probado la
  recuperación** del hub al menos una vez.
