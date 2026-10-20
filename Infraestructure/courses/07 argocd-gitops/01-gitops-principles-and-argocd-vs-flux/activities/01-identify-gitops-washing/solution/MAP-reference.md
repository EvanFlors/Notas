# MAP (reference) — argo-01-01: Auditoría de 5 escenarios

> Autoevaluación. **No** es una respuesta única — es *una* respuesta profesional y defendible. Si tu MAP llega a conclusiones equivalentes con otra articulación, también es válido.

## Sección 1 — Principios OpenGitOps

1. **Declarative** — el estado deseado se expresa como **datos** (YAML, HCL, Jsonnet), no como una secuencia de comandos. Puedes **leer** el estado deseado sin ejecutar nada.
2. **Versioned and Immutable** — el estado deseado vive en un sistema con **historia completa** e **inmutabilidad** una vez publicado (Git con branch protection cumple; S3 sin versionado no).
3. **Pulled Automatically** — un **agente dentro del sistema** halla desde la fuente y aplica. El actor externo nunca aplica directo; solo escribe en la fuente.
4. **Continuously Reconciled** — el agente **observa el estado real continuamente** y actúa (o alerta) ante desviaciones. No "aplica al commit y olvida".

Los 4 son **conjunción**: falla uno → no es GitOps.

---

## Sección 2 — Auditoría por escenario

### Escenario A — Acme Classic

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | SI | manifests YAML en `manifests/` |
| 2 Versioned & Immutable | SI | Git con branch protection + reviewer |
| 3 Pulled Automatically | **NO** | GHA hace `kubectl apply` directo al cluster (push clásico) |
| 4 Continuously Reconciled | **NO** | no hay agente observando; drift silencioso entre deploys |

**Veredicto**: **no es GitOps** (push CI/CD tradicional).

**Principio(s) violado(s)**: 3 y 4.

**Consecuencia operativa**: credenciales de admin del cluster viven en secretos del repo (blast radius enorme si se compromete el runner); drift manual queda hasta el próximo apply y luego desaparece sin aviso; rollback = re-ejecutar pipeline con SHA viejo.

**Corrección mínima**: instalar Argo CD (o Flux) en el cluster; mover los manifests a un **repo de infra** separado; cambiar el pipeline para que su último paso sea un **commit al repo de infra** bumping el image tag en vez de `kubectl apply`; crear una `Application` que apunte al repo de infra con `syncPolicy.automated` + reconciliation loop activo.

---

### Escenario B — Acme Argo

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | SI | manifests YAML en Git |
| 2 Versioned & Immutable | SI | Git con branch protection |
| 3 Pulled Automatically | **NO** | GHA sigue haciendo `kubectl apply`; Argo CD solo observa |
| 4 Continuously Reconciled | **NO** | Argo CD muestra "Synced" porque el estado se dejó así; sin `syncPolicy` no actúa; drift no se revierte |

**Veredicto**: **GitOps-washing clásico**. Argo CD está instalado pero es un **visor cosmético**; el pipeline sigue siendo push.

**Principio(s) violado(s)**: 3 (principal) y 4.

**Consecuencia operativa**: toda la complejidad extra de operar Argo CD **sin cobrar ninguno de los beneficios reales**. Credenciales siguen en el runner. Drift sigue silencioso (si alguien edita, Argo CD lo verá como "Synced" porque el estado observado es el estado deseado — pero el "estado deseado" fue puesto por el pipeline, no por Git). Peor que Acme Classic en costo/beneficio.

**Corrección mínima**: **cortar el pipeline del cluster**. Revocar las credenciales de admin del runner. Configurar `syncPolicy.automated: {selfHeal: true, prune: true}` en las Applications. El pipeline debe terminar en commit al repo de infra, no en `kubectl apply`.

---

### Escenario C — Acme Pull But Not Continuous

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | SI | manifests YAML en Git |
| 2 Versioned & Immutable | SI | Git con branch protection |
| 3 Pulled Automatically | SI | el agente (Argo CD) hace el apply en respuesta al webhook |
| 4 Continuously Reconciled | **NO** | sin polling periódico y sin loop activo, el agente solo actúa en el webhook; drift manual queda hasta el próximo commit |

