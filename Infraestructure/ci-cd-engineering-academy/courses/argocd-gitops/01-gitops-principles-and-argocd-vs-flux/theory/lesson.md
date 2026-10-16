# Lección: Principios de GitOps y Argo CD vs Flux

> **ID:** `argo-01-gitops-principles-and-argocd-vs-flux` · **Nivel:** fundamentos · **Duración:** 2 h
> **Prerrequisitos:** curso **kubernetes** ≥ Nivel 2 (Deployments, RBAC, CRDs).

---

## 1. Introducción intuitiva

Supón que ya operas Kubernetes. Tienes un pipeline de GitHub Actions que, en cada merge a `main`, hace:

```yaml
- run: docker build -t ghcr.io/acme/web:$SHA .
- run: docker push ghcr.io/acme/web:$SHA
- run: aws eks update-kubeconfig --name prod
- run: kubectl set image deploy/web web=ghcr.io/acme/web:$SHA
```

Funciona. Un día te das cuenta de que **el pipeline tiene credenciales de admin del cluster de prod**. Si se compromete un token de GitHub, se compromete prod. Añades OIDC federation en lugar de llave estática. Mejor, pero el pipeline sigue siendo quien **ordena** al cluster. Otro día alguien hace `kubectl scale deploy/web --replicas=20` a mano durante un incidente y se olvida de dejarlo como estaba. Nadie lo nota — hasta la próxima vez que el pipeline despliega y vuelve a 3, y los 17 Pods extra desaparecen sin aviso. **Drift silencioso**. Más adelante alguien quiere hacer rollback a la versión de ayer y descubre que el estado "de verdad" vive en el cluster, no en Git: hay que recordar el SHA, re-ejecutar el pipeline con parámetros, y rezar.

Lo que pasó es común. Lo que empezó como "CI/CD moderno" terminó siendo una **plataforma frágil**: credenciales de larga vida en el pipeline, drift sin alertar, rollback no obvio, trazabilidad de cambios partida entre el repo de código y el estado real del cluster. Al cabo de un año, lo que tienes es una **mala reimplementación** de lo que ya existe: un modelo donde **Git es la fuente de verdad** y un **agente en el cluster** reconcilia continuamente.

Eso es **GitOps**. No es una herramienta; es un **modelo operativo** con cuatro principios formales (OpenGitOps). Argo CD y Flux son dos implementaciones de referencia. Entender los principios **antes** que las herramientas evita el error más caro del espacio: adoptar Argo CD manteniendo prácticas push, llamar "GitOps" al conjunto y perder los beneficios reales mientras cargas con la complejidad adicional. Este módulo construye el modelo mental correcto *antes* de instalar nada.

---

## 2. Fundamentos

Tres ideas que necesitas fijar antes de ver cualquier CR `Application` o `Kustomization`:

### 2.1 Git como fuente de verdad del estado deseado

En GitOps, el **estado deseado** del sistema (todos los manifests, charts, overlays, values por entorno) vive **íntegramente en Git**. No en `etcd`, no en el head del cluster, no en una base de datos de CD, no en la memoria de un ingeniero. Si quieres saber "qué debería estar corriendo en prod", abres el repo de infra en el commit del head de la rama que apunta a prod. Punto.

El cluster puede tener cosas que **no** están en Git (drift) — y el agente de reconciliación es quien decide qué hacer: alertar, revertir o ignorar según la política.

### 2.2 Pull desde dentro del cluster, no push desde fuera

En el modelo **push** tradicional, un pipeline externo (GitHub Actions, Jenkins, GitLab CI) tiene credenciales del cluster y ejecuta `kubectl apply` desde fuera. En el modelo **pull**, un **agente dentro del cluster** (Argo CD o Flux) lee desde Git y aplica. El pipeline externo **nunca** toca el cluster; solo escribe en Git.

Esto cambia radicalmente dónde viven las credenciales de admin del cluster: **dentro del cluster**, no en un servicio SaaS externo. Y cambia la dirección del flujo: *de dentro hacia fuera* (el cluster "va a buscar" lo que debe hacer).

### 2.3 Reconciliación continua, no "push and forget"

El agente no corre una vez por despliegue. Corre **permanentemente**, comparando `desired` (Git) vs `actual` (cluster). Si algo en el cluster se desvía (alguien hizo `kubectl edit` a mano, un controller mutó un campo, se cayó un Pod), el agente **lo nota y actúa**. Esto hace al drift **imposible por diseño** (o visible al instante si el agente está configurado para solo alertar).

