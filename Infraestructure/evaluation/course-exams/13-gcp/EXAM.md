# Examen de certificación — Curso **GCP**

> **Nivel:** intermedio-avanzado (cubre `gcp-02`..`gcp-10` con base en `gcp-01`).
> **Dimensiones evaluadas:** todas (conceptual + operativa + arquitectónica).
> **Duración:** 90–120 min.
> **Umbral de aprobación:** 70% ponderado.
> **Modalidad:** take-home con validación automática; defensa oral opcional del instructor usando las "preguntas de seguimiento".
> **Idioma:** prosa en español; código, comandos, atributos IAM y HCL en inglés.
> **Entorno:** NO se requiere cuenta GCP real. El ejercicio operativo se valida con `terraform plan`, `tflint`, `checkov` y emuladores (`fake-gcs-server`, `firestore-emulator`); el ejercicio arquitectónico es documental (ADR + diagrama).

---

## 0. Instrucciones generales

1. Los **project IDs** en todos tus entregables son placeholders (`my-org-prod-123`, `my-org-shared-456`, `my-org-dev-789`). **No** incluyas IDs reales, números de billing account reales ni dominios reales.
2. **Prohibido** `terraform apply` contra GCP real. El operativo se evalúa sobre el output de `terraform plan -out=tfplan.binary` + `terraform show -json tfplan.binary`.
3. **Prohibido** adjuntar claves JSON de service accounts. Si tu solución las requiere, está mal diseñada.
4. Todo YAML/HCL que entregues debe pasar `yamllint` / `terraform fmt -check` / `tflint`.
5. Los `red_flags` listados en `competency-matrix.yaml` descuentan automáticamente y pueden invalidar la evaluación.

---

## 1. Matriz de competencias

Ver `competency-matrix.yaml` en el mismo directorio. Resumen de pesos por dimensión:

| Dimensión | Peso |
|-----------|------|
| Conceptual | 35% |
| Operativa | 35% |
| Arquitectónica | 30% |

---

## 2. Preguntas conceptuales (35%)

> 12 preguntas de respuesta corta. Máximo **8 líneas** por respuesta. Se califica comprensión, no verbosidad.

### Q1 — IAM: evaluación jerárquica con Deny Policy (C1)

Dado el siguiente estado:

- En `folders/prod` hay un **binding allow** `roles/storage.objectAdmin` → `group:platform@example.com`.
- En `projects/my-org-prod-123` (bajo `folders/prod`) hay un **binding allow** `roles/storage.objectViewer` → `user:alice@example.com` (alice pertenece a `platform@`).
- En `folders/prod` hay además una **IAM Deny Policy** con `deniedPrincipals: ["principalSet://goog/group/platform@example.com"]` y `deniedPermissions: ["storage.objects.delete"]`, sin condición.

**Pregunta:** ¿Puede `alice@` ejecutar `gsutil rm gs://my-org-prod-bucket/foo.txt`? Justifica paso a paso cómo se agregan los allows y por qué el deny decide. ¿Qué cambiaría si la Deny Policy tuviera `exceptionPrincipals: ["user:alice@example.com"]`?

### Q2 — Service Account keys vs impersonation (C2)

Un equipo opera CI local con un archivo `sa-key.json` descargado hace 14 meses. Explica **tres riesgos concretos** que esa práctica introduce (no "es inseguro" genérico) y describe el flujo que reemplaza ese archivo con **impersonation** para un desarrollador, señalando qué rol necesita el usuario humano y sobre qué principal se otorga.

### Q3 — VPC global, firewall por SA vs tags (C3)

Un equipo que viene de AWS pregunta: *"si mi VPC es global, ¿para qué sirven las subnets regionales y por qué puedo tener un firewall rule que se aplique a instancias en `us-central1` y en `europe-west1` a la vez?"* Explícalo y responde además: **¿por qué una firewall rule `targetServiceAccounts` es más robusta que una basada en `targetTags`?**

### Q4 — Cloud Run vs GKE Autopilot vs GCE MIG vs Functions gen 2 (C4)

Para cada uno de los siguientes workloads, elige la opción de compute y da **una razón decisiva** (no "porque es más barato" solo):

1. API HTTP stateless, picos impredecibles, p95 de 150 ms, acepta cold-start de 1–2 s el 1% de las requests.
2. Job batch nocturno de 90 min que procesa 2 TB de datos con GPU T4.
3. Microservicio con sidecar propio de service mesh que necesita 7 contenedores por pod, running 24/7 con tráfico constante.
4. Webhook de Stripe que debe responder < 1 s y procesa ~500 req/día.

