# Examen de certificación — Curso Azure

- **Curso:** `azure`
- **Nivel:** intermedio–avanzado
- **Dimensiones:** todas (conceptual + operativa + arquitectónica)
- **Duración total:** 90–120 min
- **Umbral de aprobación:** 70 % ponderado (y mínimo 50 % en cada dimensión por separado — no se puede aprobar colapsando en una sola)
- **Entorno:** take-home o live con instructor. **Sin suscripción Azure real.** Validación offline con Terraform + emuladores locales (ver más abajo).
- **Materiales:**
  - `competency-matrix.yaml` — matriz oficial con pesos.
  - `operative/` — stack Terraform a corregir (Landing Zone + Policy baseline).
  - `architectural/scenario.md` — escenario para la pregunta arquitectónica.

> **Lectura obligatoria antes de empezar:** la sección _Red flags_ al final. Cualquier entrega que incurra en una red flag se considera inválida en el ejercicio correspondiente, independientemente del resto del trabajo.

---

## Reglas de la casa

1. **Prosa en español, código y comandos en inglés.** Nombres de recursos y variables en inglés.
2. **Placeholders obligatorios:**
   - Tenant ID: `00000000-0000-0000-0000-000000000001`
   - Subscriptions: `...000000000010` (platform), `...000000000020` (landing-zone-prod), `...000000000030` (landing-zone-dev), `...000000000040` (sandbox).
   - Object IDs / Client IDs: `...000000000100`, `...000000000101`, etc.
3. **Prohibido** cualquier `az login` interactivo contra tenant real, cualquier `terraform apply`, cualquier recurso que genere costo en Azure.
4. **Emuladores locales** (opcionales):
   - **Azurite** (`npm i -g azurite` o `docker run mcr.microsoft.com/azure-storage/azurite`) para Blob/Queue/Table.
   - **Cosmos DB Linux Emulator** (`docker run mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator`).
   - Si el entorno de evaluación no los tiene, el candidato debe **declarar explícitamente `SKIP: emulator no disponible`** en el entregable del ejercicio operativo. No se penaliza por no tenerlos — se penaliza por fingir que corrió lo que no corrió.

---

## Reparto de puntaje

| Dimensión | % | Items |
|-----------|---|-------|
| Conceptual | 35 % | Q1–Q14 (14 preguntas, pesos variables) |
| Operativa | 35 % | OP-task-1, OP-task-2, OP-task-3 |
| Arquitectónica | 30 % | ARCH (escenario único) |

Tiempo sugerido: 30 min conceptual, 40–50 min operativa, 25–30 min arquitectónica.

---

## Sección 1 — Preguntas conceptuales (35 %)

> Respuesta corta (3–8 líneas). No se busca el manual: se busca el _por qué_. Respuestas que repiten la definición del módulo sin usarla valen 0.

### Q1 — RG como blast radius (C1, 2 pts)

**¿Por qué la recomendación es "un Resource Group por ambiente de un workload" y qué riesgo introduce esa misma recomendación cuando el equipo adopta `az group delete` como mecanismo rutinario de limpieza?** Explica el trade-off entre operabilidad y riesgo de borrado accidental, y cómo la jerarquía MG → Subscription → RG permite acotarlo.

### Q2 — RBAC allow-based (C2, 3 pts)

Un ingeniero argumenta: _"basta con quitar el role `Contributor` del grupo `developers` a nivel subscription para que no puedan crear VMs."_ **¿En qué condiciones esta frase es falsa?** Describe al menos dos vías por las que un principal podría seguir creando una VM, y explica por qué Azure RBAC es _allow-based con herencia por scope_ (no existe un `deny` como en SCP de AWS).

### Q3 — Quién bloquea cuando RBAC no bloquea (C2, 2 pts)

Siguiendo la Q2: **¿cuál es el mecanismo correcto en Azure para _prevenir_ (no auditar) la creación de VMs en una región prohibida en toda la organización?** Da el nombre exacto del effect y a qué scope lo asignarías.

### Q4 — MI vs SP con secreto (C3, 3 pts)

