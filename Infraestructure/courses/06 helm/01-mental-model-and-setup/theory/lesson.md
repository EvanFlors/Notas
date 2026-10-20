# Lección: Modelo mental y setup de Helm

> **ID:** `helm-01-mental-model-and-setup` · **Nivel:** fundamentos · **Duración:** 1,5–2 h
> **Prerrequisitos:** curso **kubernetes** ≥ Nivel 2. YAML a nivel operativo.

---

## 1. Introducción intuitiva

Supón que ya tienes un cluster Kubernetes andando y acabas de aprender a hacer `kubectl apply -f deployment.yaml`. Tu app FastAPI tiene un `Deployment`, un `Service`, un `ConfigMap` y un `Secret`. Son cuatro archivos. Los commiteas en Git, los aplicas con un script bash, funciona.

Ahora quieres **tres entornos** (dev, stg, prod) con la misma app pero con `replicas` distintas, imagen distinta, host del Ingress distinto, variables distintas y recursos distintos. Opciones ingenuas:

- **Copia-pega**: `k8s/dev/*.yaml`, `k8s/stg/*.yaml`, `k8s/prod/*.yaml`. Un día cambias el health check en dev, te olvidas de prod, se te cae prod.
- **Script bash con `sed`**: `cat deployment.yaml | sed s/REPLICAS/3/`. Funciona hasta que un valor contiene barras o se te escapa un `&`. Al cabo de un mes tienes un lenguaje de templates casero, mal.
- **`envsubst`**: mejor que `sed`, pero sigues sin tener defaults, sin validación de inputs, sin "versión" de la plantilla.

Ahora añade que quieres **instalar Prometheus**, **ingress-nginx** y **cert-manager** del ecosistema. Cada uno es una docena de manifests (Deployments, Services, CRDs, RBAC, webhooks). Si copias los YAML a mano, tu repo se vuelve ilegible y actualizar a la siguiente versión del producto es una pesadilla.

Lo que empezó como `kubectl apply` termina siendo una **mala reimplementación** de lo que ya existe: un **package manager** para Kubernetes con templating, defaults, versiones, y lifecycle de release. Eso es **Helm**.

Helm empaqueta un conjunto de manifests parametrizados (un **chart**) en un `.tgz` versionado y publica ese `.tgz` en un **repository**. Tú, consumidor, describes "quiero una instancia (**release**) de este chart con estos valores" y Helm renderiza los templates, aplica el YAML resultante contra el API server, y guarda el historial para que puedas hacer `upgrade` o `rollback` después.

Pero Helm no es solo "templates + instalador". Es un **vocabulario** (chart / release / revision / repository / values) que te permite hablar con precisión sobre software en Kubernetes. Y en Helm 3 es puramente **client-side**: no hay daemon, no hay componente en el cluster, no hay permisos amplios. Esto no era así en Helm 2 (ver §3 y §9).

---

## 2. Fundamentos

Cinco palabras que necesitas internalizar antes de ver un solo comando. Memorízalas en este orden: **chart → repository → values → release → revision**.

### 2.1 Chart

Un **chart** es un **paquete versionado** de manifests Kubernetes parametrizados. Es un directorio (o un `.tgz`) con esta forma mínima:

```
mychart/
├── Chart.yaml          ← metadata (name, version, appVersion, dependencies)
├── values.yaml         ← defaults de los parámetros
├── templates/          ← manifests Kubernetes con Go templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── _helpers.tpl    ← partials (no se renderizan directo)
│   └── NOTES.txt       ← mensaje post-install
├── charts/             ← subcharts (dependencias) extraídos
└── Chart.lock          ← lockfile de dependencias (SemVer resuelto)
```

Dos campos del `Chart.yaml` son críticos:

- `version` — versión **del chart** (SemVer). Cambia cuando cambia la plantilla.
- `appVersion` — versión **del software** empaquetado (p. ej. `1.27.0` para nginx). Puede cambiar sin que cambie la versión del chart (y viceversa).

Un chart es un **artefacto** — no está instalado en ningún lado. Es como un `.deb` o un contenedor OCI: existe antes de ser desplegado.