### Q5 — Elección de data store (C5)

Un equipo quiere "DynamoDB en GCP". Describe por qué **ni Firestore ni Bigtable son un drop-in replacement** y en qué eje decides entre ambos. Luego responde: ¿**cuándo** justificarías saltar a Spanner y qué costo asumes al hacerlo?

### Q6 — CMEK vs cifrado por default; Secret Manager en Cloud Run (C6)

(a) Un auditor pide "cifrado en reposo" para un bucket GCS que ya existe. ¿Necesitas **obligatoriamente** CMEK? ¿Qué pregunta harías antes de responder sí o no?
(b) Describe cómo expones un secreto de Secret Manager a un servicio Cloud Run **sin** escribir su valor en el YAML/Terraform. ¿Qué permiso IAM necesita la service account del servicio y sobre qué recurso?

### Q7 — GKE Autopilot: restricciones y Workload Identity (C7)

(a) Nombra **dos capacidades de pod** que Autopilot bloquea y explica **por qué** son parte del contrato (no "porque sí"). (b) Compara Workload Identity (GKE) con IRSA (EKS) en **una** diferencia operativa concreta que haga el flujo GCP más ergonómico.

### Q8 — Workload Identity Federation: previniendo suplantación cruzada (C8)

Tienes un Workload Identity Pool con un Provider OIDC de GitHub Actions. Un atacante crea un fork público del repo o un repo nuevo bajo la misma org `my-github-org`. Explica:

(a) ¿Qué **attribute condition** debes poner en el provider para que solo el repo `my-github-org/payments-service` y la rama `refs/heads/main` puedan impersonar la SA `deploy@my-org-prod-123.iam.gserviceaccount.com`?
(b) ¿Por qué `assertion.repository_owner == "my-github-org"` **no basta** como única condición?

### Q9 — Binary Authorization: qué garantiza y qué no (C9)

Binary Authorization está activo en un cluster GKE Autopilot con una policy que requiere `attestations` de un atestador `cosign-prod-attestor`. Responde:

(a) Si un atacante compromete el pipeline de build y firma una imagen con una vulnerabilidad crítica, **¿Binauthz la bloquea?** Justifica.
(b) ¿Qué dos controles complementarios cierran ese hueco?

### Q10 — Audit Logs: Admin Activity vs Data Access (C10)

Explica por qué los logs **Admin Activity** son gratis y siempre están activos, mientras que **Data Access** logs son opt-in y pueden ser caros. Da un ejemplo de un evento que cae en cada categoría. ¿Qué política de activación recomendarías para una org pequeña en etapa seed?

### Q11 — FinOps: labels, billing export, CUDs vs SUDs (C12)

(a) ¿Por qué un billing export a BigQuery habilita análisis que la UI de billing no permite? Da **un** ejemplo de query útil (en una línea en SQL).
(b) Diferencia **Committed Use Discounts** vs **Sustained Use Discounts** en una frase cada uno y di cuándo un CUD de 1 año es un error.

### Q12 — Global HTTP(S) LB con anycast vs Route53 + ALB regional (C13)

Explica por qué el Global HTTP(S) LB de GCP permite **una sola IP anycast** publicada por DNS, y qué simplifica eso frente al patrón AWS "Route53 latency-based routing → ALB por región". ¿Qué pierdes al adoptar ese patrón?

---

## 3. Ejercicio operativo (35%)

> **Entorno:** local, sin GCP real. Validación con `terraform plan`, `tflint`, `checkov`, `yq`, `cosign`, `bq query --use_legacy_sql=false` (dry-run con `--dry_run`).
> **Materiales de inicio:** `operative/starter/` en este directorio (ver `operative/README.md` para el enunciado completo).
> **Tiempo sugerido:** 40–50 min.

### Resumen de las sub-tareas

