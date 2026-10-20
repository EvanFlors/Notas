# Examen de certificación — Argo CD y GitOps

- **Curso:** `argocd-gitops`
- **Nivel:** intermedio-avanzado (módulos `argo-04` a `argo-11`, con base asumida en `argo-01..03`)
- **Dimensiones evaluadas:** todas (conceptual, operativa, arquitectónica)
- **Duración:** 90–120 minutos (sugerido: 25 min conceptual + 55 min operativo + 35 min arquitectónico, resto buffer)
- **Modalidad:** take-home con validación automatizada del ejercicio operativo + defensa oral opcional (15 min) para el ejercicio arquitectónico
- **Umbral de aprobación:** **70%** del total ponderado, con un mínimo de 50% en cada dimensión (no se aprueba sacando 100% en conceptual y 0% en operativo)
- **Materiales permitidos:** documentación oficial de Argo CD/Rollouts/ESO, código propio del curso. Prohibido: pedir el examen entero a un LLM. Permitido: usar LLM para consultas acotadas de sintaxis (declarar en entrega).

> **Prose en español, código/CLI/manifests en inglés.** Las respuestas deben entregarse en español salvo los artefactos técnicos (YAML, comandos, logs, nombres de recursos).

---

## 1. Matriz de competencias evaluadas

Ver [`competency-matrix.yaml`](./competency-matrix.yaml) para la fuente única de verdad. Resumen:

| ID  | Competencia                                                                 | Dim.                       | Peso | Evaluada en            |
|-----|-----------------------------------------------------------------------------|----------------------------|------|------------------------|
| C1  | Principios OpenGitOps y detección de GitOps-washing                         | conceptual                 | 5    | Q1                     |
| C2  | Sync vs health status; impacto de selfHeal/prune                            | conceptual                 | 6    | Q2                     |
| C3  | `ignoreDifferences` con HPA/VPA y fight-loop                                | conceptual, operativa      | 6    | Q3, OP-2               |
| C4  | Argo CD renderiza Helm (template, no install); hooks limitados              | conceptual                 | 6    | Q4                     |
| C5  | Política de sync por ambiente; sync-waves + PreSync hooks                   | conceptual, op., arq.      | 10   | Q5, OP-3, ARCH         |
| C6  | Argo CD RBAC vs K8s RBAC; auditar `*/*`                                     | conceptual, arq.           | 8    | Q6, ARCH               |
| C7  | app-of-apps vs ApplicationSet; PR previews                                  | conceptual, op., arq.      | 10   | Q7, OP-4, ARCH         |
| C8  | In-cluster vs control-plane multi-cluster; bootstrap chicken-and-egg        | arquitectónica             | 8    | Q8, ARCH               |
| C9  | Estrategia de secretos (ESO/SOPS/Sealed/CSI) por blast radius               | conceptual, arq.           | 8    | Q9, ARCH               |
| C10 | Analysis SLI-based; split por replicas vs traffic management                | conceptual, arq.           | 8    | Q10, ARCH              |
| C11 | Hardening priorizado de Argo CD (SSO, admin local, Pod Security, backup)   | conceptual, op., arq.      | 10   | Q11, OP-5, ARCH        |
| C12 | Diagnóstico de Application OutOfSync/Degraded                               | operativa                  | 10   | OP-1, OP-2             |
| C13 | `targetRevision=HEAD` como anti-patrón; branch vs tag vs SHA                | conceptual                 | 5    | Q12                    |

- **Reparto por dimensión:** conceptual 35% / operativa 40% / arquitectónica 25%.
- **Peso total:** 100 puntos (ver sub-pesos por sección más abajo).

---

## 2. Preguntas conceptuales (35 puntos — ~25 min)

Formato: respuesta corta (3–8 líneas). Se penaliza copiar la definición del material sin ejemplo o justificación. Se premia la respuesta que explica **por qué** o **cuándo**.

### Q1 (C1 — 3 pts) — GitOps-washing