### 2.2 Repository

Un **repository** es un índice de charts publicados. Dos sabores:

- **HTTP tradicional** — un servidor web sirve `index.yaml` + los `.tgz`. Es el modelo original. Se usa con `helm repo add <name> <url>` y `helm repo update`.
- **OCI registry** — desde Helm 3.8, un chart se puede publicar como artefacto OCI en el mismo registry que tus imágenes (GHCR, ECR, Harbor). No requiere `helm repo add`; se accede con `oci://` directamente. Es la dirección moderna.

Artifact Hub (`artifacthub.io`) es un **índice de índices**: no aloja charts, pero te deja buscar en todos los repositorios públicos conocidos. `helm search hub` consulta a Artifact Hub; `helm search repo` consulta a los repos que **tú** añadiste localmente.

### 2.3 Values

**Values** son los **parámetros** del chart. El chart trae **defaults** en `values.yaml`; tú los sobrescribes con `--values mi-overrides.yaml` o `--set key=valor` al instalar/actualizar. Toda la lección vuelve una y otra vez a esta idea:

> **`values.yaml` ES la API pública del chart**. Es el único punto por donde el usuario del chart puede influir en lo que se renderiza.

Esto importa porque significa que:

- Añadir, renombrar o eliminar una key de `values.yaml` es un **cambio de API** — rompe a tus consumidores si lo haces en una versión *minor* o *patch*.
- Los defaults de `values.yaml` definen cómo se comporta el chart "out of the box"; eso es parte del contrato.
- Formalizar la API con **`values.schema.json`** (JSON Schema) permite validar que los inputs del usuario son correctos antes de renderizar — pasa de "docs informal" a "contrato ejecutable".

### 2.4 Release

Una **release** es una **instancia** de un chart aplicada a un cluster concreto, en un namespace concreto, con un nombre único. El mismo chart puede desplegarse N veces (con N nombres distintos) y cada una es una release independiente.

Una release tiene:

- **Nombre** (`helm install mi-nginx bitnami/nginx` → la release se llama `mi-nginx`).
- **Namespace** (donde viven sus recursos).
- **Chart + versión del chart** y **valores efectivos** (defaults + overrides fusionados).
- **Estado** (`deployed`, `failed`, `pending-upgrade`, `uninstalled`, …).

Si borras una release (`helm uninstall mi-nginx`), Helm borra los recursos que aplicó. Es la pieza "operada" del vocabulario.

### 2.5 Revision

Cada operación sobre una release (`install`, `upgrade`, `rollback`) crea una **revision**. Las revisions son enteros monótonamente crecientes: 1, 2, 3, 4...

- `install` crea la revision **1**.
- Cada `upgrade` crea una revision nueva.
- `rollback` **también** crea una revision nueva (es una copia del estado de la revision destino).
- Las revisions viejas se conservan (por default las últimas 10) para permitir `rollback`.

Dónde se guardan: en **Secrets** (default desde Helm 3) o **ConfigMaps** en el namespace de la release, con nombres tipo `sh.helm.release.v1.mi-nginx.v3`. Son datos serializados (gzip + base64) del release manifest, los valores y el estado. No los edites a mano — Helm los posee.

### Síntesis mental