Memoriza las tres ideas: **Git como fuente de verdad**, **pull desde el cluster**, **reconciliación continua**. Son el núcleo del modelo; los 4 principios formales de la §4 son una expresión más precisa de lo mismo.

---

## 3. Contexto histórico

GitOps no cayó del cielo. Viene de una línea de pensamiento sobre entrega continua que lleva una década:

- **2015–2016** — Equipos ya practicaban "infra as code" con Terraform y manifests en Git. El patrón de "pipeline que hace `kubectl apply`" era estándar.
- **2017** — **Weaveworks** acuña el término *GitOps* en un post describiendo cómo operaban sus clusters internamente. El punto novedoso: un **operator** dentro del cluster que reconcilia desde Git, en vez de un pipeline externo. Nace **Flux v1**.
- **2018** — **Argo CD** nace en **Intuit** como parte del ecosistema Argo (con Argo Workflows). Enfoque distinto: UI rica, concepto de `Application` como CR primera clase, soporte multi-cluster desde el inicio.
- **2020** — Argo CD y Flux ingresan a **CNCF** como proyectos incubating. El término "GitOps" ya es común, pero su definición formal es informal (depende de quién lo diga).
- **2021** — Se forma el **OpenGitOps Working Group** bajo CNCF para publicar una definición **neutral y formal**. Se liberan los **4 principios** (declarative, versioned & immutable, pulled automatically, continuously reconciled) en `opengitops.dev`. Argo CD y Flux son miembros fundadores; la definición es intencionalmente agnóstica de herramienta.
- **2021** — **Flux v2** sale como rediseño: en vez de un operator monolítico, un conjunto de **controllers modulares** (`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`, `image-automation-controller`). Alineado con la filosofía K8s de "muchos controllers pequeños".
- **2022** — Argo CD gradúa a **CNCF Graduated**. **ApplicationSets** maduran (generators para clusters, Git, PRs). Argo Rollouts se consolida como add-on canónico para progressive delivery sobre GitOps.
- **2023** — Flux gradúa a **CNCF Graduated**. **Multi-source Applications** llegan a GA en Argo CD (una Application que combina manifests de varios repos).
- **2024+** — Debate maduro de patrones de **promoción** entre entornos (branch vs folder vs image updater). **Backstage** y **IDPs** adoptan GitOps como fundamento. **Crossplane** se perfila como complementario (gestionar recursos de cloud *también* por GitOps).

Qué memorizar: GitOps **no inventó** la idea de "Git como fuente de verdad" (ya existía en IaC). Inventó el **modelo operativo pull con reconciliación continua** y lo nombró. **OpenGitOps** es la definición formal, publicada por un grupo neutral; Argo CD y Flux son dos implementaciones legítimas con filosofías distintas. Todo lo demás (ApplicationSets, Rollouts, image automation) es construcción sobre esa base.

---

## 4. Funcionamiento interno

### 4.1 Los 4 principios OpenGitOps

Publicados en `opengitops.dev` (v1.0.0, 2021). Son la **definición formal** y neutral de GitOps:

**1. Declarative** — "A system managed by GitOps must have its desired state expressed declaratively." El estado deseado se expresa como **datos** (YAML, HCL, Jsonnet, Starlark), no como una secuencia de comandos. Un script bash que hace `kubectl create` **no cuenta** como declarativo aunque viva en Git — da los mismos resultados por acción, no por descripción.

**2. Versioned and Immutable** — "Desired state is stored in a way that enforces immutability, versioning and retains a complete version history." Git lo cumple naturalmente (SHA inmutables, history linealizable). Un bucket S3 con los últimos manifests sin versionado **no cuenta**. Un repo de Git **sin branch protection** cumple el principio técnicamente pero sin disciplina — por eso en producción se exige PR + revisores + rulesets.

**3. Pulled Automatically** — "Software agents automatically pull the desired state declarations from the source." Un **agente dentro del sistema** halla y aplica, sin que un actor externo le mande cambios. Un pipeline CI que **hace** `kubectl apply` desde fuera **viola este principio**. El agente puede combinar **polling** (p. ej. cada 3 min) con **webhooks** (Git te avisa al push), pero quien decide aplicar es el agente, no el pipeline.

**4. Continuously Reconciled** — "Software agents continuously observe actual system state and attempt to apply the desired state." El agente no corre una vez por commit. Corre **todo el tiempo**, comparando `desired` (Git) vs `actual` (cluster) y actuando (o alertando) ante desviaciones. Esto es lo que elimina el drift silencioso.