**¿Qué garantiza una system-assigned Managed Identity que un Service Principal con client secret _no_ garantiza, y qué pierdes a cambio?** Da un caso donde preferirías explícitamente una **user-assigned MI** sobre una system-assigned.

### Q5 — Private Endpoint vs Service Endpoint (C4, 3 pts)

**¿Por qué un Private Endpoint elimina el egress por internet a un Storage Account y un Service Endpoint no?** Explica qué le aparece a tu VNet con cada uno (IP privada vs ruta optimizada) y qué sigue siendo público en el caso del Service Endpoint.

### Q6 — NSG en subnet y NIC (C5, 2 pts)

Tienes un NSG aplicado a la subnet `web` que permite `tcp/443` desde `0.0.0.0/0`, y otro NSG aplicado a la NIC de una VM dentro de esa subnet que **deniega** `tcp/443` desde `0.0.0.0/0`. **¿Qué tráfico pasa y por qué?** Explica el modelo de "effective security rules" para una NIC.

### Q7 — Container Apps vs AKS vs Functions (C6, 3 pts)

Un equipo tiene tres workloads: (a) una API HTTP pública con picos impredecibles y silencios de horas, (b) un procesador que consume de una Service Bus Queue con backlog variable, (c) un workload que necesita un sidecar `envoy` custom con configuración de xDS no soportada por el runtime managed. **Elige el compute correcto para cada uno y justifica.** Pistas de criterio aceptable: scale-to-zero, control sobre el runtime, costo por request vs costo por hora.

### Q8 — Cosmos DB consistency (C7, 3 pts)

Diseñas una API de "carrito de compras" multi-región (lectura desde la región más cercana al usuario, escritura en una región primaria). **¿Qué consistency level de Cosmos DB eliges y por qué `strong` sería un error?** Da un caso donde `session` sería suficiente y uno donde subirías a `bounded staleness`.

### Q9 — Workload Identity vs Pod Identity v1 (C8, 3 pts)

**¿Por qué AKS Workload Identity sucede a Pod Identity v1 y qué parte del flujo (desde el pod hasta la obtención del token de Entra ID) es el que ambos resuelven?** Mapea los componentes (ServiceAccount, federated credential, Entra ID app registration) a los equivalentes de IRSA en EKS.

### Q10 — Costo Log Analytics (C9, 2 pts)

Un workspace Log Analytics factura $4,000/mes y el 70 % de la ingestion viene de `AzureDiagnostics` de un AKS que loguea `stdout` sin filtrar. **Describe tres palancas** (una por categoría: ingestion, retention, consulta) para bajar el costo sin perder la señal de seguridad crítica (fallos de auth, cambios de RBAC).

### Q11 — `deployIfNotExists` (C11, 2 pts)

Asignas una policy con effect `deployIfNotExists` que debería crear un Diagnostic Setting en cada Storage Account nuevo. La asignación se completa sin error pero las remediations no se ejecutan. **¿Qué pieza suele faltar y por qué `audit` no habría tenido el mismo problema?**

### Q12 — OIDC Federation subject (C12, 3 pts)

**¿Cuál es el riesgo concreto de dejar el `subject` del federated credential como `repo:owner/repo:*` en vez de `repo:owner/repo:environment:prod`?** Describe cómo un contributor con permiso de abrir un PR podría obtener un token con permisos de producción, y qué formato de `subject` prefieres cuando la "unidad de confianza" es un GitHub Environment protegido.

### Q13 — Key Vault RBAC vs access policies (C14, 2 pts)

**¿Por qué el modo RBAC data-plane es preferible a access policies legacy para un Key Vault nuevo?** Menciona al menos dos propiedades operacionales (auditabilidad, modelo mental, delegación) y qué garantizan `soft delete` + `purge protection` que un `rm -rf` del Key Vault no destruye.

### Q14 — Cosign no es un escáner (C15, 2 pts)

Verificas la firma `cosign verify ...` de una imagen contra tu identidad de GitHub Actions y pasa. **¿Qué garantiza esa verificación y qué _no_ garantiza?** Explica por qué firmar _no_ sustituye a Defender for Containers / Trivy, y por qué la cadena correcta en un admission controller es firma + escaneo + policy, no uno solo de los tres.

---