```
┌─────────────────────────────────────────────────────────────┐
│  REPOSITORY  (HTTP index o OCI registry)                    │
│    publica CHARTs                                           │
└─────────────────────────────────────────────────────────────┘
                        │  helm repo add / helm pull
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  CHART  (artefacto .tgz versionado)                         │
│    - Chart.yaml       (metadata)                            │
│    - values.yaml      ← LA API DEL CHART                    │
│    - templates/       (Go templates sobre YAML)             │
└─────────────────────────────────────────────────────────────┘
                        │  helm install <name> <chart> --values ...
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  RELEASE  (instancia aplicada a un namespace)               │
│    revision 1 (install)                                     │
│    revision 2 (upgrade con otros values)                    │
│    revision 3 (rollback a 1)                                │
│    ... estado en Secrets del namespace de la release        │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Contexto histórico

Helm no cayó del cielo y, sobre todo, **Helm 3 no es Helm 2 con parches**. La historia pesa en el modelo mental:

- **2015** — Deis (una startup, luego comprada por Microsoft) libera **Helm 1**. Idea: "homebrew / apt para Kubernetes".
- **2016** — Kubernetes adopta Helm como proyecto. Nace **Helm 2** con **Tiller**, un componente **in-cluster** (Deployment en `kube-system`) que:
  - Recibía peticiones del cliente `helm` por gRPC.
  - Renderizaba los templates **server-side**.
  - Aplicaba los manifests al API server **usando sus propios permisos**.
  - Guardaba el estado de releases en ConfigMaps.
  - Problema: Tiller típicamente corría con un `ServiceAccount` con **`cluster-admin`** porque "para instalar cualquier chart necesita poder crear cualquier recurso". Cualquiera que pudiera hablar con Tiller (y a menudo era accesible sin autenticación robusta dentro del cluster) **efectivamente era `cluster-admin`**. Esto era un agujero de seguridad conocido durante años.
- **2017–2018** — El equipo de Helm acepta que Tiller fue un error de diseño y empieza el rediseño. Mitigaciones intermedias (TLS mutuo con Tiller, `--tiller-namespace` por tenant) nunca resolvieron el fondo: un *singleton* server-side con permisos amplios es, por naturaleza, un problema.
- **Noviembre 2019** — **Helm 3** GA. Cambios estructurales:
  - **Tiller eliminado.** El cliente `helm` renderiza localmente y aplica contra el API server **como cualquier otro usuario** (usando el kubeconfig del operador). Los permisos efectivos son los del usuario, no los de un robot con `cluster-admin`.
  - El estado de releases pasa a **Secrets** por default (no ConfigMaps) y vive en el **namespace de la release** (no en `kube-system`).
  - Las releases son **namespace-scoped** (en Helm 2 eran global por nombre).
  - CRDs tienen un directorio especial `crds/` con reglas distintas al resto (ver `helm-03`).
- **2020–2021** — Depreciación de `helm/charts` (el monorepo oficial de charts). El mundo migra a **Artifact Hub** como índice público y repos propios por organización.
- **Marzo 2022** — Helm 3.8: **OCI registries** salen de experimental. Ahora un chart se publica como artefacto OCI junto a tus imágenes.
- **2023+** — Integración más limpia con **Argo CD** y **Flux** (ambos consumen charts Helm como fuente de verdad en GitOps). Mejoras de UX menores. **`helm-unittest`** y **`chart-testing`** se consolidan como herramientas de validación.
- **2024+** — Soporte estable para post-rendering con `--post-renderer` (combinable con Kustomize), mejoras en la gestión de dependencias.

Qué memorizar: **Helm 2 + Tiller está muerto desde 2019**. Si lees un tutorial que menciona `helm init` o Tiller, es Helm 2 y está obsoleto. Hoy "Helm" significa "Helm 3", client-side, sin daemon.

---

## 4. Funcionamiento interno

### 4.1 Qué hace `helm install` paso a paso

Ejemplo: `helm install mi-nginx ingress-nginx/ingress-nginx --namespace ingress --create-namespace --values prod.yaml`.

```
1. CLIENTE 'helm' (binario Go en tu laptop / runner de CI)
   - Lee kubeconfig (como kubectl: endpoint del API server + credenciales).
   - Resuelve el chart: busca ingress-nginx/ingress-nginx en los repos locales
     o lo pulls de OCI si es oci://...
                            │
                            ▼