| Tarea | Competencia | Entregable | Validación automática |
|-------|-------------|------------|-----------------------|
| OP-task-1 | C8 | `wif.tf` creando `google_iam_workload_identity_pool` + `..._provider` con attribute mapping y attribute condition sobre `repository` **y** `ref`. | `terraform plan -out=tfplan.binary` + `jq` sobre el plan JSON que verifique presencia de la condición. |
| OP-task-2 | C8 | `sa_binding.tf` otorgando `roles/iam.workloadIdentityUser` a la SA `deploy@` **solo** desde el principal correcto (`principalSet://.../attribute.repository/my-github-org/payments-service`). | `jq` sobre el plan JSON. |
| OP-task-3 | C9 | `binauthz.tf` con un `google_binary_authorization_policy` que exija el attestor `cosign-prod-attestor` para `clusters: ["projects/my-org-prod-123/locations/us-central1/clusters/gke-prod"]`, y `defaultAdmissionRule.evaluationMode = REQUIRE_ATTESTATION`. | `checkov` + `jq` sobre el plan JSON. |
| OP-task-4 | C10 | `audit_sink.tf` con un `google_logging_project_sink` filtrado a `logName:"cloudaudit.googleapis.com/activity"` destino BigQuery dataset `audit_logs`, con `exclusions` para `k8s.io/events`. | `jq` sobre el plan JSON. |

Ver `operative/README.md` para el detalle, criterios de aceptación y rúbrica.

---

## 4. Ejercicio arquitectónico (30%)

> Ver `architectural/scenario.md`. Entregas: diseño + ADR + diagrama (mermaid) + migration plan.
> **Tiempo sugerido:** 30–40 min.
> **Formato:** un Markdown único `architectural/answer.md` del alumno con las 4 secciones solicitadas.

---

## 5. Rúbrica

### 5.1 Rúbrica de preguntas conceptuales (por pregunta)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Precisión conceptual | Confunde conceptos (p. ej. "deny GCP es como security group") | Nombra el concepto pero no explica mecanismo | Explica mecanismo + consecuencia | Añade un trade-off o caso límite no pedido |
| Razonamiento ("por qué") | Afirma sin justificar | Justificación circular | Causalidad clara | Causalidad + alternativa descartada |
| Transferencia AWS→GCP (cuando aplica) | Mapeo errado | Mapeo correcto superficial | Mapeo + diferencia operativa | Mapeo + diferencia + consecuencia de diseño |

Nota mínima por pregunta para "no reprobar la sección": promedio ≥ 1.5.

### 5.2 Rúbrica del ejercicio operativo

| Criterio | Peso | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------|------------------|------------|----------------|-------------|
| Correctness (el plan refleja la intención) | 30% | `terraform plan` falla | Plan válido pero recurso principal mal configurado | Plan válido, recursos correctos | Plan + outputs útiles + variables tipadas |
| Seguridad | 25% | WIF sin attribute condition / Binauthz en ALWAYS_ALLOW | Condición débil (solo `repository_owner`) | Condición doble (`repository` + `ref`) + REQUIRE_ATTESTATION | Añade `attestation.jwt_token` claim pinning o policy per-namespace |
| Idempotencia / limpieza | 15% | Recursos duplicados, sin `locals`/`for_each` | Funciona pero con repetición | DRY con `for_each`/`locals` | Módulos reutilizables tipados |
| Validación automática pasa | 20% | `tflint` o `checkov` falla con criticidad alta | Falla con criticidad media | Pasa `tflint`, `checkov --skip-check LOW` | Pasa todo + justifica cada skip con comentario |
| Documentación | 10% | Sin README o sin explicar decisiones | README mínimo | README + diagrama + supuestos | README + ADR + justificación de alternativas descartadas |

Umbral de aprobación de la sección: ≥ 1.8 ponderado.

### 5.3 Rúbrica del ejercicio arquitectónico

| Criterio | Peso | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------|------------------|------------|----------------|-------------|
| Jerarquía Org/Folder/Project | 20% | Un solo project para todo | Separación por entorno pero sin folders | Folders prod/dev/shared + project por workload×entorno | Añade `folders/sandbox` + billing export aislado |
| Identidad y acceso | 20% | Bindings a usuarios individuales / SA keys | Grupos sin WIF | Groups + WIF para CI | Groups + WIF + impersonation para humanos + Deny Policy perimetral |
| Red | 15% | VPC auto, IP pública en VMs | VPC custom pero sin Shared VPC | Shared VPC host + service projects + Private Google Access | Añade Cloud Armor + managed cert + CDN y justifica cada uno |
| Guardrails (Org Policies) | 15% | Ninguna | 1–2 básicas | ≥4 defensivas (disableSaKeyCreation, vmExternalIp=deny, publicAccessPrevention, allowedPolicyMemberDomains) | ≥4 + política de constraint custom |
| Supply chain (WIF + Binauthz) | 15% | Keys estáticas o Binauthz desactivado | WIF sin condition / Binauthz ALWAYS_ALLOW | WIF con condition doble + Binauthz REQUIRE_ATTESTATION | Añade attestor por entorno + rotación cosign documentada |
| ADR | 15% | No hay ADR o solo "porque sí" | Alternativas listadas sin descartar | Decisión + alternativas descartadas con razón | Añade reversibilidad y "si fallara, cómo lo sabría" |