Un equipo afirma hacer GitOps porque su pipeline de GitHub Actions corre `kubectl apply -f manifests/` contra el cluster de producción tras cada merge a `main`, y los manifests viven en Git versionados.
**(a)** ¿Qué principio(s) de OpenGitOps viola este pipeline y por qué?
**(b)** Describe un escenario concreto donde este modelo falla silenciosamente y Argo CD lo detectaría.

### Q2 (C2 — 4 pts) — Sync vs health

Una Application reporta `Sync Status: Synced` y `Health Status: Degraded`.
**(a)** ¿Qué significa cada campo y por qué pueden estar en estos valores a la vez?
**(b)** ¿Cambia la respuesta de Argo CD si `syncPolicy.automated.selfHeal=true` está habilitado? Justifica.

### Q3 (C3 — 4 pts) — HPA y `ignoreDifferences`

Tu Application despliega un `Deployment` con `replicas: 3` en Git. En el cluster hay un `HorizontalPodAutoscaler` que lo escaló a 7.
**(a)** ¿Qué pasa si **no** usas `ignoreDifferences`? Describe el fight-loop paso a paso.
**(b)** Escribe el fragmento YAML de `spec.ignoreDifferences` que corrige el problema.

### Q4 (C4 — 4 pts) — Helm bajo Argo CD

**(a)** Explica por qué un chart con un hook `pre-install` para crear un `Secret` no se comporta igual bajo Argo CD que bajo `helm install`.
**(b)** ¿Cuál es la alternativa recomendada dentro de Argo CD y qué anotación usa?

### Q5 (C5 — 3 pts) — selfHeal por ambiente

Defiende con un argumento operativo concreto por qué `selfHeal=true` tiene sentido en `dev` pero suele ser contraproducente en `prod` durante un incidente activo.

### Q6 (C6 — 3 pts) — Doble RBAC

Un desarrollador puede ver y sincronizar Applications en Argo CD (rol `role:dev`), pero cuando sincroniza, los recursos no se crean en el cluster target. ¿Dónde buscas el fallo y por qué puede estar en **dos** capas distintas de RBAC?

### Q7 (C7 — 3 pts) — ApplicationSet vs app-of-apps

Da **un** caso donde app-of-apps es la mejor opción y **un** caso donde ApplicationSet lo supera claramente. No basta con "ApplicationSet es más nuevo".

### Q8 (C8 — 3 pts) — Argo CD auto-gestionado

Argo CD gestiona el chart del propio Argo CD vía una Application en Git. Describe un cambio concreto en ese chart que podría dejar el cluster **sin forma de reconciliar** y cómo lo mitigas antes de mergear.

### Q9 (C9 — 3 pts) — Blast radius de secretos

Compara ESO vs SOPS/KSOPS en términos de **blast radius** si se filtra la credencial maestra (IAM role del controller vs clave KMS). ¿Cuál prefieres para una org con rotación agresiva de credenciales y por qué?

### Q10 (C10 — 2 pts) — Canary sin traffic management

Un Rollout canary con `steps: setWeight: 10` sobre un `Service` + `Deployment` clásico (sin ingress-nginx canary, sin Istio, sin Gateway API) ¿realmente envía 10% del tráfico al nuevo pod? Explica.

### Q11 (C11 — 2 pts) — Hardening prioritario

De esta lista, elige las **3 acciones de mayor impacto** y ordénalas por prioridad justificando: (i) deshabilitar admin local, (ii) habilitar SSO/OIDC, (iii) aplicar Pod Security `restricted` al namespace `argocd`, (iv) backup con Velero del namespace, (v) rotar `argocd-secret`.

### Q12 (C13 — 2 pts) — `targetRevision`

Para cada caso, elige entre `main` (branch), `v1.4.2` (tag) o `3a9f...` (commit SHA) y justifica en una línea:
**(a)** Application que gestiona el ambiente `dev` que debe recoger cualquier commit mergeado.
**(b)** Application que gestiona el ambiente `prod` sujeto a auditoría.
**(c)** Rollback de emergencia tras un deploy fallido en `prod`.

---

## 3. Ejercicio operativo (40 puntos — ~55 min)