2. CARGA del chart en memoria
   - Parsea Chart.yaml, values.yaml, templates/*, charts/ (subcharts).
   - Resuelve dependencias (Chart.lock).
                            │
                            ▼
3. MERGE de values
   - defaults del chart (values.yaml)
   - overrides de --values archivo.yaml (en orden)
   - overrides de --set clave=valor (más alta precedencia)
   - resultado: un único objeto 'values' efectivo.
                            │
                            ▼
4. RENDER (client-side, Go templates + Sprig)
   - Ejecuta cada template de templates/ con el objeto 'values'.
   - Produce un stream de manifests YAML puros.
   - (opcional) --post-renderer puede transformar el output.
                            │
                            ▼
5. (opcional) VALIDACIÓN contra values.schema.json si existe.
                            │
                            ▼
6. APPLY contra el API server
   - El cliente envía los manifests con server-side apply (o client-side apply
     en versiones antiguas), usando TU identidad (TU kubeconfig).
   - Autentica → autoriza (RBAC) → admission → persistencia en etcd.
                            │
                            ▼
7. GUARDA el estado de la release
   - Crea un Secret 'sh.helm.release.v1.<release>.v1' en el namespace.
   - Contiene: manifest renderizado, valores efectivos, metadata, info.
                            │
                            ▼
8. HOOKS post-install (si el chart los define) y render de NOTES.txt
   - Muestra en pantalla el mensaje de bienvenida con tips de uso.
```

**Nada de esto requiere un componente en el cluster que sea de Helm.** El API server ve requests normales de aplicar manifests desde `tu-usuario`. Si no tienes permisos para crear un Deployment en ese namespace, `helm install` falla con `403 Forbidden` — igual que un `kubectl apply`.

### 4.2 Dónde vive el estado de una release

```
Namespace: ingress  (el namespace de la release)
├── Secret sh.helm.release.v1.mi-nginx.v1   (revision 1 — install)
├── Secret sh.helm.release.v1.mi-nginx.v2   (revision 2 — upgrade)
├── Secret sh.helm.release.v1.mi-nginx.v3   (revision 3 — rollback)
└── (recursos de la app: Deployment, Service, ConfigMap, …)
```

Cada Secret es `type: helm.sh/release.v1` con los datos serializados (gzip + base64). `helm list -n ingress` los enumera. `helm history mi-nginx -n ingress` muestra sus revisions. Si borras esos Secrets manualmente, para Helm la release **ya no existe** (aunque sus recursos aplicados sigan vivos — orphans).

### 4.3 Por qué el rendering en el cliente importa

En Helm 2, el rendering y el apply los hacía **Tiller**. Problemas:

- **Permisos amplios.** Tiller necesitaba permisos para crear casi cualquier recurso en casi cualquier namespace. Dar `cluster-admin` a un pod era la vía fácil.
- **Autenticación débil.** Entre el cliente `helm` y Tiller había gRPC. Habilitar TLS mutuo era opt-in y mal documentado. En clusters mal configurados, cualquier otro Pod con red al Tiller podía hablarle.
- **Punto único de operación.** Un Tiller por cluster centralizaba todas las releases; un `helm upgrade` mal hecho podía dejar su estado inconsistente y bloquear futuras operaciones.
- **Multi-tenancy imposible.** No había una buena forma de aislar tenants: todos compartían el Tiller del cluster.

En Helm 3:

- **Sin daemon.** El binario `helm` es local; no instala nada en el cluster.
- **Permisos = permisos del usuario.** Si eres `developer` con RBAC acotado a un namespace, solo puedes instalar charts cuyos recursos quepan en ese namespace con esos permisos. Si no tienes permisos, el apply falla — como con `kubectl`.
- **Auditoría clara.** El API server audita las acciones como del usuario que las hizo, no de un robot genérico.
- **Multi-tenancy natural.** Cada equipo trae su kubeconfig / ServiceAccount; Helm respeta eso.

Esto es la decisión arquitectónica más importante de Helm 3 y es la razón por la que decir "Helm" en 2026 es decir "Helm 3".

### 4.4 Qué NO hace Helm

Para calibrar expectativas:

- **No es un GitOps controller.** Helm instala/actualiza cuando *tú* se lo pides. No vigila el cluster para corregir drift. **Argo CD** y **Flux** son los que hacen eso (y consumen charts de Helm como entrada).
- **No es un sistema de secretos.** `values.yaml` **no está cifrado**. Para secretos usa Sealed Secrets, External Secrets Operator, SOPS, o inyecta `--set` desde un secret manager en CI.
- **No es un validador semántico profundo del cluster.** Hace `helm lint` básico y, si tiene `values.schema.json`, valida inputs. No simula el apply ni detecta conflictos con lo que ya hay en el cluster.
- **No gestiona el ciclo de vida de CRDs después del install.** Las CRDs en `crds/` se crean en `install` pero **no** se actualizan en `upgrade`. Es una decisión de seguridad deliberada (ver `helm-03`).

---

## 5. Ejemplo mínimo (sin cluster)

Nada aquí requiere cluster — es lectura. Mira este fragmento de un `values.yaml` real de un chart popular (versión simplificada):

```yaml
# Chart: ingress-nginx (simplificado)
controller:
  replicaCount: 1

  image:
    repository: registry.k8s.io/ingress-nginx/controller
    tag: ""                     # vacío ⇒ usa appVersion del chart
    pullPolicy: IfNotPresent

  service:
    type: LoadBalancer          # también: NodePort, ClusterIP
    externalTrafficPolicy: ""   # Local | Cluster

  resources:
    requests:
      cpu: 100m
      memory: 90Mi

  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 11

  metrics:
    enabled: false
```

Lee eso como lo que es: **la API del chart**. Un consumidor sabe que puede:

- Pedir N réplicas con `--set controller.replicaCount=3`.
- Cambiar el tipo de Service con `--set controller.service.type=NodePort`.
- Habilitar métricas con `--set controller.metrics.enabled=true`.
- Pasar un override completo con `--values prod.yaml`.

El consumidor **no necesita leer los templates**. La promesa del chart es: *"si tocas estos knobs, obtendrás este comportamiento"*. Si el chart está bien hecho, los templates son una caja negra para el consumidor.

Ahora el comando que renderiza esto en pantalla (**sin instalar nada**):

```bash
helm template mi-nginx ingress-nginx/ingress-nginx \
  --set controller.replicaCount=3 \
  --set controller.service.type=NodePort \
  > /tmp/rendered.yaml
```

Produce YAML puro. Puedes `kubectl diff` eso contra el cluster, meterlo en un repo de GitOps, o pasárselo a Kustomize. **Esto solo es posible porque el rendering es client-side.**

---

## 6. Implementación progresiva

Un camino de aprendizaje realista — qué entender *antes* y qué *después*:

**Paso 1 — Modelo mental + setup (este módulo).** Vocabulario (chart/release/revision/repository/values), por qué Tiller murió, instalación de `helm`, comandos exploratorios. Sin instalar releases.

**Paso 2 — Consumo (`helm-02`).** Instalar charts de terceros con `helm install`, actualizar con `helm upgrade`, revertir con `helm rollback`, inspeccionar con `helm list|status|history|get`.

**Paso 3 — Anatomía de un chart propio (`helm-03`).** Crear tu primer chart con `helm create`, entender `Chart.yaml`, `templates/`, `_helpers.tpl`, `values.schema.json`.

**Paso 4 — Templating profundo (`helm-04`).** Go templates, Sprig, `include` vs `template`, `required`, `default`, debug.

**Paso 5 — Values y precedencia (`helm-05`).** Overrides por entorno, `global:`, scoping en subcharts, `import-values`.

**Paso 6 — Dependencias (`helm-06`).** `dependencies:`, `Chart.lock`, umbrella vs chart-per-app.

**Paso 7+ — Lifecycle, repos/OCI, testing, platform patterns** (`helm-07` → `helm-10`).

Lo importante de este módulo es que **ningún paso siguiente tiene sentido** si no distingues chart de release ni entiendes por qué `values.yaml` es un contrato público.

---

## 7. Aplicación profesional

En una organización madura, Helm aparece en varios roles distintos:

- **Instalación de software de plataforma.** `ingress-nginx`, `cert-manager`, `kube-prometheus-stack`, `argocd`, `external-secrets`, `karpenter`... todos vienen como charts Helm. Operar un cluster sin Helm es técnicamente posible y profesionalmente raro.
- **Empaquetado de servicios internos.** Cada equipo publica su app como un chart (versionado) a un registry OCI interno (GHCR, ECR, Harbor). Otros equipos lo consumen declarando una versión.
- **Fuente de verdad para GitOps.** **Argo CD** y **Flux** leen charts de Helm como entrada y los reconcilian en el cluster. El equipo de plataforma mantiene los charts; GitOps los aplica.
- **Golden path.** Un equipo de plataforma publica un **library chart** o un **app chart genérico** que todas las apps internas consumen vía `values`. Esto fuerza convenciones (labels, probes, PDB, NetworkPolicy, ServiceMonitor) sin que cada equipo las reimplemente.

Flujo típico de una organización profesional:

```
Developer                 CI (GitHub Actions)                 Cluster (EKS)
─────────                 ───────────────────                 ─────────────
edita Chart.yaml,
templates/, values.yaml
                          helm lint
                          helm template --debug
                          helm unittest
                          chart-testing (install en kind)
──PR al repo del chart──> helm diff en el PR (vs último release)
                                    │
                                    ▼
                          review humano del diff
                                    │
                          ──merge main──
                                    │
                                    ▼
                          helm package + helm push oci://ghcr.io/org/charts
                          cosign sign (artefacto OCI)
                                    │
                                    ▼
                          Argo CD / Flux ve nueva versión del chart
                          en el App manifest → renderiza con values
                          del entorno → aplica al cluster
                          cluster converge al nuevo estado
```

Puntos clave de la práctica profesional:

- **GitOps + Helm**, no `helm install` manual en producción.
- **Charts internos versionados como productos** (SemVer, changelog, deprecation policy, migration guides).
- **Firma del chart** (cosign + OCI) como requisito de admisión en el cluster (Kyverno).
- **`values.schema.json`** obligatorio en charts internos — formaliza el contrato.
- **No usar `cluster-admin` para instalar.** La identidad de Helm (en CI o Argo CD) es un ServiceAccount acotado.

---

## 8. Trade-offs

### 8.1 Helm vs **Kustomize**

| Dimensión | Helm | Kustomize |
|-----------|------|-----------|
| Paradigma | Templating (Go templates) | Overlays (merge/patch sobre YAML base) |
| Ecosistema | Enorme (Artifact Hub, charts para casi todo) | Más pequeño (bases comunes, no "marketplace") |
| Curva | Media-alta (Sprig, pipelines, scoping) | Baja (es YAML + reglas de merge) |
| Debugging | Awkward (template render + indentación) | Natural (ves YAML diff) |
| Distribución | `.tgz` versionado, repos HTTP/OCI | Repo Git (no hay empaquetado estándar) |
| Validación de inputs | `values.schema.json` (JSON Schema) | No nativa |
| Cuándo | Software distribuible / configurable / versionado | Overlays personales sobre YAML propio |

Regla heurística: **para consumir software de terceros, Helm**. **Para gestionar tus propios manifests por entorno sin publicar nada**, Kustomize puede bastar. Muchas orgs combinan: Helm genera la base, Kustomize parchea para el entorno (`--post-renderer`).

### 8.2 Helm vs **operador** (CRDs + controller)

Un operador es software con reconciliación continua: observa CRDs y actúa. Un chart Helm aplica una vez y se olvida (hasta el próximo `upgrade`).

- Usa **Helm** para instalar/actualizar software y para apps "simples".
- Usa **operador** cuando la operación es rica (CloudNativePG hace backups, failovers, PITR; Strimzi gestiona upgrades de Kafka). Ningún chart Helm reemplaza a un operador para esos dominios.
- Muy común: **el operador se instala con un chart** (p. ej. `cert-manager` el chart instala el operador, luego creas `Certificate` CRs que el operador reconcila).

### 8.3 Helm vs **`kubectl apply -f` directo**

Si tienes 2 manifests y nunca cambiarán, `kubectl apply -f` basta. En cuanto quieras parametrizar por entorno, versionar, actualizar coordinadamente, o distribuir — Helm (o Kustomize) deja de ser opcional.

### 8.4 Helm 3 **client-side** vs la vieja idea de Tiller

Resuelto. No hay trade-off: client-side ganó en todos los frentes (seguridad, multi-tenancy, auditoría, simplicidad). No existe argumento serio para volver a un modelo con daemon in-cluster.

### 8.5 Repository HTTP vs OCI

| Dimensión | HTTP (`index.yaml`) | OCI (`oci://ghcr.io/...`) |
|-----------|---------------------|---------------------------|
| Edad | 2016+ | 2022+ (3.8 estable) |
| Infra | Cualquier servidor web | Registry OCI (misma que imágenes) |
| Autenticación | HTTP basic / token / anónimo | Mecanismos OCI (OIDC, tokens, etc.) |
| Firma | GPG via `.prov` | cosign + sigstore (keyless) |
| Tendencia | Legacy | Preferido para nuevos |

Para charts internos nuevos, **OCI**. Para consumir del ecosistema público, probablemente sigues usando repos HTTP (ingress-nginx, cert-manager, etc. ofrecen ambos pero el HTTP es canónico).

---

## 9. Errores frecuentes

### 9.1 "Helm necesita algo instalado en el cluster"

No. Helm 3 es **puramente cliente**. El cluster no sabe que existe Helm. Lo único que ve son requests normales de apply al API server y, después, Secrets con `type: helm.sh/release.v1` en el namespace. Si lees "instala Helm en tu cluster", es una guía de Helm 2 y está obsoleta.

### 9.2 "Chart y release son lo mismo"

No. **Chart = artefacto** (template). **Release = instancia aplicada**. Un mismo chart puede dar lugar a 10 releases distintas en el mismo cluster (con nombres distintos). Confundirlas lleva a errores: borrar un chart no borra releases; actualizar un chart no actualiza releases hasta que haces `helm upgrade`.

### 9.3 "Edito el YAML renderizado en el cluster para arreglarlo"

Pésimo: el próximo `helm upgrade` lo pisa. Si quieres cambiar algo, cambia los **values** (o el template, si es tu chart). La fuente de verdad es la combinación chart + values, no el YAML en el cluster.

### 9.4 "`values.yaml` es solo configuración interna del chart"

No. **`values.yaml` es la API pública**. Cambiar sus keys sin bumpear major es romper a tus consumidores. Si tu chart no tiene `values.schema.json`, la API está sin contrato formal pero existe igual — y la rompes igual si cambias nombres por capricho.

### 9.5 "Lo meto en `values.yaml` porque es más cómodo (incluye el token de Slack)"

**No pongas secretos en `values.yaml`.** No se cifra, va a git, va al log del CI, va al Secret serializado de la release. Usa Sealed Secrets / External Secrets Operator / inyección de `--set` desde un secret manager.

### 9.6 "Si borro el Secret del release Helm sigue sabiendo que existe"

Falso. **El Secret ES el estado de la release**. Si lo borras, para Helm la release ya no existe. Los recursos aplicados por esa release siguen vivos (son objetos del API server independientes), pero quedan **huérfanos** — ningún `helm upgrade` futuro los reconoce.

### 9.7 "`helm search` sin repos añadidos encuentra todo"

Dos comandos distintos:

- **`helm search hub`** consulta **Artifact Hub** (red). No requiere repos locales.
- **`helm search repo`** consulta solo los repos que **tú** añadiste con `helm repo add`. Sin repos, no encuentra nada.

Confundirlos frustra: `helm search repo nginx` sin repos solo retorna vacío.

### 9.8 "Helm instala con `cluster-admin`"

Falso en Helm 3. Instala **con tus credenciales**. Si tu kubeconfig apunta a una ServiceAccount con RBAC limitado, Helm hereda esas limitaciones. Esto es exactamente lo que hace a Helm 3 seguro para multi-tenancy.

### 9.9 "Un chart es un `.yaml` grande"

No. Un chart es un **directorio con estructura obligatoria** (`Chart.yaml` + `values.yaml` + `templates/`...). Puede empaquetarse como `.tgz` para distribución. Pensarlo como "un YAML gigante" pierde la riqueza (dependencias, hooks, tests, helpers, schema).

---

## 10. Buenas prácticas (todavía conceptuales)

- **Antes de instalar un chart, lee su `values.yaml`.** `helm show values <chart>` es la primera parada. No instales nada cuya API no entiendes.
- **Pinea versiones.** `helm install ... --version 4.5.6`. Sin `--version`, Helm toma la última, lo que rompe reproducibilidad.
- **`helm template` antes de `helm install`.** Rinde localmente, revisa el YAML. Si estás en CI, `helm template | kubectl diff -f -` muestra qué cambiará.
- **No instales con tu usuario humano en producción.** CI/CD o Argo CD con una ServiceAccount acotada.
- **Separa `values-<env>.yaml` por entorno.** Un archivo por dev/stg/prod, con lo mínimo que diferencia (no copia de `values.yaml` completo).
- **No pongas secretos en `values.yaml`.** Nunca. Sin excepciones.
- **Internaliza el vocabulario.** Si en una reunión dices "release" cuando quieres decir "chart", pierdes credibilidad y confundes al equipo. El vocabulario es técnico.

---

## 11. Ejercicios recomendados

1. **`activities/01-install-helm-and-explore/`** — instala `helm`, mapea `helm env`, añade un repo, busca y describe charts. **Guided-lab**.
2. **`activities/02-read-values-of-popular-chart/`** — analiza `values.yaml` de 3 charts populares y argumenta por qué `values.yaml` **es** la interfaz del chart. **Independent**.

Son conceptuales/exploratorios. Si no puedes escribirlas con tus palabras, el modelo mental todavía no está firme.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Verdadero / falso:
- [ ] Un chart y una release son lo mismo.
- [ ] Helm 3 instala un Deployment llamado `tiller` en `kube-system`.
- [ ] El estado de una release vive en Secrets del namespace de la release.
- [ ] `helm search hub` consulta a los repos que añadiste con `helm repo add`.
- [ ] `values.yaml` es la API pública del chart.

**P2.** Define con tus palabras y da un ejemplo de cada uno: **chart**, **release**, **revision**, **repository**, **values**.

**P3.** Explica el flujo completo de un `helm install mi-nginx bitnami/nginx -f prod.yaml --version 15.0.0` desde que ejecutas el comando hasta que los Pods están corriendo. Nombra qué pasa en el cliente y qué pasa en el cluster.

**P4.** ¿Por qué Tiller fue abandonado en Helm 3? Da **tres** razones distintas y explica qué cambió operacionalmente al moverse a un modelo client-side.

**P5.** ¿Por qué decimos que `values.yaml` **es** la API pública del chart? Da al menos **tres** implicaciones concretas (p. ej. versionado, documentación, validación).

**P6.** ¿Qué diferencia hay entre `version` y `appVersion` en `Chart.yaml`? Da un ejemplo donde cambia uno sin el otro.

**P7.** Diferencia **`helm search hub`** vs **`helm search repo`**. ¿Qué red consultan? ¿Qué pre-requisito tiene cada uno?

**P8.** Un compañero propone usar `helm install` manual en producción desde su laptop con `--kubeconfig prod.yaml`. Da **tres** criterios por los que vas a decir que no (y qué propondrías en su lugar).

**P9.** Explica por qué `values.yaml` **no** es un buen lugar para secretos. ¿Qué alternativas conoces?

**P10.** Si borras el Secret `sh.helm.release.v1.mi-nginx.v3` manualmente, ¿qué pasa (a) con la release para Helm y (b) con los recursos del cluster que aplicó esa release?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Helm Docs* — <https://helm.sh/docs/>
- *Helm: Charts* — <https://helm.sh/docs/topics/charts/>
- *Helm: Chart Repositories* — <https://helm.sh/docs/topics/chart_repository/>
- *Helm: OCI-based Registries* — <https://helm.sh/docs/topics/registries/>
- *Helm: Chart Best Practices* — <https://helm.sh/docs/chart_best_practices/>
- *Artifact Hub* — <https://artifacthub.io/>
- *Helm 2 → 3 migration* — <https://helm.sh/docs/topics/v2_v3_migration/>

Lectura complementaria:

- Masse, Butcher — *Learning Helm* (O'Reilly, 2021). Introducción canónica a Helm 3.
- Blog post del equipo Helm sobre la decisión de eliminar Tiller — buscable en <https://helm.sh/blog/>.
- *CNCF Helm Project* page — <https://www.cncf.io/projects/helm/>.