Los 4 son **conjunción** — un sistema que cumple 3 de 4 no es GitOps, es "GitOps-washing". El caso típico: declarative + versioned + pull **pero** solo "aplicar al commit" (no continuamente). Resultado: drift sin alertar, igual que antes.

### 4.2 Push vs pull en diagramas

**Modelo push** (anti-GitOps en sentido estricto):

```
┌──────────────┐   build+push    ┌──────────────┐
│  Developer   │────────────────►│   Registry   │
│  commit code │                 │   (imagen)   │
└──────┬───────┘                 └──────────────┘
       │ push
       ▼
┌──────────────┐
│  Repo codigo │
└──────┬───────┘
       │ trigger
       ▼
┌──────────────────────────────────┐
│  CI runner (GitHub Actions)      │
│    kubeconfig con credenciales   │
│    de admin del cluster target   │
│    kubectl apply -f ...          │────────────┐
└──────────────────────────────────┘            │
                                                │ apply vía API
                                                ▼
                                     ┌────────────────────┐
                                     │  Cluster target    │
                                     │  (prod/stg/dev)    │
                                     └────────────────────┘
```

Problema: **credenciales de admin del cluster viven en el CI runner** (y en secretos del repo). Blast radius enorme si se compromete el runner.

**Modelo pull** (GitOps):

```
┌──────────────┐   build+push    ┌──────────────┐
│  Developer   │────────────────►│   Registry   │
│  commit code │                 │   (imagen)   │
└──────┬───────┘                 └──────────────┘
       │ push                            ▲
       ▼                                 │ pull imagen
┌──────────────┐                         │
│  Repo codigo │                         │
└──────┬───────┘                         │
       │ trigger CI                      │
       ▼                                 │
┌──────────────────────────────────┐     │
│  CI runner                       │     │
│  (SIN credenciales de cluster)   │     │
│  solo: build+push imagen +       │     │
│  commit al repo de infra con     │     │
│  nuevo image tag                 │     │
└──────┬───────────────────────────┘     │
       │ commit                          │
       ▼                                 │
┌──────────────┐                         │
│  Repo infra  │◄────────────────┐       │
│  (manifests) │ pull            │       │
└──────────────┘                 │       │
                                 │       │
                        ┌────────┴───────┴──────┐
                        │  Agente GitOps        │
                        │  (Argo CD / Flux)     │
                        │  DENTRO del cluster   │
                        │  pulls Git + aplica   │
                        │  reconcilia continuo  │
                        └───────────┬───────────┘
                                    │ apply vía API local
                                    ▼
                        ┌───────────────────────┐
                        │  Cluster target       │
                        └───────────────────────┘
```

Observa: **el CI runner no toca el cluster**. Solo escribe en Git (commits al repo de infra). Las credenciales de admin viven **dentro** del cluster, en el agente. Si se compromete el runner, el atacante puede subir imágenes maliciosas o manipular PRs del repo de infra — pero no tiene acceso directo al cluster. El PR al repo de infra pasa por **branch protection + revisores**, que es la última línea.

### 4.3 "CI builds artifacts, CD reconciles state"

En el mundo push, la línea entre CI y CD es borrosa: el mismo pipeline construye y despliega. En GitOps hay una **línea limpia**:

- **CI** — todo lo que termina produciendo un **artefacto inmutable**: compilar, testear, construir imagen OCI, firmar (cosign), subir a registry, analizar vulnerabilidades. Puede terminar también haciendo un **commit al repo de infra** bumping el image tag. Esto sigue siendo CI (produce commit, no estado en el cluster).
- **CD** — lo hace el **agente** en el cluster. Pulls del repo de infra, reconcilia, aplica. No hay "pipeline CD" en el sentido tradicional.

Esta separación tiene consecuencias concretas:

- El **CI runner nunca más** necesita `kubeconfig` del cluster target.
- El **repo de infra** se vuelve el único "pane of glass" del estado deseado — útil para auditoría, revisión, políticas.
- El **rollback** es `git revert` del commit en el repo de infra. El agente reconcilia hacia la versión anterior sin más intervención.

### 4.4 Repo de código vs repo de infra

Patrón canónico: **dos repos** separados.

- **Repo de código** — contiene el source de la app, su Dockerfile, su chart Helm (o Kustomize base), sus tests. CI corre en cada PR.
- **Repo de infra** — contiene los manifests desplegables por entorno: values por entorno, overlays, image tags concretos. Argo CD/Flux leen de aquí.

Por qué separarlos:

- **Diferentes ciclos de vida**: el código cambia a diario; la configuración de prod cambia menos y con más revisión.
- **Diferentes ownership**: el equipo de la app owns el repo de código; el equipo de plataforma owns parte del repo de infra; CODEOWNERS en infra protege prod.
- **El pipeline del repo de código** termina con un commit al repo de infra (bump de image tag) — un salto *entre repos* que separa claramente "producir artefacto" de "declarar estado".

Alternativa: **monorepo** con `/app/` y `/infra/`. Válido para orgs pequeñas; se complica con muchas apps y con diferentes políticas de merge por carpeta.

### 4.5 Argo CD vs Flux — filosofías

Ambos cumplen OpenGitOps. Difieren en **estética y modelo**:

**Argo CD**:

- Modelo centrado en `Application` como CR primera clase (un objeto por app).
- **UI web rica** — grafos de dependencias, diff visual, logs, sync manual con un click. Pensado para que humanos *vean* el estado.
- **RBAC propio** (CSV) además del RBAC del cluster.
- Multi-cluster desde el inicio (una instalación controla N clusters target).
- Image automation vía add-on separado (`argocd-image-updater`), menos maduro que la contraparte de Flux.
- Cultura: "GitOps + UX para equipos de app". Más adoptado en empresa.

**Flux v2**:

- Modelo de **controllers modulares**: `source-controller` (traer Git/Helm/OCI), `kustomize-controller` (aplicar `Kustomization`), `helm-controller` (aplicar `HelmRelease`), `notification-controller`, `image-automation-controller`.
- **Sin UI de edición** — hay UI de lectura (`weave-gitops`), pero por diseño **todo cambio pasa por Git**. Es una característica, no un defecto.
- **Image automation nativo** (parte del core).
- Cultura: "GitOps estricto, filosofía Unix". Favorito de plataformas que quieren controlar todo por CRs y usar `kubectl` como única interfaz de operación.
- Multi-tenancy via `Kustomization` con impersonation + ServiceAccount — más explícito.

Resumen tabular:

| Dimensión | Argo CD | Flux v2 |
|-----------|---------|---------|
| UI de edición | Sí (rica) | No (por diseño) |
| CR principal | `Application` | `Kustomization`, `HelmRelease`, `GitRepository`, ... |
| Multi-cluster | Nativo, bien pulido | Posible, menos opinado |
| Image automation | Add-on separado | Nativo |
| RBAC propio | Sí (CSV) | Delegado al RBAC del cluster |
| Modelo | Monolítico (con subcomponentes) | Modular (controllers independientes) |
| Curva | Más amigable con UI | Más "kubectl-only" |
| Cuándo | Equipos de app, visibilidad para no-plataforma, multi-cluster desde día 1 | Equipos de plataforma, cultura "GitOps-only", CRs como única interfaz |

Elegir uno no es "cuál es mejor" — es **cuál encaja con la cultura y los requisitos**. Ambos son correctos y maduros. La actividad 02 de este módulo pide hacer esta elección con criterios.

### 4.6 Dónde se rompe la ilusión: GitOps-washing

Patrones comunes que **parecen** GitOps pero no lo son:

- **"Instalamos Argo CD y seguimos usando `kubectl apply` desde el pipeline"** — Argo CD existe pero el pipeline sigue haciendo push al cluster. Viola el principio 3 (pulled). El agente no es el actor que aplica.
- **"Nuestro Git tiene todo pero el pipeline hace `helm upgrade` desde CI"** — Git tiene los manifests, pero quien aplica es el pipeline, no un agente in-cluster. Mismo problema.
- **"El agente aplica, pero solo al merge; no reconcilia"** — se cumple pull (al merge) pero **no** continuo. Drift silencioso, igual que en push.
- **"Tenemos Argo CD pero los manifests reales están en S3 (versionado desactivado)"** — se viola el principio 2 (versioned & immutable). Sin history no hay auditoría ni rollback trivial.
- **"Los developers hacen `kubectl edit` en prod en incidentes"** — el agente los revierte (si `selfHeal: true`), bien; pero si `selfHeal` está off, el drift queda. Es un problema cultural, no técnico.
- **"Secretos en claro en Git"** — no viola OpenGitOps per se (es declarativo + versionado + pulled + reconciliado), pero es malpráctica catastrófica. GitOps **exige** disciplina de secretos (SOPS/Sealed Secrets/ESO) — se cubre en `argo-09`.

El patrón para detectar GitOps-washing: **recorre los 4 principios uno por uno** y pregunta "¿este sistema lo cumple sin asteriscos?". Si falta uno, no es GitOps.