Ver [`operative/README.md`](./operative/README.md) para el enunciado completo, materiales de inicio y procedimiento de validación.

**Resumen:**

- Entorno: cluster `kind` local + Argo CD instalado por el candidato.
- Tareas:
  - **OP-1 (8 pts)** — Diagnosticar y arreglar una Application pre-sembrada que está `OutOfSync` + `Degraded`.
  - **OP-2 (8 pts)** — Añadir `ignoreDifferences` para convivir con un HPA que modifica `replicas`.
  - **OP-3 (8 pts)** — Introducir `sync-waves` + un PreSync hook (Job) que simule una migración de BD y bloquee el deploy de la app si falla.
  - **OP-4 (8 pts)** — Reemplazar un trío de Applications hermanas por un `ApplicationSet` con generator Git (una carpeta por entorno) y demostrar la generación de las tres apps.
  - **OP-5 (8 pts)** — Aplicar hardening mínimo: deshabilitar admin local, aplicar `PodSecurity: restricted` al namespace `argocd`, documentar la operación.

**SKIP policy:** si el candidato no puede instalar `kind` + `kubectl` + `argocd` CLI en su equipo (sin acceso a cloud, sin Docker), el ejercicio operativo se SALTA y los 40 puntos se redistribuyen proporcionalmente entre conceptual (×1.4) y arquitectónica (×1.6). El examen anota "operativo-skip" y la certificación resultante se emite con nota "sin validación hands-on" (válida 6 meses para re-tomar la parte práctica).

---

## 4. Ejercicio arquitectónico (25 puntos — ~35 min)

Ver [`architectural/scenario.md`](./architectural/scenario.md) para el escenario completo. Resumen: diseñar la plataforma GitOps para una empresa ficticia con 3 clusters, 2 equipos, 2 ambientes, secretos en AWS Secrets Manager y requisito de canary.

**Entregables:** diagrama de alto nivel + ADR (≤ 2 páginas) + fragmentos YAML representativos (`AppProject`, `ApplicationSet`, `AnalysisTemplate`).

---

## 5. Rúbrica

### 5.1 Rúbrica — Preguntas conceptuales

Cada pregunta se puntúa con la escala siguiente, escalada a su peso:

| Criterio             | Insuficiente (0)                                  | Básico (1)                                          | Competente (2)                                                  | Experto (3)                                                                        |
|----------------------|---------------------------------------------------|-----------------------------------------------------|------------------------------------------------------------------|------------------------------------------------------------------------------------|
| Corrección           | Respuesta falsa o no responde                     | Idea direccionalmente correcta pero con imprecisión | Correcta y completa                                              | Correcta, completa y anticipa un caso límite                                       |
| Razonamiento (why)    | Repite definición sin justificar                  | Justifica con una razón                             | Justifica con causa-efecto                                       | Justifica + contrasta alternativa descartada                                       |
| Ejemplo/concreción    | Abstracto o copiado                               | Ejemplo genérico                                    | Ejemplo específico y verificable                                 | Ejemplo del propio dominio del candidato con números/comandos                       |

**Nota final = media ponderada** (corrección 50%, razonamiento 35%, ejemplo 15%). **Aprobación conceptual: ≥ 60%** (21/35).

### 5.2 Rúbrica — Ejercicio operativo

| Criterio                | Insuficiente (0)                                      | Básico (1)                                                 | Competente (2)                                                                 | Experto (3)                                                                                      |
|-------------------------|-------------------------------------------------------|------------------------------------------------------------|-------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Correctness             | Validación automática falla en >50%                   | Falla en ≤50%                                              | Todas las validaciones pasan                                                   | Pasa + edge cases no exigidos (idempotencia, rerun)                                              |
| Diagnóstico (OP-1/2)    | No identifica causa raíz                              | Identifica síntoma pero aplica fix wide-net                | Identifica causa raíz y aplica fix mínimo                                      | Documenta cómo lo diagnosticó (logs, `argocd app diff`, events) con comandos exactos             |
| Seguridad               | Introduce red flag (ver §7)                           | Fix funcional pero deja permisos amplios                   | Least-privilege razonable                                                     | Least-privilege + justifica en comentario YAML                                                   |
| Mantenibilidad          | YAML no comentado, nombres crípticos                  | Legible                                                    | Comentado donde no es obvio + convenciones consistentes                        | Reutilizable (ApplicationSet, overlays) con separación clara de concerns                         |
| Operabilidad            | No se puede volver a ejecutar                         | Reproducible con intervención manual                       | Totalmente reproducible desde `make verify` o script equivalente              | Incluye rollback documentado                                                                     |