## Sección 2 — Ejercicio operativo (35 %)

Ver `operative/README.md`. Resumen de tareas (todas en el stack Terraform de `operative/`, sin cloud):

- **OP-task-1 (C10, 15 pts)** — Corregir el stack para que `terraform fmt && terraform init -backend=false && terraform validate` pase sin errores. Esto incluye arreglar la jerarquía de Management Groups, los scopes de las asignaciones de Azure Policy y el `required_providers`.
- **OP-task-2 (C3, 10 pts)** — Rediseñar el bloque de identidad: eliminar el Service Principal con secret, sustituirlo por una user-assigned MI referenciada por nombre (sin crear el secret resource) y asignarle el role mínimo (`Key Vault Secrets User`) sobre un Key Vault scoped a RG.
- **OP-task-3 (C8, C12, 10 pts)** — Dejar documentado y configurado (sólo IaC + manifest de ejemplo, no apply) el federated credential de GitHub Actions con `subject` pinneado a environment, y el `azurerm_federated_identity_credential` que casa un `ServiceAccount` de AKS con una user-assigned MI (patrón Workload Identity).

**Validación automática** (lo que corre el instructor, ver `operative/README.md` para la lista exacta).

---

## Sección 3 — Ejercicio arquitectónico (30 %)

Ver `architectural/scenario.md`.

Entregable: un documento en Markdown (`decisiones.md` dentro de `architectural/`) con:

1. Diagrama de alto nivel (ASCII o mermaid) de la topología Hub-Spoke, suscripciones y Management Groups.
2. Tabla de decisiones (compute, data, identidad, red, observabilidad, DevSecOps) con **trade-offs explícitos** — no "elegimos Container Apps porque es moderno".
3. Un **ADR** siguiendo el formato (contexto, decisión, consecuencias) para una decisión concretamente contenciosa que detectes.
4. Mapeo explícito AWS → Azure para cada capa (p. ej. IRSA → AKS Workload Identity, SCP → Azure Policy deny, Secrets Manager → Key Vault).

---

## Sección 4 — Rúbrica

### 4.1 Preguntas conceptuales

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Explica _por qué_ (no solo _qué_) | Repite la definición del módulo o responde con la lista de features. | Nombra el mecanismo correcto pero no articula la causa. | Explica causa y trade-off con un ejemplo concreto. | Explica causa, trade-off, caso límite donde la regla falla y cómo detectarlo. |
| Precisión técnica | Confunde conceptos próximos (p. ej. Service Endpoint con Private Endpoint). | Nombres correctos, mecánica aproximada. | Nombres y mecánica correctas. | Correcto y usa el vocabulario oficial de Azure sin ambigüedad (p. ej. "federated credential" vs "trust policy"). |
| Caso límite / contraejemplo | Ausente. | Mencionado vagamente. | Un contraejemplo concreto. | Dos o más contraejemplos y señala cuándo la respuesta "obvia" sería la equivocada. |

Peso por pregunta: declarado en cada enunciado (2 o 3 pts). Máximo 35 pts conceptual.