### 4.7 Por qué pull reduce la superficie de credenciales

Pensemos en términos de **blast radius** si se compromete cada actor:

| Compromiso | Push | Pull |
|------------|------|------|
| CI runner | **Admin del cluster** (vía kubeconfig del runner) | Puede subir imágenes y abrir PRs al repo de infra |
| Repo de código | Puede inyectar código malicioso; vía CI puede impactar cluster | Puede inyectar código; necesita además pasar revisión en repo de infra |
| Repo de infra | N/A o leve | Puede escribir manifests maliciosos; el agente los aplicaría |
| Agente (Argo/Flux) | N/A | Admin del cluster target |

En push, **el runner es el punto más caliente** y es externo al cluster. En pull, el punto más caliente es el **agente in-cluster** (más fácil de endurecer, mismas políticas que el resto de workloads del cluster, no expuesto a Internet) y el **repo de infra** (defendido con branch protection + revisores + rulesets — una interfaz humana explícita).

La magnitud real: en una org típica, decenas de pipelines distintos tienen kubeconfig con admin del cluster en el modelo push. Con pull, **nadie fuera del cluster** tiene ese kubeconfig; el agente lo tiene y ya.

---

## 5. Ejemplo mínimo

Nada aquí requiere cluster — es lectura comparada. Imagina el mismo cambio de versión (`web:1.2.0 → web:1.2.1`) en los dos modelos.

**Push** (anti-GitOps):

```
1. Developer merge PR al repo de código con bump de versión.
2. GHA se dispara:
     - build imagen ghcr.io/acme/web:1.2.1
     - push al registry
     - kubectl set image deploy/web web=ghcr.io/acme/web:1.2.1
       (usando kubeconfig con admin de prod)
3. Cluster ejecuta la rolling update.
4. Si alguien hace `kubectl scale deploy/web --replicas=20` mañana
   por un pico de carga, se queda en 20 hasta la próxima vez
   que el pipeline despliegue — luego vuelve a 3 sin aviso.
5. Rollback: re-ejecutar pipeline con SHA viejo o kubectl set image
   a la imagen anterior manualmente.
```

**Pull** (GitOps):

```
1. Developer merge PR al repo de código.
2. GHA se dispara:
     - build imagen ghcr.io/acme/web:1.2.1
     - push al registry
     - clone repo de infra, bump en envs/prod/values.yaml
       (image.tag: 1.2.1), commit + PR al repo de infra.
3. PR revisado y merge al repo de infra (branch protection).
4. Argo CD, que hace WATCH del repo de infra (polling 3 min + webhook),
   detecta el nuevo commit:
     - renderiza (helm template) el chart con los values nuevos.
     - compara desired vs actual.
     - aplica el cambio (rolling update) vía API server del cluster
       usando sus propias credenciales (in-cluster).
5. Si alguien hace `kubectl scale ... --replicas=20`:
     - con `selfHeal: true`, Argo CD lo revierte en el próximo tick.
     - con `selfHeal: false`, marca la Application OutOfSync y alerta.
     En cualquier caso, el drift es VISIBLE, no silencioso.
6. Rollback: `git revert` del commit en el repo de infra.
   Argo CD reconcilia hacia la versión anterior. No hay pipeline que correr.
```

Observa tres cosas:

1. **Dónde viven las credenciales**: en push, en el runner. En pull, en el agente in-cluster.
2. **Cómo se maneja el drift**: en push, silencioso. En pull, visible o auto-revertido.
3. **Cómo se hace rollback**: en push, re-ejecutando pipelines. En pull, `git revert`. El estado del cluster persigue a Git siempre.

Este es el patrón entero. Lo demás (ApplicationSets, waves, hooks, Rollouts, secrets) construye sobre esta base.

---

## 6. Implementación progresiva

Un camino de aprendizaje realista — qué entender *antes* y qué *después*:

**Paso 1 — Modelo mental (este módulo).** 4 principios, push vs pull, GitOps-washing, Argo CD vs Flux filosóficamente. Sin tocar nada.

**Paso 2 — Install y primera Application (`argo-02`).** Instalar Argo CD en cluster local, acceder por UI/CLI, conectar un repo público, primera `Application` plain YAML, diferencia sync status vs health status.

**Paso 3 — Anatomía del `Application` (`argo-03`).** `spec.source` / `spec.destination` / `spec.syncPolicy`, `ignoreDifferences`, por qué `targetRevision: HEAD` es trampa.