**Aprobación operativa: ≥ 60%** (24/40). Peso: correctness 40%, diagnóstico 25%, seguridad 15%, mantenibilidad 10%, operabilidad 10%.

### 5.3 Rúbrica — Ejercicio arquitectónico

| Criterio               | Insuficiente (0)                                   | Básico (1)                                             | Competente (2)                                                              | Experto (3)                                                                                     |
|------------------------|----------------------------------------------------|--------------------------------------------------------|------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| Satisfacción de req.    | Diseño no cubre requisitos                        | Cubre funcional pero ignora alguna restricción         | Cubre todos los requisitos y restricciones                                   | Además propone KPIs/SLOs para medir el diseño en operación                                      |
| Trade-offs explícitos   | Presenta una sola opción                          | Menciona alternativas sin comparar                     | Compara ≥ 2 alternativas con criterios                                       | Compara + enumera lo que se renuncia al elegir (coste operativo, bloqueo tech)                  |
| ADR well-formed         | Falta contexto o decisión                         | Formato correcto pero genérico                         | Contexto, decisión, consecuencias (positivas y negativas), status             | Añade sección "what would make us revisit" (triggers de reevaluación)                           |
| Realismo operativo      | Diseño "pizarra" no implementable                 | Implementable con esfuerzo no cuantificado             | Incluye estimación de esfuerzo y responsables                                 | Incluye plan de migración desde un estado anterior conocido                                     |
| Seguridad y blast radius | Introduce red flag                                | Menciona seguridad al final                            | Secretos, RBAC y multi-tenancy diseñados desde el principio                  | Modela escenario de credencial filtrada y describe contención                                   |

**Aprobación arquitectónica: ≥ 60%** (15/25). Peso: req. 25%, trade-offs 25%, ADR 20%, realismo 15%, seguridad 15%.

### 5.4 Agregado

- **Nota global** = (conceptual_puntos + operativo_puntos + arquitectónico_puntos) / 100.
- **Umbral:** ≥ 70 **y** cada dimensión ≥ 50%.
- Un **red flag demostrable** (ver §7) resta 10 puntos del total y descarta "Experto" en el criterio afectado.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo — conceptual

**Q1.**
(a) Viola *pulled automatically* y *continuously reconciled*: el pipeline **empuja** desde fuera (push, no pull), y no hay reconciliación continua — si alguien hace `kubectl edit` en prod, nadie lo revierte hasta el próximo merge. También suele violar *versioned & immutable* si el pipeline aplica `kubectl apply` sobre `latest` o resuelve variables en tiempo de build que no quedan en Git.
(b) Alguien edita manualmente un `Deployment` para "arreglar" un incidente; nada lo revierte, el drift queda indefinidamente, el próximo deploy del pipeline sobrescribe el fix sin aviso. Argo CD con `selfHeal` revertiría en segundos y, aun sin `selfHeal`, mostraría `OutOfSync`.
*Parcial:* mencionar solo "no es pull" sin explicar la consecuencia del drift. *Red flag en respuesta:* decir que es GitOps "porque está en Git".

**Q2.**
(a) `Sync` compara manifests en Git vs recursos en cluster (desired vs applied). `Health` evalúa el estado real de los recursos (p. ej., Deployment con replicas disponibles). `Synced + Degraded` es típico: el cluster tiene lo que Git declara, pero la app falla en runtime (crashloop, pull image error, probe fail).
(b) `selfHeal` no interviene aquí — selfHeal reacciona a *diferencias* entre Git y cluster, no a health. El `Degraded` persiste hasta corregir la causa real (fix de imagen, config, dependencia).
*Parcial:* confundir Sync y Health. *Experto:* mencionar que un `Degraded` por `ImagePullBackOff` con `targetRevision=HEAD` puede provocar deploy inválido difícil de identificar.