**Veredicto**: **parcial / GitOps-washing sutil**. Es la variante "aplicar al commit y nada más" — cumple 3 pero rompe 4.

**Principio(s) violado(s)**: 4.

**Consecuencia operativa**: **drift silencioso igual que en push**. Alguien hace `kubectl edit deploy/web` cambiando replicas de 3 a 10 → nadie lo revierte ni lo detecta hasta que haya un cambio en Git. Si el webhook de GitHub se pierde (bug, red, misconfig), el deploy **ni siquiera se aplica**. Pierdes el beneficio principal de GitOps.

**Corrección mínima**: **activar el reconciliation loop** del agente con un `interval` razonable (3–5 min). En Argo CD, cambiar `timeout.reconciliation` a `180s` (default) y asegurar que `syncPolicy.automated` tenga `selfHeal: true`. Los webhooks son **optimización**; el loop es **obligatorio**.

---

### Escenario D — Acme Scripted

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | **NO** | el "estado deseado" en Git son scripts bash imperativos (`kubectl create`, `kubectl set`, `kubectl patch`), no manifests |
| 2 Versioned & Immutable | SI | Git con history |
| 3 Pulled Automatically | SI | Argo CD corre dentro del cluster y hace polling |
| 4 Continuously Reconciled | **NO** (parcial) | aunque el agente itere, no puede hacer **diff** real — los scripts no describen un estado observable, así que la "reconciliación" se vuelve "re-ejecutar scripts" (idempotencia frágil); drift tampoco se detecta porque no hay manifest contra el que comparar |

**Veredicto**: **no es GitOps** aunque haya agente y pulling.

**Principio(s) violado(s)**: 1 (principal) y, por consecuencia, 4.

**Consecuencia operativa**: no se puede hacer `diff` (no hay representación declarativa del estado). `git revert` del script no revierte el estado del cluster, solo elimina el script. Los scripts pueden fallar en re-ejecución ("el Deployment ya existe"). Argo CD no puede mostrar "OutOfSync" porque no sabe qué debería existir realmente — solo sabe que un script debería correr. "GitOps" en el papel, scripts imperativos en la práctica.

**Corrección mínima**: **convertir los scripts a manifests declarativos** (YAML, Helm chart o Kustomize overlay). Si hay lógica condicional ("si env=prod entonces 3 replicas"), expresarla con Helm `if/else` en values por entorno, no con `if` en bash. Eliminar el config management plugin que ejecuta scripts.

---

### Escenario E — Acme S3 Pivot

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | SI | manifests YAML (aunque generados) |
| 2 Versioned & Immutable | **NO** | S3 sin versionado — sobreescribir destruye la versión anterior; sin history |
| 3 Pulled Automatically | SI | Argo CD hace polling del bucket |
| 4 Continuously Reconciled | SI | `selfHeal: true` + polling cada 3 min |

**Veredicto**: **no es GitOps** por violar explícitamente el principio 2.

**Principio(s) violado(s)**: 2.

**Consecuencia operativa**: (a) **rollback imposible** sin recordar la generación anterior y re-generarla a mano; (b) **auditoría destruida** — si un auditor SOC2 pregunta "¿qué estaba en prod el martes?", no hay respuesta; (c) **debugging degradado** — "¿qué cambió entre dos deploys?" no tiene diff posible; (d) si el pipeline nocturno falla a mitad, el bucket puede quedar en estado **inconsistente** sin aviso. "Ahorro de costos" minúsculo (versionado S3 cuesta centavos) a cambio de perder la propiedad clave de GitOps.

**Corrección mínima**: **activar versionado y object lock en el bucket**, o — mejor — **mover los manifests generados a un repo Git**. El bucket S3 puede quedarse como caché/mirror; la fuente de verdad debe tener history inmutable.

---

## Sección 3 — Preguntas obligatorias

1. **El principio 3 (pulled)** es el más común de violar. Patrón de washing típico: la organización instala Argo CD/Flux pero **no corta el pipeline del cluster** — los runners siguen teniendo `kubeconfig` con admin y aplicando directo. El agente queda como "visor bonito". Es Acme Argo (escenario B). Lo segundo más común es violar 4 (continuous reconciliation) por "aplicar al commit sin loop" — Acme Pull But Not Continuous (escenario C).