Umbral de aprobación de la sección: ≥ 1.8 ponderado.

### 5.4 Umbral global

- **Aprueba:** ≥ 70% del total ponderado **y** ninguna sección por debajo de su umbral de sección.
- **Red flag crítico** (ver `competency-matrix.yaml`): invalida la pregunta/tarea donde aparezca; si aparecen ≥ 2 red flags, invalida el examen aunque la suma dé ≥ 70%.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo (resumen; detalle en `operative/README.md` para OP y en el scenario para ARCH)

- **Q1 — IAM/Deny:** NO puede borrar. Allow bindings se agregan por jerarquía (alice obtiene `storage.objectViewer` del project + `storage.objectAdmin` heredado del folder vía membresía al grupo). La Deny Policy **evalúa antes** y bloquea `storage.objects.delete` para cualquier miembro del grupo sin condición de exclusión. Con `exceptionPrincipals: ["user:alice@example.com"]`, el deny no aplica a alice y el allow heredado le permite borrar. Puntos clave: (i) deny ⟶ allow (evaluation order), (ii) deny es por permission, no por rol, (iii) exception principal lo saca de la lista.
- **Q2 — SA keys:** riesgos aceptables: (1) exfiltración + no rotación (14 meses sin logs de uso), (2) ausencia de attestation del origen del request (no sabemos qué pipeline/host la usa), (3) blast radius: la key es portable, sobrevive a off-boarding. Reemplazo: `roles/iam.serviceAccountTokenCreator` al usuario humano **sobre la SA** (no sobre el project), `gcloud auth application-default login --impersonate-service-account=...`.
- **Q3 — VPC global:** subnet regional define el rango IP y la ubicación de recursos, pero la VPC es un único plano de ruteo; no se necesita peering intra-VPC. Firewall por SA = identidad: aunque muevas la VM a otra subnet o la recrees, mantiene la identidad; tags son strings mutables sin autenticación.
- **Q4:** (1) Cloud Run (scale-to-zero + concurrency), (2) GCE MIG o GKE con GPU (Cloud Run no soporta T4 reliably y 90 min excede límites típicos de Run; aceptable: Cloud Run jobs con nodo A100 si lo justifica), (3) GKE (Cloud Run limita contenedores por servicio y no permite sidecars arbitrarios), (4) Cloud Functions gen 2 o Cloud Run (ambos válidos; aceptar cualquiera con justificación de simplicidad operativa).
- **Q5:** Firestore = document, strong consistency a nivel documento, pensado para patrones mobile/web con queries limitadas; Bigtable = wide-column, baja latencia a escala masiva, requiere diseño de row-key correcto, no indexes secundarios. DynamoDB no mapea limpio porque mezcla ambos. Spanner cuando necesitas SQL + global strong consistency; costo: mínimo $$ y curva de aprendizaje de interleaved tables + split points.
- **Q6:** (a) No necesariamente: GCS cifra por default con claves Google. CMEK solo si política interna/regulatoria exige clave gestionada por el cliente, rotación controlada, o crypto-shredding. Pregunta: *¿la política exige key ownership del cliente?*. (b) Montar como volumen o `--set-secrets`; permiso `roles/secretmanager.secretAccessor` sobre el **secret específico** (no el project).
- **Q7:** (a) `hostNetwork`, `hostPath`, `privileged`, capacidades añadidas — porque Autopilot cobra per-pod y comparte el pool de nodos entre tenants lógicos: romper el aislamiento rompería el modelo. (b) WI no requiere OIDC trust explícito con el cluster (es un claim mapping gestionado por GCP); IRSA requiere crear el OIDC provider del cluster EKS y mapear el `sub` manualmente.
- **Q8:** (a) `assertion.repository == "my-github-org/payments-service" && assertion.ref == "refs/heads/main"`. (b) `repository_owner` deja pasar cualquier repo del org, incluyendo repos nuevos que un empleado con permiso de crear repos puede abrir; el ataque es trivialmente escalable.
- **Q9:** (a) NO: Binauthz verifica **que la imagen fue firmada por un atestador autorizado**, no que la imagen esté libre de CVEs. (b) scanning + policy que bloquee critical en Artifact Registry; separación de duties en el atestador (quien firma ≠ quien hace build).
- **Q10:** Admin Activity registra mutaciones (crear VM, cambiar binding IAM) — siempre on, barato, obligatorio para compliance básico. Data Access registra lecturas y escrituras de datos (p. ej. `storage.objects.get`) — volumen enorme → opt-in. Recomendación seed: Admin + Data Access `WRITE` activados globalmente; `READ` solo en projects/datasets sensibles.
- **Q11:** (a) Billing UI agrupa por project/SKU/label a baja granularidad y sin JOIN con metadata propia; BigQuery permite JOIN con una tabla de ownership por project o label para charge-back. Query ejemplo: `SELECT labels.value AS team, SUM(cost) FROM \`billing.gcp_billing_export_v1_*\` WHERE labels.key = 'team' GROUP BY team`. (b) CUD = compromiso 1 o 3 años por vCPU/memoria; SUD = descuento automático por uso sostenido en GCE/GKE Standard. Error: CUD en workload con demanda incierta o con ciclo de vida < 1 año.
- **Q12:** Una IP anycast enruta al PoP de Google más cercano al cliente; Google hace el health-check y failover entre backends regionales por ti. Simplifica: un solo `A` en DNS, un solo cert managed, sin latency routing. Pierdes: control fino de routing per-cliente (p. ej. "fuerza a este cliente a EU por residencia") y portabilidad del patrón DNS a otros clouds.