**Q3.**
(a) HPA escala a 7. Argo CD detecta `replicas: 7` ≠ `replicas: 3` → `OutOfSync`. Si `selfHeal=true`, sincroniza a 3. HPA inmediatamente vuelve a 7. Loop: Argo CD baja a 3, HPA sube a 7, cada ~minuto. El cluster oscila, HPA emite eventos de scale sin fin, Argo CD "parece" nunca estar `Synced`.
(b)
```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```
*Parcial:* usar `managedFieldsManagers` sin entender SSA (correcto pero necesita contexto). *Red flag:* desactivar `selfHeal` globalmente como "fix".

**Q4.**
(a) Argo CD **no ejecuta `helm install`**; el `repo-server` corre `helm template` y aplica los manifests resultantes vía el `application-controller`. Los hooks de Helm (`pre-install`, `post-upgrade`, etc.) son metadata que **el cliente Helm** interpreta — Argo CD los ignora (o los filtra). El `Secret` no se crea antes del release.
(b) Convertir el hook a Argo CD resource hook con anotación `argocd.argoproj.io/hook: PreSync` (y opcional `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation`), combinado con `sync-wave` si hay orden.
*Red flag:* responder "Helm hooks funcionan igual" o proponer `helm install` fuera de Argo CD como workaround.

**Q5.** En `prod` durante un incidente el SRE puede necesitar aplicar un parche con `kubectl` (p. ej., bajar replicas de un pod ruidoso, cambiar un flag). `selfHeal` revertiría ese parche en segundos, prolongando el incidente. En `dev` el drift es ruido, no acción crítica, y `selfHeal` protege la fidelidad Git↔cluster.
*Parcial:* "es peligroso en prod" sin ejemplo concreto.

**Q6.** Hay que mirar **dos** capas: (1) **Argo CD RBAC** (`argocd-rbac-cm`) para confirmar que el rol `dev` tiene `sync` sobre la Application correcta. (2) **K8s RBAC** del ServiceAccount que usa el `application-controller` en el cluster target: si ese SA no puede crear/aplicar los recursos (Deployment, Service, etc.), el sync falla desde el cluster, no desde Argo CD. En logs se verá `forbidden: User "system:serviceaccount:argocd:argocd-application-controller" cannot create ...`.

**Q7.** app-of-apps mejor cuando: pocas Applications heterogéneas con estructuras muy distintas, cuando el equipo quiere control explícito por app y añadir una nueva es un evento. ApplicationSet mejor cuando: muchas Applications con el mismo shape que cambian por 1-2 parámetros (una por cluster, una por entorno, una por PR). *Red flag:* responder solo con un criterio ("ApplicationSet es declarativo") que también aplica a app-of-apps.

**Q8.** Ejemplos aceptables: cambiar la imagen del `application-controller` a una versión incompatible; romper el `AppProject` que contiene la propia Application; cambiar RBAC quitándose permisos. Mitigaciones: `syncPolicy` manual en la Application que gestiona Argo CD (sin `selfHeal`), review obligatorio en el repo, pipeline de pre-flight que haga `argocd app diff` en CI, mantener un `kubeconfig` + manifests fallback fuera de Argo CD para re-aplicar manualmente.

**Q9.** Blast radius ESO: si se filtra el IAM role del controller, el atacante puede leer los secretos a los que ese role tiene acceso (acotado por IAM policy) **pero no los secretos en otros clusters/orgs**. Blast radius SOPS: si se filtra la clave KMS que descifra, el atacante puede descifrar **todos los secretos cifrados con esa clave en Git**, histórico incluido (los commits viejos siguen cifrados con la clave vieja). Para rotación agresiva, ESO suele ser mejor: rotar un IAM role es trivial; rotar la clave SOPS requiere re-cifrar y commitear todo el historial relevante.

