# ADR (reference) — argo-01-02: Elección GitOps para Fintech Nórdica

> Autoevaluación. **No** es una respuesta única — es *una* respuesta profesional y defendible. Si tu ADR argumenta "Flux" con criterios equivalentes, también es válido.

## Contexto

Fintech Nórdica es una empresa de 180 personas con **60 desarrolladores de aplicación** (40 backend Go/Java, 20 frontend) y un **equipo de plataforma reciente de 3 personas**. Opera ~25 microservicios desplegados hoy con **Jenkins + `helm upgrade --install`** sobre 3 clusters GKE (dev, stg, prod). El mandato es **migrar a GitOps**: cortar el acceso directo del CI al cluster, eliminar drift silencioso y mejorar auditoría para la próxima **auditoría PSD2**.

Datos relevantes para la decisión:

- **Ratio 60:3** entre desarrolladores de app y equipo de plataforma — cualquier flujo que genere tickets a plataforma por cada "¿está desplegada mi versión?" no escala.
- **Driver regulatorio** (PSD2): auditoría de cambios en prod obligatoria, trazabilidad completa.
- **25 microservicios con image bumps frecuentes** — image automation es driver real.
- **Postura CISO**: todo cambio por PR explícito; nada de clicks que modifiquen prod.
- **Lead de plataforma** experimentado en Flux v1 (sesgo legítimo).
- **Head of eng backend** quiere UI para reducir carga sobre plataforma.
- **3 clusters** hoy, pero el roadmap habla de expandir regionalmente (potencial multi-cluster real a 12–18 meses).

## Decisión

**Elegimos Argo CD** como motor GitOps principal. Configuramos:

- **Sync automático con `selfHeal: true`** en **dev** y **stg**.
- **Sync automático en prod**, pero cambios críticos en el repo de infra pasan por **PR con 2 revisores** (CODEOWNERS: equipo de release + 1 de plataforma).
- **UI expuesta en modo solo-lectura** para los 60 desarrolladores vía **SSO/OIDC** (grupos de Google Workspace); los permisos de write solo para el equipo de plataforma.
- **Projects** por dominio/equipo para boundaries.
- **Image automation** inicialmente con `argocd-image-updater` como add-on; **revisaremos a 6 meses** contra Flux image automation si fricciona.

Criterio decisivo: el **ratio 60:3** entre app y plataforma hace de la **visibilidad para no-plataforma** un requisito funcional, no cosmético. Argo CD la resuelve nativamente con UI + SSO + RBAC propio. Flux la resuelve con `weave-gitops` o adopción generalizada de `kubectl` por los desarrolladores — ambas opciones generan fricción adicional en este escenario.

## Consecuencias y disparadores (triggers)

### Consecuencias de la decisión

**Ganamos**:

- **Visibilidad para 60 desarrolladores** sin tickets a plataforma — UI con SSO + readonly.
- **Multi-cluster bien pulido** desde día 1 — importante para el roadmap regional (3 clusters hoy → N en 12–18 meses).
- **RBAC propio** (Projects + CSV) que da boundaries por equipo sin tocar RBAC del cluster todo el tiempo.
- **Cortamos el acceso directo** del CI al cluster — kubeconfig de admin no vive más en Jenkins.
- **Rollback trivial** (`git revert` en el repo de infra).
- **Auditoría PSD2**: history de Git = history del estado del cluster.

**Perdemos** (y lo asumimos):

- **Operación de Argo CD mismo** — upgrades, hardening, SSO, backup. Carga nueva para el equipo de plataforma (ya pequeño).
- **Image automation con add-on separado** (`argocd-image-updater`) — menos maduro que la contraparte Flux; un componente más que operar.
- **Riesgo cultural**: la UI, aunque esté en modo readonly para no-plataforma, es tentación para el equipo de plataforma — necesitamos política escrita: "cambios en prod se hacen por PR, no por click en Argo".
- **Dos puntos de RBAC** — Argo CD RBAC (CSV) + K8s RBAC. Más complejidad conceptual para el equipo.

### Disparadores para reconsiderar la decisión (concretos y medibles)

Si **cualquiera** se cumple, se reabre este ADR:

1. **Equipo de plataforma decrece a 1 persona** — operar Argo CD con 1 persona es exigente; Flux modular puede ser más barato (cada controller falla independiente).
2. **Número de clusters supera 10** (expansión regional multi-cluster real) y **ApplicationSets** no escala bien a nuestras necesidades.
3. **≥ 2 incidentes/trimestre atribuidos a "click en caliente"** en la UI de Argo CD — señal de que la política no se sostiene culturalmente.
4. `argocd-image-updater` **genera > 5 bugs/trimestre** o se queda sin mantenimiento activo — image automation es driver clave y debe funcionar.
5. **Requisito regulatorio nuevo** que exija "sin interfaz de escritura visual al cluster" — Flux cumple por diseño; Argo CD requiere lockdown adicional.
6. **Fuga de talento con experiencia Argo CD** y entrada de talento con experiencia Flux (señal cultural + práctica).
7. **Multi-tenancy** se vuelve crítico (muchos equipos aislados por hard-boundary) y los **Projects** de Argo CD no bastan — Flux + `kustomization` + impersonation puede ser más limpio.

## Alternativas descartadas

### Flux v2

- **Pros**: modular (`source-controller`, `kustomize-controller`, `helm-controller`, `image-automation-controller`); image automation **nativo**; filosofía "GitOps-only" alineada con el CISO; menos tentación de operar por UI.
- **Contras**: sin UI de edición → **mayor presión sobre el equipo de plataforma** para responder al "¿está desplegada mi versión?" de 60 desarrolladores (`weave-gitops` da visibilidad, pero menos pulida que la UI de Argo CD y es un deploy adicional); multi-cluster más manual; curva más empinada para equipos no `kubectl-fluent`.
- **Cuándo sí**: si el equipo de plataforma fuera mayor (5+); si el ratio con desarrolladores fuera más plano (p. ej. 1:5 en vez de 1:20); si la cultura ya fuera "kubectl para todo". **Es nuestra elección si cualquiera de los triggers 1, 3 o 5 se cumple.**

### Mantener Jenkins + `helm upgrade --install` (status quo)

- **Pros**: cero migración; el equipo lo opera hoy.
- **Contras**: **no es GitOps** — viola los principios 3 y 4; no cumple el mandato; auditoría PSD2 débil; blast radius del kubeconfig en Jenkins; drift silencioso. Es por lo que estamos aquí.
- **Cuándo sí**: nunca con este mandato. Si el mandato cambiara (sin PSD2 ni cross-cluster), el status quo podría defenderse por simplicidad, pero no es el caso.

### Jenkins X / Spinnaker

- **Pros**: proyectos maduros con comunidades existentes.
- **Contras**: adopción decreciente; menos talento en el mercado; features cubiertas por Argo CD/Flux con mejor momentum.
- **Cuándo sí**: si la organización ya tuviera una inversión fuerte y reciente en Spinnaker y hubiera talento interno — no es el caso.

### Combinación Argo CD + Flux (en dominios distintos)

- **Pros**: Flux para add-ons del cluster (ingress, cert-manager, Prometheus Operator); Argo CD para apps. Aprovecha fortalezas de cada uno.
- **Contras**: **dos sistemas que operar**, dos planos de autenticación, dos modelos mentales, dos puntos de falla. Para 3 personas de plataforma, es demasiado.
- **Cuándo sí**: equipos de plataforma grandes (10+) con dominios muy diferenciados. **No para 3 personas.**

### Crossplane como motor único

- **Pros**: gestiona recursos cloud **y** K8s desde K8s por GitOps. Reduce número de herramientas.
- **Contras**: Crossplane **no reemplaza** Argo CD/Flux (lo complementa: Crossplane manifests también se despliegan por GitOps). Añade curva propia, inmadurez en algunos providers, y nos distrae del objetivo principal.
- **Cuándo sí**: cuando ya tengamos GitOps consolidado y queramos extender el modelo a infraestructura cloud. **Fuera de scope de esta decisión.**

## Preguntas obligatorias

1. El argumento más débil es **"elegir por feature-table"**. Features cross-tool convergen con el tiempo — lo que falta hoy en uno llegará en 6 meses. Lo que **no converge** es la filosofía (UI vs kubectl-only), el modelo mental (Application monolítica vs controllers modulares) y el encaje organizacional (talento disponible, cultura de operación). Elegir porque "Flux tiene image automation nativo" ignora que `argocd-image-updater` cumple el mismo propósito; el criterio real es "qué equipo opera mejor cada uno".