**Paso 4 — Sources (`argo-04`).** Helm, Kustomize, plain YAML, multi-source. Cómo `repo-server` renderiza. Por qué los hooks de Helm quedan limitados.

**Paso 5 — Sync strategies, Projects, ApplicationSets (`argo-05` → `argo-07`).** Automated sync, waves, hooks; multi-tenancy; generación dinámica de Applications.

**Paso 6 — Multi-cluster, secrets, Rollouts, hardening (`argo-08` → `argo-11`).**

**Paso 7 — Platform patterns y Flux (`argo-12` → `argo-13`).**

Lo importante de **este módulo** es que ninguno de los pasos siguientes tiene sentido si no tienes claro **por qué** GitOps existe y **qué no es**. Si adoptas Argo CD manteniendo push, pagas la complejidad sin cobrar los beneficios.

---

## 7. Aplicación profesional

En una organización madura, GitOps **no es un detalle** del pipeline: es el **contrato de plataforma**. Flujo típico:

```
Developer         CI (GHA)                  Repo infra              Agente in-cluster       Cluster
─────────         ────────                  ──────────              ─────────────────       ───────
edita code
abre PR  ────►   lint + test
                 (nada toca cluster)
merge code ──►   build imagen
                 firma cosign
                 scan vulns
                 push a GHCR
                 clone repo infra
                 bump envs/dev/values.yaml
                 PR al repo infra ─────────► review (CODEOWNERS)
                                             merge a main
                                                                    WATCH detecta commit
                                                                    helm template + diff
                                                                    aplica vía API server ──► rolling update
                                                                    reconcilia continuo        drift revertido
                                                                                               o alertado
                                             (promoción a stg/prod:
                                              PR del equipo de release
                                              merge → agente aplica)
```

Puntos clave de la práctica profesional:

- **Separación limpia CI / CD**: CI nunca tiene `kubeconfig` del cluster. Solo escribe en Git (y en registries).
- **Repo de infra protegido**: branch protection, CODEOWNERS, rulesets. Es la nueva "consola de admin".
- **Promoción explícita**: dev → stg → prod se promociona por **PR al repo de infra** (branch-based) o por **merge entre overlays** (folder-based). No por "re-ejecutar el pipeline con otro `--namespace`".
- **Secretos nunca en claro**: SOPS, Sealed Secrets o ESO (preferido). Se cubre en `argo-09`.
- **Admission policies obligatorias**: Kyverno/OPA exigen imagen firmada, Pod Security `restricted`.
- **Observabilidad del agente mismo**: métricas de `application-controller`, dashboards de sync latency y drift.
- **Rollback = `git revert`**: documentado en runbooks. Nunca "corre tal pipeline con tales parámetros".

Nada de esto es exclusivo de Argo CD o Flux — es el patrón **GitOps + policy + observabilidad**. La elección entre Argo CD y Flux es una **elección estética y organizacional**, no un cambio de modelo.

---

## 8. Trade-offs

### 8.1 GitOps vs push CI/CD tradicional

| Dimensión | Push CI/CD | GitOps (pull) |
|-----------|-----------|---------------|
| Credenciales del cluster | En el runner (externo) | En el agente (interno) |
| Drift | Silencioso | Visible o auto-revertido |
| Rollback | Re-ejecutar pipeline | `git revert` |
| Multi-cluster | Un pipeline por cluster, cada uno con sus creds | Un agente (o pocos) con registry de clusters |
| Auditoría | Logs de pipeline + logs de kubectl | History de Git = history del cluster |
| Curva | Baja (si ya hay CI) | Media (nuevo componente que operar) |
| Operación extra | Mantener el pipeline | Mantener el agente (Argo/Flux) |

GitOps **introduce complejidad** (el agente es software que operar) a cambio de **eliminar categorías enteras de problemas** (drift, credenciales dispersas, rollback obtuso).

### 8.2 Argo CD vs Flux (resumen operativo)

Ya cubierto en §4.5. Resumen de la decisión:

- **Argo CD** por default si: equipo de app grande que valora UI; multi-cluster desde día 1; organización que ya usa el ecosistema Argo (Rollouts, Workflows).
- **Flux** por default si: equipo de plataforma pequeño; cultura "kubectl-only"; preferencia por controllers modulares y filosofía Unix; image automation central en el workflow.
- **Ninguno de los dos** es malo. Es raro que la decisión se arrepienta — las migraciones son posibles pero no triviales.

### 8.3 GitOps vs IaC (Terraform / Pulumi)

Cercanos pero no equivalentes:

- **IaC** cubre bien recursos de cloud (VPCs, buckets, DBs, DNS). Tiene state file (puede ser fuente de verdad, pero es un state separado de Git).
- **GitOps** cubre bien recursos de K8s. Git **es** la state.
- **Complementarios**: IaC provisiona el cluster (y VPC/IAM/DNS); GitOps gestiona lo que corre dentro. **Crossplane** intenta cerrar la brecha gestionando también recursos cloud desde K8s por GitOps.

### 8.4 Pull-only vs híbrido

Un patrón de transición común: adoptar Argo CD para **workloads de app** y mantener el pipeline push para **add-ons del cluster** (ingress, cert-manager). Funciona como escalón, pero es **GitOps parcial** — hay drift posible en los add-ons. Lo correcto a mediano plazo es que **todo** (incluido el propio Argo CD) sea gestionado por GitOps (`argo-08`).

---

## 9. Errores frecuentes

### 9.1 "Instalé Argo CD, ya hago GitOps"

No. GitOps es un modelo operativo. Si el pipeline sigue haciendo `kubectl apply` directo al cluster, o si editas en caliente en producción, Argo CD solo añade complejidad sin cobrar beneficios. El modelo es la práctica, no la herramienta.

### 9.2 "Nuestro repo de infra tiene todo, pero el pipeline hace `helm upgrade`"

Violación del principio 3 (pulled). Quien aplica debe ser el agente in-cluster, no el pipeline externo. Si solo tienes Helm sin agente, no es GitOps — es "Helm desde CI con los manifests en Git".

### 9.3 "El agente aplica cuando hay commit, no continuamente"

Violación del principio 4 (continuously reconciled). Resultado: drift silencioso igual que en push. Argo CD por default reconcilia cada 3 minutos; Flux cada 1 minuto. Si lo apagas, pierdes el núcleo del modelo.

### 9.4 "Secretos en claro en Git porque es privado"

Técnicamente cumple los 4 principios de OpenGitOps, pero es **malpráctica catastrófica**: cualquier filtración del repo = filtración de secretos; auditoría pobre; rotación imposible. GitOps exige disciplina: SOPS, Sealed Secrets, ESO (preferido). Un repo privado no es un vault.

### 9.5 "Elegir Argo CD vs Flux por features"

Las features convergen con el tiempo. La decisión real es **filosófica y organizacional**: UI vs kubectl-only, equipo de app vs equipo de plataforma, cultura de PR vs cultura de operación interactiva. Elegir por feature-table es engañarse — en 12 meses esa feature estará en los dos.

### 9.6 "Monorepo con app + infra: mismo PR cambia código y manifests"

Posible, pero mezcla ciclos de vida: cambiar código → bump image tag → mismo PR. Pierdes la separación limpia CI/CD. Para equipos pequeños puede ser ok; a escala rompe (quién revisa cambios de infra vs quién revisa código es gente distinta con permisos distintos).

### 9.7 "Un pipeline push 'rápido' para hotfixes"

Antipatrón clásico: "GitOps en días normales, push para emergencias". Resultado: dos caminos distintos a producción, uno de ellos sin trazabilidad. En una emergencia real quieres **más** disciplina, no menos. Lo correcto es que el agente tenga sync manual gatillable con un click y la ruta sea siempre la misma.

### 9.8 "GitOps resuelve la seguridad"

No. GitOps **reduce la superficie de credenciales** (ya es mucho). No reemplaza admission policies, no cifra secretos, no previene imágenes maliciosas. Es una capa; sigue necesitando Kyverno/OPA, cosign, scanning, RBAC estricto.

### 9.9 "Elegimos Flux porque es más 'puro'"

Argumento débil. Lo que cuenta es el ajuste con la organización. Si tu equipo de app pide UI para ver el estado de deploys y vas a decir que no "por pureza", prepárate para fricción constante. "Puro" sin encaje organizacional es un ADR mal escrito.

---

## 10. Buenas prácticas (todavía conceptuales)