2. **No, no es GitOps**. Argo CD muestra "Synced" porque la realidad del cluster coincide con el estado deseado en Git — pero esa coincidencia la produjo el pipeline (que aplicó Git al cluster), no el agente. Viola el principio 3 (pulled): quien aplica debe ser el agente, no un actor externo. "Synced" es una **métrica de resultado**, no una **métrica de proceso**; GitOps se juzga por el proceso. Si el pipeline aplicara algo distinto a lo que hay en Git, Argo CD lo mostraría "OutOfSync" — pero mientras no haya desviación, parece correcto. Es engañoso.

3. "Aplicar al commit sin reconciliar" **anula el beneficio principal**: la detección y auto-reversión de **drift**. El beneficio #1 de GitOps es "el cluster persigue a Git siempre"; sin loop, el cluster persigue a Git **solo cuando Git cambia**. Entre commits, cualquier `kubectl edit` manual queda. Resultado: la misma superficie de drift silencioso que push, con la complejidad adicional de haber instalado el agente. Peor relación costo/beneficio.

4. En el escenario D se rompe el principio 1 (declarative). Un script bash **no es declarativo** aunque viva en Git porque: (a) **no describe un estado**, describe una **secuencia de acciones** — para saber qué va a hacer tienes que ejecutarlo o leerlo línea por línea; (b) **no es trivialmente idempotente** — `kubectl create` falla si el objeto existe; `kubectl set` falla si el objeto no existe; (c) **no permite diff** — Argo CD no puede comparar "lo que el script produciría" con "lo que hay"; (d) `git revert` del script no revierte el estado del cluster. Un YAML cumple todas: lo lees y sabes el estado; lo aplicas dos veces y pasa lo mismo; se puede diff; `git revert` del YAML, aplicar, y el estado vuelve.

5. En el escenario E se viola el principio 2 (versioned & immutable). Riesgos operativos concretos: (a) **rollback imposible sin history** — si una generación nocturna rompe prod, no hay "la de ayer" a la que volver, hay que **re-generar** y rezar; (b) **auditoría destruida** — compliance (SOC2, HIPAA) exige mostrar qué estaba en prod en una fecha; sin versionado no hay respuesta; (c) **debugging degradado** — no hay diff posible entre dos estados; (d) si una generación falla a mitad y sobreescribe parcialmente, el bucket queda en estado inconsistente sin history para auditar qué pasó; (e) riesgo de **supply chain** — si alguien compromete la cuenta de AWS y modifica el bucket, el cambio es indetectable sin logs externos.

6. Con **GitOps bien hecho**, el auditor pregunta y tú abres el repo de infra, haces `git log --since='last tuesday' --until='last wednesday' -- envs/prod/` y le muestras los commits (quién, cuándo, qué cambió, qué PR fue, quién aprobó). Trivial. Con **GitOps-washing** (p. ej. escenario B, con pipeline push), tienes que correlacionar: logs del pipeline + logs de `kubectl apply` en el cluster + commits del repo de código — todo por separado, sin garantía de que coincidan (si alguien hizo `kubectl edit` a mano, no aparecerá en ningún log del pipeline). Es la diferencia entre "una pregunta, una respuesta" y "una pregunta, media semana reconstruyendo".

7. **Técnicamente no viola los 4 principios**: secretos en claro en Git privado siguen siendo declarativos, versionados, pulled y reconciliados. **Pero no es aceptable** por tres razones ortogonales a OpenGitOps: (a) **superficie de fuga** — un repo privado se vuelve público por error humano (misconfig del rulesets, mirror a GitHub público, screenshot en una presentación); (b) **auditoría débil** — un desarrollador con read access al repo puede extraer *todos* los secretos sin dejar rastro, no hay rotación trivial; (c) **imposibilidad de rotación** — rotar un secreto exige nuevo commit, nuevo PR, tiempo entre commit y aplicación; con un secret manager externo (ESO, Vault) la rotación es inmediata y auditada. GitOps **exige disciplina de secretos** aunque no la codifique como principio: SOPS, Sealed Secrets o ESO (preferido). Se cubre en `argo-09`.