**Q10.** No. Sin traffic management explícito, Argo Rollouts divide por **replicas** — si hay 10 pods, un `setWeight: 10` arranca 1 pod nuevo y mantiene 9 viejos. El `Service` reparte round-robin aproximadamente 10% de las conexiones (no requests), lo cual varía con `keep-alive`, afinidad de sesión y balanceo del kube-proxy. Para control real por porcentaje de requests hace falta ingress-nginx canary annotations, Istio VirtualService, Gateway API HTTPRoute weight, SMI TrafficSplit, etc.

**Q11.** Orden recomendado:
1. **Habilitar SSO/OIDC** — raíz del árbol de identidad; sin esto, el resto es cosmético.
2. **Deshabilitar admin local** — una vez SSO probado; cierra el bypass más usado por atacantes.
3. **Pod Security `restricted` al namespace** — reduce blast radius si un pod de Argo CD es comprometido.
Backup con Velero y rotación de secretos son higiene continua, no la mitigación de mayor impacto único. *Red flag:* poner "rotar `argocd-secret`" primero sin SSO.

**Q12.**
(a) `main` — se quiere seguir el flujo continuo del equipo de dev.
(b) `v1.4.2` (tag inmutable) — auditable, referenciable en runbook, no cambia bajo los pies.
(c) commit SHA del release anterior conocido-bueno — tag puede haberse sobrescrito, SHA es inmutable y preciso. *Parcial:* usar `main` en (b) o "último tag" en (c).

### 6.2 Guía — ejercicio operativo

- Solución de referencia detallada en [`operative/SOLUTION.md`](./operative/SOLUTION.md) (archivo instructor-only, no entregar al candidato).
- **Validación automatizada:** [`operative/validate.sh`](./operative/validate.sh) corre las 5 tareas y produce un reporte por tarea (pass/fail + puntos).
- **Errores comunes esperados:**
  - OP-1: aplicar `kubectl apply` en vez de arreglar el manifest en Git ("GitOps-washing" en el propio examen → red flag).
  - OP-2: usar `managedFieldsManagers` sin SSA en el cluster → funcional pero frágil.
  - OP-3: olvidar `hook-delete-policy` → acumulación de Jobs tras cada sync.
  - OP-4: copiar las 3 apps en el ApplicationSet template en vez de parametrizar → no cumple el espíritu.
  - OP-5: aplicar `restricted` sin probar que los pods de Argo CD arrancan → cluster muere.
- **Señales de "respondió sin entender":** nombres de recursos sin adaptar al proyecto, `kubectl patch` fuera del repo de Git para "arreglar" OP-1, `--insecure-skip-tls-verify` en comandos de `argocd login`.

### 6.3 Guía — ejercicio arquitectónico

- Solución de referencia en [`architectural/SOLUTION.md`](./architectural/SOLUTION.md) (instructor-only).
- **Errores comunes:**
  - Un solo `AppProject` para todos los equipos.
  - ESO sin discutir rotación ni IAM policy acotada.
  - Canary con analysis que solo mira `pod ready`.
  - Bootstrap que no explica cómo se instala Argo CD la primera vez.
- **Señales de memorización:** copiar la arquitectura del capstone del curso tal cual sin adaptar al escenario; usar los mismos nombres de namespaces/apps que los ejemplos del Deep Dive.

---

## 7. Red flags (invalidación automática del criterio asociado)

Red flags **demostrables** (si el corrector puede señalarlos en el artefacto entregado):