### 6.2 Errores comunes esperados

- Confundir Deny Policy con VPC-SC perimeters.
- "WIF es más seguro" sin saber decir **qué** mitiga (robo de key estática).
- Recomendar Spanner por "porque es managed" sin reconocer el costo mínimo.
- Autopilot: justificar restricciones con "porque sí" en vez de "modelo multi-tenant interno".
- Binauthz: creer que verifica contenido de la imagen (CVEs).
- Confundir CMEK con CSEK (customer-supplied).
- En el operativo: WIF con condition `assertion.repository_owner` únicamente (red flag).

### 6.3 Señales de "respondió sin entender"

- Copiar bloques HCL de la documentación oficial sin cambiar los placeholders (`YOUR_POOL_ID`, `PROJECT_NUMBER`).
- Usar `roles/owner` para la SA del pipeline "temporalmente".
- Diagrama mermaid genérico sin arcos de confianza (OIDC → Pool → SA).
- Explicar WIF reproduciendo el diagrama de Google pero sin nombrar `attribute condition`.

### 6.4 Red flags (invalidación automática — ver `competency-matrix.yaml`)

Reiteración de los más críticos para el corrector:

1. Key JSON de SA presente en el entregable.
2. WIF sin `attribute condition` sobre `repository`.
3. Binauthz en `ALWAYS_ALLOW` o `dryrun` en producción sin ADR que lo justifique.
4. Project IDs o billing account IDs reales.
5. `terraform apply` ejecutado contra GCP real.

### 6.5 Preguntas de seguimiento para evaluación live

> El instructor las usa para distinguir memorización de comprensión. Elegir 2–3.

- *"Si el equipo de red te pide quitar la Shared VPC porque 'añade complejidad', ¿cómo argumentas la decisión en 2 min?"* (C3, C11)
- *"Un dev dice: ¿por qué no me das `roles/editor` en el project de dev y ya? Dime qué pierdes y qué ganas."* (C1, C11)
- *"Explícame qué pasa si el pipeline firma la imagen antes de que el scanner termine. ¿Es un bug o es diseño?"* (C9)
- *"Si mañana GitHub rota el `iss` del OIDC provider, ¿qué se rompe y cómo lo detectas?"* (C8)
- *"¿Por qué un Deny Policy no reemplaza a VPC Service Controls?"* (C1, C3)
- *"Autopilot bloquea `hostPath`. ¿Qué patrón alternativo propondrías para una app legacy que lo requiere, sin salir de GKE?"* (C7)
- *"Diseñaste CMEK para GCS. Si pierdes la key version activa sin backup, ¿qué pasa con los objetos?"* (C6)

---

## 7. Checklist de entrega del alumno

- [ ] `operative/answer/` con `*.tf`, `tfplan.binary`, `tfplan.json`, `README.md` de decisiones.
- [ ] `architectural/answer.md` con diseño + ADR + mermaid + migration plan.
- [ ] Respuestas Q1..Q12 en `conceptual/answers.md` (crear).
- [ ] `terraform fmt -check` y `tflint` pasan en `operative/answer/`.
- [ ] Ningún project ID, billing account ID o dominio real.
- [ ] Ninguna clave JSON de service account.
- [ ] `terraform apply` NO ejecutado.