2. **No descarta Argo CD**. La UI de Argo CD soporta **RBAC fino** vía Projects + CSV: puedes dar a un grupo SSO permisos de **solo lectura** (`p, role:dev, applications, get, */*, allow`) sin permiso de `sync` ni `update`. En nuestra decisión, los 60 desarrolladores entran con readonly; solo el equipo de release/plataforma puede ejecutar sync manual, y de todos modos el sync automático hace que no sea necesario. El CISO queda satisfecho: cambios reales siguen pasando por PR al repo de infra, con revisores obligatorios por branch protection.

3. "Argo CD invita a tocar en caliente" es un argumento **mitad técnico, mitad cultural** — técnico porque la UI expone acciones como "refresh", "hard refresh", "sync", "sync with options", "terminate op"; cultural porque **la organización decide** si esos botones se usan en prod o no. Mitigación si eligiéramos Argo CD (y lo hacemos): (a) RBAC estricto — nadie fuera de plataforma puede `sync` en prod; (b) política escrita: "cambios en prod se hacen vía PR al repo de infra, nunca vía UI"; (c) auditoría de acciones en Argo CD (log al SIEM); (d) `syncPolicy.automated` activo para que el "sync manual" no sea necesario en el flujo normal. La UI queda como **visor**, no como consola de operación.

4. **Argo CD** usa `argocd-image-updater` — add-on separado, se instala aparte, escribe commits al repo de infra cuando aparece imagen nueva en el registry que matchee un patrón. Menos integrado, add-on con su propia operación y upgrades. **Flux** tiene `image-automation-controller` + `image-reflector-controller` **nativos** (parte del core Flux) — misma funcionalidad, mejor integrado, misma UX de operación (`flux` CLI y CRs). Para 25 microservicios con image bumps frecuentes, Flux es **marginalmente mejor** aquí — pero no suficiente para flipear la decisión; el ratio 60:3 (que privilegia Argo CD por UI/SSO) pesa más. Si el `argocd-image-updater` fuera inmantenible, es nuestro **trigger #4** para reconsiderar.

5. **Escenario invertido**: Fintech Nórdica con **equipo de plataforma de 8 personas**, **5 desarrolladores internos** (producto es más plataforma que app), ya con experiencia Flux v1 de otra empresa del grupo, y **sin requisito de UI** porque los 5 desarrolladores son `kubectl-fluent`. En ese contexto Flux gana: modular (menos tentación de UI), image automation nativo (driver #1), equipo plataforma grande que puede operar los controllers independientes, cero demanda de visibilidad para no-plataforma. La decisión se invertiría a Flux sin dudarlo.

6. **Costo de migrar entre Argo CD y Flux a 2 años**: (a) **reescribir CRs** — Applications ↔ Kustomization/HelmRelease/GitRepository; convenciones diferentes de naming, hooks, waves; no es trivial, es ~1–2 semanas por app; (b) **re-aprender el modelo mental** del equipo (Projects vs Kustomization + impersonation); (c) **migrar RBAC** — Argo CD RBAC (CSV) y Flux delegado al RBAC del cluster son modelos distintos; (d) **migrar observabilidad y notifications** — dashboards diferentes, métricas con nombres distintos, Slack/webhook configurado contra el otro notification-controller; (e) **re-educar a 60 developers** sobre dónde ver el estado de sus deploys (si pierden la UI de Argo CD por Flux); (f) **gestión de secretos** si cambia el plugin (SOPS funciona en los dos pero con wiring diferente). Es un **proyecto de meses**, no un fin de semana — por eso el ADR hoy pesa.

7. El disparador que primero reabriría este ADR en Fintech Nórdica es probablemente el **#3 (incidentes por "click en caliente")**: pasa cuando la UI, aun con readonly para no-plataforma, se usa indebidamente por el equipo de plataforma en emergencias y genera post-mortems recurrentes. Lo mediría con un **count trimestral de incidentes etiquetados como `root-cause: manual-sync-prod`** o `root-cause: ui-direct-action`, revisado en la retro de operaciones. Umbral: **>= 2 por trimestre durante 2 trimestres consecutivos**. Si pasa, Flux (sin UI de edición) se vuelve una opción honesta frente a seguir luchando contra la cultura.