1. **Secreto en claro commitado** (token, password, kubeconfig, cert privada) en el repo del ejercicio operativo o en los fragmentos del arquitectónico.
2. **AppProject con `sourceRepos: '*'` + `destinations: '*/*'` + `clusterResourceWhitelist: ['*']`** sin justificación por escrito.
3. **Admin local habilitado** en el diseño productivo del ejercicio arquitectónico sin plan de desactivación.
4. **`selfHeal=true` global** aplicado a `prod` sin ventanas de mantenimiento ni plan de override para incidentes.
5. **`targetRevision: HEAD`** o rama mutable en Applications marcadas como productivas.
6. **Argo CD con `cluster-admin`** en todos los clusters target sin razón técnica documentada.
7. **Pipeline que hace `kubectl apply`** descrito como "GitOps" en el ADR.
8. **Hooks de Helm sin convertir** dentro de un chart gestionado por Argo CD (indica que no se entendió §Q4).
9. **Credenciales de repo hardcodeadas** en `argocd-cm` o en manifests commitados.
10. **`curl | bash` desde fuente no verificada** en initContainers, PreSync Jobs o scripts de bootstrap.
11. **ApplicationSet con PR generator sin delete-on-close** o sin `preserveResourcesOnDeletion: false`.
12. **AnalysisTemplate que solo valida `pod ready`** y no una SLI (success rate, latencia, error budget).
13. **`cosign verify --insecure-ignore-tlog`** u otros flags que desactivan verificación en pipeline productivo.
14. **`--insecure-skip-tls-verify`** o equivalentes en `argocd login` o en manifests productivos.

Cada red flag demostrable: **−10 puntos** del total y descarta "Experto" en el criterio afectado. **Dos o más red flags: no aprueba, independientemente del score numérico.**

---

## 8. Preguntas de seguimiento (defensa oral — opcional, 15 min)

Para distinguir memorización de comprensión en evaluación live, el instructor elige **3** de estas preguntas, al menos una por dimensión:

**Conceptuales:**
- F1. "Diste `v1.4.2` como respuesta en Q12 (b). ¿Qué pasa si un atacante con acceso al registro mueve el tag `v1.4.2` a otra imagen? ¿Argo CD lo detectaría?"
- F2. "En Q4 propusiste `argocd.argoproj.io/hook: PreSync`. ¿Qué pasa si ese Job falla? ¿Y si tarda 30 minutos?"
- F3. "En Q11 priorizaste SSO. Pero el equipo todavía no tiene IdP. ¿Qué haces mientras tanto?"

**Operativas:**
- F4. "Walkthrough: muéstrame cómo diagnosticaste OP-1 sin leer la solución. ¿Qué fue lo primero que miraste y por qué?"
- F5. "Tu `ignoreDifferences` en OP-2 funciona para HPA. ¿Qué pasa si mañana añaden un VPA que modifica `resources.requests`? Modifícalo en vivo."
- F6. "Tu PreSync Job en OP-3 asume que la BD está disponible. ¿Qué pasa si no lo está? ¿El Rollout se gatea? ¿Cómo lo notarías?"

**Arquitectónicas:**
- F7. "Elegiste ESO para secretos. Mañana la empresa compra una subsidiaria con GCP (hoy sois AWS-only). ¿Cambias de estrategia? ¿Por qué?"
- F8. "Tu canary tiene criterio de 'success rate > 99%'. ¿Qué pasa si el servicio tiene baja QPS (10 rpm) durante la ventana de analysis? Diseña la mitigación."
- F9. "Un ingeniero senior te dice: 'ApplicationSet es overengineering, hagamos app-of-apps'. Convénceme en 2 minutos usando este diseño concreto, no genéricos."

**Criterio:** respuesta débil si el candidato (a) repite lo que escribió sin añadir, (b) se bloquea ante el "¿y si cambia X?", (c) propone soluciones que violan algo que él mismo escribió antes.

---

## 9. Entrega

El candidato entrega un **tarball** o repo con:

```
submission/
  conceptual/
    answers.md          # Respuestas Q1..Q12 en español
  operative/
    repo/               # Repo de infra GitOps completo (manifests, ApplicationSet, hardening)
    diagnosis.md        # Narrativa breve de cómo diagnosticó OP-1 y OP-2
    validate-output.txt # Output del script validate.sh
  architectural/
    adr.md              # ADR final
    diagram.{png,svg,drawio}
    manifests/          # Fragmentos YAML representativos
  llm-usage.md          # Declaración de uso de LLM (si aplica)
```

Validación automática del operativo:

```bash
cd evaluation/course-exams/07-argocd/operative
./validate.sh --submission /path/to/submission/operative/repo
```