### 4.2 Ejercicio operativo

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Correctness (los comandos de validación pasan) | `terraform validate` falla. | Pasa `validate` pero varias tareas sin implementar. | Pasa `validate` y las 3 tareas implementadas. | Pasa `validate`, 3 tareas e incluye comentarios que explican el _por qué_ de cada decisión. |
| Seguridad / least-privilege | Introduce un role `Owner` o secret hardcodeado. | Usa roles amplios (`Contributor`) sin justificación. | Role scoped correctamente al RG/recurso. | Role scoped + MI user-assigned reutilizable + federated credential con subject pinneado a environment. |
| Mantenibilidad | Un solo archivo monolítico, variables sin tipo, nombres inconsistentes. | Organización básica pero variables sin `validation`. | Separación por archivo (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`) + variables con tipos. | Lo anterior + `validation` block + `moved` block si refactoriza + comentarios tipo "cuándo remover esto". |
| Justificación en comentarios | No hay. | Comentarios triviales ("# this is the key vault"). | Comentarios que explican _por qué_ (no _qué_). | Comentarios que anticipan la pregunta del revisor ("elegí user-assigned porque N recursos consumen la misma identidad"). |

Peso: OP-task-1 = 15 pts, OP-task-2 = 10 pts, OP-task-3 = 10 pts. Máximo 35 pts operativo. **Umbral mínimo:** 17 pts (sin esto no se aprueba el examen aunque la nota ponderada supere 70 %).

### 4.3 Ejercicio arquitectónico

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Alineación con los requisitos del escenario | Ignora requisitos clave (p. ej. multi-tenant, latencia). | Cubre los funcionales, ignora los no-funcionales. | Cubre funcionales + no-funcionales. | Lo anterior + explicita qué requisito se sacrificó y a cambio de qué. |
| Decisiones justificadas con trade-offs | "Elegimos X porque es moderno/popular". | Menciona un pro pero no el contra. | Pro + contra por decisión. | Pro + contra + umbral en que cambiarías de decisión. |
| ADR | No hay o es un bullet list. | Formato ADR pero sin consecuencias. | ADR completo (contexto, decisión, consecuencias). | ADR + fecha + alternativas descartadas + condición de revisión. |
| Mapeo AWS → Azure | Ausente o incorrecto (p. ej. IRSA → MI). | Parcial (3–4 capas). | Mapeo completo para todas las capas del escenario. | Mapeo + notas donde la analogía _no_ es 1:1 (p. ej. "no hay SCP, se cubre con Azure Policy deny"). |

Peso: 30 pts arquitectónico. **Umbral mínimo:** 15 pts.

---

## Sección 5 — Guía de corrección (instructor-only)

### Puntos clave esperados por pregunta

- **Q1 (C1):** El RG agrupa recursos con mismo ciclo de vida → `az group delete` es el "undo" barato de un ambiente. Riesgo: operador borra el RG equivocado (todo cae en cascada, incluidos recursos con `publicNetworkAccess` abiertos que no sabían que existían). Mitigación: resource locks (`CanNotDelete`), MGs separan workloads críticos, naming que delata el ambiente, PIM para `Owner`. Respuesta parcial aceptable: menciona cascade pero no la mitigación por MG.
- **Q2 (C2):** El developer puede: (1) tener el role en otro scope más amplio heredado (MG o Subscription padre); (2) ser miembro de un grupo con el role; (3) la role assignment estar sobre un RG específico; (4) existir otro role custom con `actions` equivalentes. Clave: Azure RBAC es _allow-based_, no hay `deny` que bloquee desde arriba — solo Azure Policy puede. **Respuesta inválida:** "porque Azure es seguro por defecto".
- **Q3 (C2):** Azure Policy con effect **`deny`**, assignado al scope **Management Group** que contiene las suscripciones objetivo (idealmente el root de "Landing Zones" en CAF). Variante aceptable: policy con parámetro `allowedLocations`. **Red flag en la respuesta:** `audit` (no bloquea).
- **Q4 (C3):** MI garantiza ausencia de secreto gestionado por humanos (rotación automática por Azure, no hay archivo con el valor). Pierde: no puede usarse fuera de Azure (un workload on-prem no tiene MI). User-assigned preferida cuando N recursos comparten la misma identidad (reutilizable, sobrevive al recreate del recurso cliente). Red flag: confundir MI con "SP sin password" — es un SP, pero gestionado.
- **Q5 (C4):** Private Endpoint = NIC con IP privada del VNet apuntando al servicio PaaS → DNS resolver privado resuelve `*.blob.core.windows.net` a IP interna; tráfico nunca sale al public internet. Service Endpoint = ruta optimizada + el servicio PaaS "sabe" que el request viene de tu VNet, pero el endpoint público sigue existiendo (depende de firewall rules del servicio para bloquearlo externamente). PE elimina egress; SE optimiza egress pero el endpoint público persiste.
- **Q6 (C5):** Para tráfico _ingress_ a la VM, se evalúan ambos NSGs en orden: subnet-level primero (permite), luego NIC-level (deniega) → el tráfico se bloquea. Respuesta inversa (NIC primero) es incorrecta pero común. Clave: la "effective rule" es la intersección — basta un deny para bloquear.
- **Q7 (C6):** (a) **Container Apps** por scale-to-zero + HTTP ingress managed; (b) **Container Apps** con KEDA scaler sobre Service Bus (o Functions con trigger Service Bus); (c) **AKS** porque Container Apps no permite sidecars arbitrarios ni configuración xDS. Respuesta parcial: elegir todo en AKS "por consistencia" es defensible si justifica costo operativo vs tres planos de control distintos.
- **Q8 (C7):** `session` por default (coherencia por usuario = suficiente para "mi carrito"). `strong` sería error porque obliga a sincronización global entre regiones → latencia inaceptable y pérdida de disponibilidad regional. `bounded staleness` si necesita leer stock casi-realtime pero puede tolerar X segundos de staleness. `eventual` si solo son recomendaciones.
- **Q9 (C8):** El flujo: pod monta token SA proyectado → intercambia por token Entra ID via federated credential (el claim `sub` del SA token empata el `subject` del federated credential registrado en la app Entra ID). Mapeo IRSA: ServiceAccount ↔ ServiceAccount, federated credential ↔ IAM OIDC trust policy, Entra ID app ↔ IAM role. Pod Identity v1 usaba un DaemonSet (NMI) que interceptaba IMDS — fallo en el NMI = fallo del pod; además era específico de Azure. Workload Identity es estándar OIDC, sin componentes en el data plane del cluster.
- **Q10 (C9):** Ingestion: Diagnostic Settings con `logs` filtrados (no mandar `kube-audit-admin`, no mandar `AllMetrics` si no se usan) + Container Insights con sampling. Retention: 30 días en Analytics tier + archive a Storage para forense. Consulta: `KQL` summarize antes de persistir alertas, no agregar en Workbooks sobre crudo. Mantener: `AzureActivity`, `SigninLogs`, `AuditLogs` (fuente de la señal de seguridad). **Red flag:** "reducir retention a 7 días" sin análisis → se pierde el postmortem.
- **Q11 (C11):** Falta asignar la **Managed Identity** que la policy usa para remediar (parámetro `assignIdentity` + `roleDefinitionIds`), o el role assignment correspondiente al scope. `audit` no habría tenido el problema porque no modifica estado — solo reporta non-compliance.
- **Q12 (C12):** Con subject `repo:owner/repo:*` un PR malicioso puede desencadenar un workflow (si hay `pull_request_target` o un `workflow_dispatch` manual mal protegido) que asume la identidad y accede a prod. Subject correcto: `repo:owner/repo:environment:prod` combinado con GitHub Environment con _required reviewers_ — así el token sólo se emite para un run que pasó por aprobación. Variantes: `repo:owner/repo:ref:refs/heads/main` para main-only. Red flag: aceptar "pin a cualquier branch main-ish" sin environment.
- **Q13 (C14):** RBAC data-plane: auditable con Activity Log unificado, delegable con los mismos roles de Azure RBAC, modelo mental único (no "dos planos: control plane RBAC + data plane access policies"). Soft delete + purge protection: ventana de recuperación (90 días) + nadie — ni Owner — puede purgar en esa ventana. Un `rm -rf` del Key Vault pone el recurso en estado soft-deleted, se puede recuperar.
- **Q14 (C15):** Firma garantiza _provenance_ (quién la emitió, en qué pipeline/repo) e _integridad_ (no mutó entre registry y runtime). **No** garantiza que la imagen esté libre de CVEs, ni que el código fuente esté auditado, ni que el `base image` sea confiable. La cadena correcta: scanner (CVEs) + firma (provenance) + policy (admission rules que exigen ambos).

### Errores comunes esperados y cómo puntuarlos

- Confundir Managed Identity con "Service Principal sin password" → 0 pts en Q4.
- Decir "Azure Policy = SCP de AWS" sin matizar que uno es declarativo-jerárquico y el otro es de autorización → 1 pt máximo en Q3.
- Elegir Container Apps para el caso (c) de Q7 porque "está en Azure" → 0 pts (indica que no entendió que CA abstrae K8s y no deja customizar).
- En OP-task-2 crear el `azurerm_user_assigned_identity` pero asignarle `Owner` al RG "para simplificar" → red flag, 0 pts en seguridad del operativo.
- En OP-task-3 configurar federated credential con `subject = "repo:owner/repo:*"` → red flag, 0 pts.
- En ARCH proponer AKS para todo "por consistencia" sin articular costo operativo → 1 pt máximo en justificación.

### Señales de "respondió sin entender"

- Copió el `subject` del federated credential del `README.md` sin cambiar `owner/repo` → el archivo entregado tiene el placeholder original.
- Comentarios en código generados por LLM que contradicen la decisión del código (p. ej. el código usa `for_each` pero el comentario dice "usamos count para iterar").
- ADR con sección "consecuencias" vacía o copiada de la sección "decisión".
- GUIDs del tenant/subscription no son los dummy del enunciado → o no leyó, o usó un tenant real (red flag).
- Diagrama Hub-Spoke donde los spokes están peered entre sí (anti-patrón: el hub deja de ser el único punto de inspección).

### Preguntas de seguimiento (evaluación live)

> Úsalas cuando la respuesta escrita suene correcta pero genérica. Objetivo: distinguir memorización de comprensión.

- **Para Q2/Q3:** "¿Qué pasa si asigno la policy `deny locations` al Tenant Root Group? ¿Rompe algo del plano de management?" (Esperado: afecta todo, incluyendo workloads de la propia Microsoft en tu tenant, por eso se asigna al MG `Landing Zones`.)
- **Para Q4:** "¿Qué objeto hay realmente en Entra ID cuando creas una system-assigned MI? ¿Cómo lo verías?" (Esperado: un service principal en el tenant, visible en `az ad sp list --display-name <resource-name>`.)
- **Para Q5:** "Si pongo un Private Endpoint a mi Storage Account y mis VMs on-prem acceden por ExpressRoute, ¿necesito algo más?" (Esperado: Private DNS Zone linkeada al VNet, forwarder/condicional en el DNS on-prem.)
- **Para Q9:** "El pod obtiene un token SA. ¿Dónde se valida que ese token efectivamente viene del cluster que registraste como issuer?" (Esperado: el federated credential en la app Entra ID tiene el OIDC issuer URL del cluster, Entra ID valida la firma contra el JWKS público.)
- **Para Q12:** "¿Cómo descubriste que el pipeline usaba `*` en el subject?" (Si no responde: `az ad app federated-credential list` o portal.)
- **Para ARCH:** "Si bajamos el presupuesto a la mitad, ¿qué sacrificas primero y por qué?" (Esperado: identificar lo que es _accidentalmente_ caro — Front Door en vez de App Gateway, Premium ACR si no se necesita geo-replication, Log Analytics ingestion.)

### Red flags (invalidan automáticamente el ejercicio en que ocurren)

Ver `competency-matrix.yaml` → `red_flags`. Las más críticas:

1. Credenciales / secretos / GUIDs reales en el entregable.
2. Service Principal con secret donde OIDC o MI eran posibles.
3. Federated credential sin pinning de `subject`.
4. Role `Owner`/`Contributor`/`cluster-admin` a un workload sin justificación.
5. Pod Identity v1 o Blueprints en un diseño nuevo.
6. Policy `audit` cuando se pidió prevenir.
7. `deployIfNotExists` sin la identity asignada.
8. Falsear ejecución de emuladores o `terraform validate` ("corrió en mi máquina" sin output pegado).

Cualquiera de las 1–4 es también una **falla de criterio profesional** y debe quedar anotada en el feedback del candidato, no solo descontada en el ejercicio.

---

## Checklist del candidato antes de entregar

- [ ] Todos los GUIDs son dummy (`00000000-...`).
- [ ] No hay secrets, keys ni passwords en ningún archivo (ni ejemplos "obvios" tipo `password = "changeme"` sin `# TODO`).
- [ ] `terraform fmt -check -recursive && terraform validate` pasa.
- [ ] `operative/README.md` tiene el output exacto de los comandos de validación.
- [ ] `architectural/decisiones.md` incluye los 4 entregables (diagrama, tabla, ADR, mapeo AWS→Azure).
- [ ] Si no corriste algún emulador: dejaste `SKIP: emulator no disponible` justificado.
- [ ] Releíste la sección _Red flags_.