- **Lee los 4 principios en voz alta ante cualquier pipeline nuevo.** Si falla uno, no es GitOps. Si falla uno y lo llamas GitOps, es washing.
- **Repo de código ≠ repo de infra** por default. Monorepo solo con intención explícita.
- **CI nunca tiene `kubeconfig` del cluster target.** Si lo tiene, tu CD no es GitOps aunque exista un agente.
- **El agente reconcilia continuo**, no solo al commit. `selfHeal` on en dev; en prod con criterio (puede ser off + alertar, para dar ventana a incidentes humanos).
- **Rollback = `git revert`.** Documentado y practicado.
- **Secretos nunca en claro**, aunque el repo sea privado. ESO/SOPS/Sealed Secrets desde el inicio.
- **Promoción explícita por PR**, no por "re-ejecutar con otros valores".
- **Elegir Argo CD vs Flux por organización**, no por features. Documentar la decisión como ADR.
- **El propio agente también por GitOps** (meta-GitOps). Lo veremos en `argo-08`.
- **Antes de instalar nada, entiende el modelo.** Este módulo existe por eso.

---

## 11. Ejercicios recomendados

1. **`activities/01-identify-gitops-washing/`** — audita 5 escenarios y clasifica cuáles son GitOps y cuáles washing, nombrando el principio violado y proponiendo la corrección mínima. **Independent**.
2. **`activities/02-adr-argocd-vs-flux-first-pass/`** — escribe un ADR corto defendiendo una elección Argo CD vs Flux para una organización con restricciones dadas. **Independent**.

Son conceptuales. Si no puedes escribirlas con tus palabras, el modelo mental todavía no está firme.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Verdadero / falso:
- [ ] Instalar Argo CD convierte un pipeline en GitOps.
- [ ] Un repo de infra con secretos en claro cumple los 4 principios OpenGitOps.
- [ ] "Reconciliación continua" significa que el agente aplica solo cuando hay un commit nuevo.
- [ ] En el modelo pull, el CI runner nunca tiene `kubeconfig` del cluster target.

**P2.** Enumera los **4 principios OpenGitOps** y, para cada uno, da un ejemplo de **violación** típica.

**P3.** Explica, en tus palabras y sin diagramas, cómo cambia la **superficie de credenciales** al pasar de push a pull. ¿Dónde viven las credenciales de admin del cluster en cada modelo?

**P4.** Un pipeline hace `kubectl apply -f manifests/` desde GHA al cluster, con los manifests versionados en Git. ¿Es GitOps? Justifica mencionando los principios.

**P5.** ¿Cuál es la diferencia funcional entre un `git revert` como rollback (GitOps) y "re-ejecutar el pipeline con el SHA viejo" (push)? Nombra al menos **tres**.

**P6.** Compara **Argo CD** y **Flux** en tres dimensiones: UX, modularidad, image automation. ¿Cuál elegirías para un equipo de **plataforma pequeño** y cuál para un equipo de **app grande** con desarrolladores que quieren ver el estado de sus deploys?

**P7.** Un compañero propone: "en vez de montar Argo CD, dejemos el pipeline haciendo `kubectl apply` pero cifrado con sops y PRs al repo de manifests". Da **tres** razones por las que esto **no** es GitOps aunque suene parecido.

**P8.** Explica por qué separar **repo de código** y **repo de infra** suele ser la mejor práctica a escala. ¿Cuándo tiene sentido un monorepo?

**P9.** Un equipo adopta Argo CD pero mantiene un pipeline push "rápido" para hotfixes. ¿Qué principio viola y qué consecuencia práctica tendrá en incidentes?

**P10.** Si tuvieras que convencer a un escéptico de GitOps en 90 segundos, ¿qué **dos problemas concretos** del modelo push atacarías primero?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- **OpenGitOps principles** — <https://opengitops.dev/>
- *GitOps Working Group — Principles v1.0.0* — <https://github.com/open-gitops/documents/blob/main/PRINCIPLES.md>
- **Argo CD** — <https://argo-cd.readthedocs.io/>
- *Argo CD architecture* — <https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/>
- **Flux v2** — <https://fluxcd.io/flux/>
- *Flux v2 concepts* — <https://fluxcd.io/flux/concepts/>
- *Argo vs Flux (CNCF comparison, community-maintained)* — buscar comparativas CNCF recientes.

Lectura complementaria:

- Weaveworks (2017) — *GitOps: Operations by Pull Request* (post original que acuñó el término).
- Beyer, Jones, Petoff — *Site Reliability Engineering* (O'Reilly). Capítulos de release engineering para contexto de "cambio desde Git".
- Humble, Farley — *Continuous Delivery* (Addison-Wesley). Fundamento de "artefactos inmutables + pipelines" sobre el que GitOps construye.
- Codefresh / Akuity (mantenedores Argo CD) — blogs técnicos sobre patrones avanzados.
- *Flux adopters* — <https://fluxcd.io/adopters/>
- *Argo CD adopters* — <https://github.com/argoproj/argo-cd/blob/master/USERS.md>
