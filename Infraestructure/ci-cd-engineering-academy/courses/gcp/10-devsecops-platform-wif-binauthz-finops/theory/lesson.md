# Lección — DevSecOps y FinOps en GCP: WIF, Binary Authorization y unit economics

> Capstone del track GCP. Integra IAM (`gcp-02`), GKE Autopilot (`gcp-07`) y Org/Cloud Identity (`gcp-09`) en un pipeline end-to-end que no deja nunca una service account key en disco y que no admite imágenes sin firmar en producción.

---

## 1. Por qué este módulo existe

La mayoría de incidentes serios en pipelines CI/CD caben en dos categorías:

1. **Keys estáticas filtradas**. Una service account key con `roles/owner` termina en un repo público, un gist, un screenshot. El atacante hereda tu pipeline y, con él, tu production.
2. **Imágenes alteradas que llegan a producción**. Alguien hace push a un tag `latest` desde una máquina que no es la del pipeline. El cluster, que confía en el tag, la ejecuta. No queda rastro de dónde salió.

GCP resuelve ambas de raíz con dos primitivas que **no existen de forma nativa equivalente** en AWS (hay equivalentes construibles, pero no con la misma ergonomía):

- **Workload Identity Federation** elimina las keys: GitHub Actions obtiene un token OIDC propio, GCP lo cambia por un token de corta vida contra una service account que elegimos, y toda la operación queda en logs.
- **Binary Authorization** elimina el "cualquier imagen vale": GKE no admite un pod cuya imagen no tenga una *attestation* firmada por el attestor que la policy exige.

Además, cerramos el módulo con el otro ángulo del control de ingeniería: **FinOps**. No basta con saber qué cuesta la nube — hay que saber qué cuesta **una unidad de valor** entregada (una request servida, un customer activo). Ese cálculo se hace con el export de Billing a BigQuery, no mirando la UI.

---

## 2. Workload Identity Federation (WIF)

### 2.1 Qué problema resuelve

Antes de WIF, publicar una imagen desde GitHub Actions a Artifact Registry requería:

1. Crear una service account en GCP.
2. Generar una **key JSON** (`gcloud iam service-accounts keys create`).
3. Subirla a GitHub Secrets.
4. Rotarla "cuando toque" (en la práctica, nunca).

Esa key:

- No tiene expiración.
- No deja rastro de dónde se usó (los Audit Logs solo ven "la SA actuó").
- Si el atacante la obtiene, puede autenticarse desde su máquina indefinidamente.

WIF reemplaza este flujo con **federación OIDC**: GitHub Actions ya emite tokens OIDC firmados con su propia JWKS. GCP acepta esos tokens, los valida contra el provider que configuraste, y los **intercambia** por un `access_token` de corta vida que impersona la service account elegida — **sin que exista nunca una key JSON**.

### 2.2 Piezas

Tres recursos GCP:

1. **Workload Identity Pool** (`iam.googleapis.com/WorkloadIdentityPool`). Agrupador lógico de providers. Un pool por "sistema externo" (ej. `github`).
2. **Workload Identity Provider** OIDC (`iam.googleapis.com/WorkloadIdentityPoolProvider`). Dentro del pool, configura **cuál IdP** confías (`issuer_uri = https://token.actions.githubusercontent.com`) y **cómo mapear** sus claims a atributos GCP.
3. **IAM binding** en una service account: `roles/iam.workloadIdentityUser` concedido al principal `principalSet://iam.googleapis.com/projects/<n>/locations/global/workloadIdentityPools/<pool>/attribute.repository/<org>/<repo>`.

### 2.3 Attribute mapping y condition — el detalle crítico

```hcl
attribute_mapping = {
  "google.subject"       = "assertion.sub"
  "attribute.repository" = "assertion.repository"
  "attribute.ref"        = "assertion.ref"
  "attribute.actor"      = "assertion.actor"
}

# Pin: solo tokens de este repo pueden usar este provider.
attribute_condition = "assertion.repository == 'acme/checkout'"
```

El **error número uno** al configurar WIF es olvidar `attribute_condition`. Sin él, **cualquier** repo de GitHub puede pedir un token OIDC con tu `audience` y, si el binding en la SA no filtra por `attribute.repository`, impersonar la SA. El `attribute_condition` es la frontera que convierte "cualquier GitHub Action del planeta" en "solo este repo".

Buenas prácticas:

- `attribute_condition` siempre pinnea al menos `assertion.repository`.
- Para producción, pinnea también `assertion.ref == 'refs/heads/main'` o `assertion.ref_type == 'tag'`.
- El binding en la SA usa `principalSet://.../attribute.repository/<org>/<repo>` para una segunda defensa en profundidad.

### 2.4 Flujo del token (resumido)

1. GitHub Actions emite JWT con claims `sub`, `repository`, `ref`, `actor`.
2. El workflow hace `google-github-actions/auth@v2` con `workload_identity_provider` y `service_account`.
3. La action llama a STS GCP (`sts.googleapis.com/v1/token`) con el JWT y recibe un **federated token**.
4. Con ese token, llama a `iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/<SA>:generateAccessToken` y obtiene un `access_token` de hasta 1 h.
5. Ese `access_token` se usa para `gcloud` o SDKs. **Nunca se persiste**.

### 2.5 Audit trail

Cada paso aparece en Cloud Audit Logs:

- `AuthorizeToken` del pool/provider (identifica el repo, el ref, el actor de GitHub).
- `GenerateAccessToken` de la SA impersonada.
- Las acciones posteriores (`artifactregistry.repositories.uploadArtifacts`) aparecen con `authenticationInfo.principalSubject` apuntando a la federated identity.

Resultado: puedes responder "¿quién subió esta imagen?" con el **repo + ref + commit** de GitHub, no con "la SA `gha-publisher`".

---

## 3. Artifact Registry

### 3.1 Qué sustituye

Reemplaza **Container Registry** (`gcr.io`, deprecado — fechas de sunset han ido moviéndose, pero en 2026 ya es inviable para proyectos nuevos). Artifact Registry añade:

- Formatos múltiples en el mismo producto: Docker, Maven, npm, Python, Go modules, OS packages.
- Repos **regionales** o **multi-región**. Un repo `europe-west1-docker.pkg.dev/<project>/<repo>` es regional.
- IAM binding **por repositorio**, no por project — permite dar `writer` a GHA solo al repo `prod-images`.
- **Cleanup policies** declarativas (ej. "retén las últimas 20 versiones; borra `-dev-*` tras 7 días").
- **Vulnerability scanning** nativo vía Container Analysis.

### 3.2 Vulnerability scanning

Al habilitar la Container Scanning API, cada push a un repo Docker dispara un escaneo. Los hallazgos se publican como **Occurrences** en Container Analysis, con severidad CVE. Son consumibles por:

- La UI de Artifact Registry (vista por imagen).
- La API (`containeranalysis.googleapis.com`), para gates en el pipeline.
- Security Command Center (si está habilitado), que los agrega como findings.

Patrón recomendado: bloquear en el pipeline si hay CVEs con severidad `CRITICAL`, **pero** usar la gate del pipeline (no Binauthz) para esto — Binauthz es admisión en cluster, no validación en build.

---

## 4. Binary Authorization

### 4.1 Qué garantiza

Cuando el cluster está sujeto a una **policy** de Binary Authorization, al crear un Pod el admission controller consulta la policy. Si la imagen requiere una attestation y ésta falta o es inválida, el Pod es rechazado (modo `ENFORCED_BLOCK_AND_AUDIT_LOG`) o se audita pero se admite (modo `DRYRUN_AUDIT_LOG_ONLY`).

Las **attestations** son firmas criptográficas sobre el **digest** (SHA256) de la imagen, no sobre el tag. Esto elimina el ataque de "mismo tag, otra imagen".

### 4.2 Anatomía de una policy

```yaml
# binauthz-policy.yaml
defaultAdmissionRule:
  evaluationMode: ALWAYS_DENY
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG

clusterAdmissionRules:
  europe-west1.prod-autopilot:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
      - projects/my-project/attestors/build-attestor
      - projects/my-project/attestors/qa-attestor

admissionWhitelistPatterns:
  - namePattern: gcr.io/gke-release/*
  - namePattern: registry.k8s.io/*
  - namePattern: europe-west1-docker.pkg.dev/my-project/system/*
```

Claves:

- **`defaultAdmissionRule`** aplica donde no haya regla más específica. `ALWAYS_DENY` como default es el pattern "deny-by-default" que queremos.
- **`clusterAdmissionRules`** permite diferenciar entre `prod` y `dev` sin dos policies.
- **`admissionWhitelistPatterns`** exime imágenes del sistema (kube-system, control plane sidecars de GKE Autopilot) — **sin esto, el cluster no arranca** porque los pods de sistema fallan la admisión.

### 4.3 Attestors y Sigstore cosign

Un **attestor** es la "autoridad firmante aceptada". Internamente apunta a una **Container Analysis Note** y a una clave pública (PGP, PKIX o KMS). La integración con **Sigstore cosign** se hace vía:

- `cosign generate-key-pair --kms gcpkms://...` (clave en Cloud KMS).
- `cosign sign --key gcpkms://... <IMAGE>` tras el push.
- El attestor en Binauthz referencia la misma clave pública (o la clave KMS directamente via `pkixPublicKey`).

Para una org pequeña:

- `build-attestor` → firma en el pipeline tras build+test+scan OK. Clave en KMS, acceso solo via WIF desde el repo.
- `qa-attestor` (opcional) → firma manual tras QA. Clave en KMS, acceso solo via grupo `qa-signers`.

### 4.4 Rollout seguro

El modo `DRYRUN_AUDIT_LOG_ONLY` es el salvavidas: la policy evalúa, los rechazos se loggean, **nada se bloquea**. Sin esto, un error en la whitelist tira el cluster.

Secuencia recomendada:

1. Policy en `DRYRUN` 1 semana. Revisar `logName="projects/.../logs/binaryauthorization.googleapis.com%2Fcontinuous_validation"` y Audit Logs.
2. Afinar whitelist hasta cero rechazos espurios.
3. Promocionar a `ENFORCED` primero en el cluster de dev. Observar 48 h.
4. Promocionar a `ENFORCED` en el cluster de prod.
5. Dejar activo **también** `continuousValidationMode: ENABLED` — comprueba periódicamente que los pods **ya corriendo** siguen cumpliendo la policy (atrapa el caso "la policy cambió, pero los pods viejos no han sido re-admitidos").

---

## 5. Security Command Center (SCC)

Tres tiers en 2026:

- **Standard** (incluido): Security Health Analytics (misconfig común, SA con `roles/owner`, bucket público), Web Security Scanner.
- **Premium**: Event Threat Detection (anomalías en Audit Logs), Container Threat Detection (runtime en GKE), Virtual Machine Threat Detection, Rapid Vulnerability Detection.
- **Enterprise**: Premium + SIEM + SOAR + agente Mandiant, enfocado a SOC maduro.

Para este capstone basta Standard: lo relevante es que **las keys estáticas que WIF elimina ya no aparecen como finding**, cerrando el loop.

---

## 6. FinOps en GCP

### 6.1 Labels como mecanismo de allocation

GCP usa **labels** (`key=value`, hasta 64 por recurso). Convención del programa:

| Label | Valores | Owner |
|-------|---------|-------|
| `env` | `prod` / `stg` / `dev` / `sandbox` | obligatorio |
| `workload` | `checkout` / `analytics` / … | obligatorio |
| `cost-center` | `eng` / `data` / `platform` | obligatorio |
| `owner` | email del team lead | obligatorio |

**Guardrail**: Org Policy `gcp.resourceLocations` para forzar región, y `compute.requireOsLogin` para auditoría — pero **no** hay org policy nativa en 2026 que fuerce "estos labels sí o sí". Se verifica en el pipeline (TF plan parsea los labels) o con `gcloud asset search-all-resources --query='-labels.workload:*'`.

### 6.2 Billing export a BigQuery

El export estándar deposita, cada hora/día, una tabla `gcp_billing_export_resource_v1_<billing_account_id>` en BigQuery con columnas:

- `billing_account_id`, `invoice.month`
- `project.id`, `project.labels` (array de `{key,value}`)
- `service.description`, `sku.description`
- `usage.amount`, `usage.unit`, `cost`, `currency`
- `labels` (resource labels), `system_labels`
- `credits` (array con descuentos aplicados: SUDs, CUDs, promocionales)
- `resource.name`, `location.location`

Esto habilita queries por project, por label, por SKU, con descuentos ya aplicados — algo que la UI no ofrece con la misma flexibilidad.

### 6.3 CUDs vs SUDs

- **Sustained Use Discounts**: automáticos, se aplican por correr una VM >25 % del mes. No requieren compromiso. GKE Autopilot no los aplica directamente — el pricing per-pod ya los absorbe.
- **Committed Use Discounts**: compromiso 1 o 3 años. Dos formas:
  - **Resource-based CUD**: comprometes N vCPU + M GB RAM en una región.
  - **Spend-based CUD** (más reciente): comprometes gasto $/h en una familia de servicios. Más flexible.
- Decisión: comprar CUD solo si el baseline de utilización lleva estable ≥3 meses. Antes, SUDs son suficientes.

### 6.4 Recommender

`recommender.googleapis.com` emite recomendaciones automáticas:

- `google.compute.instance.MachineTypeRecommender` (rightsizing VMs).
- `google.iam.policy.Recommender` (quitar roles no usados en 90 d — útil para auditar bindings).
- `google.cloud.sql.instance.OverprovisionedRecommender`.

Consumibles por API o UI. Se pueden materializar en una tabla BigQuery con `gcloud recommender recommendations list` + export, y revisar en el ritual mensual de FinOps.

### 6.5 Unit economics

El salto de "sé qué cuesta" a "sé qué cuesta por unidad de valor" requiere unir el export de Billing con **métricas de negocio**: `requests_served`, `active_customers`, `monthly_transactions`. Las fuentes típicas: Cloud Monitoring, logs de la app exportados a BigQuery, Mixpanel/Amplitude si existe.

Dos KPIs base:

- **Coste por request**: `(SUM(cost) WHERE labels.workload='checkout') / SUM(requests_served)`.
- **Coste por customer activo mensual (MAC)**: `(SUM(cost) WHERE workload='checkout') / COUNT(DISTINCT active_customer_id)`.

El propósito no es la cifra absoluta — es ver la **tendencia** y detectar regresiones (una release que infla el coste por request 2× sin razón de negocio).

En la actividad 03 practicamos este cálculo contra un CSV sintético que imita el export de Billing, sin tocar BigQuery.

---

## 7. Mapping rápido AWS ↔ GCP (DevSecOps)

| Concepto | AWS | GCP |
|---------|-----|-----|
| OIDC desde GHA (sin keys) | OIDC provider + IAM role con trust policy | Workload Identity Federation (pool + provider + binding) |
| Registry de imágenes | ECR | Artifact Registry |
| Firma de imágenes | ECR + cosign + policy-controller | Artifact Registry + cosign + Binary Authorization (nativo) |
| Admisión por firma en cluster | EKS + Kyverno/policy-controller | GKE + Binary Authorization (nativo) |
| Billing export | CUR → S3 → Athena | Billing export → BigQuery (nativo) |
| Rightsizing automático | Compute Optimizer | Recommender |
| SOC centralizado | Security Hub | Security Command Center |

La diferencia clave: Binauthz **es parte del cluster**, no un add-on. Lo mismo ocurre con el billing export a BigQuery.

---

## 8. Decisiones típicas que deberías poder defender

1. **¿Por qué `attribute.repository` siempre en `attribute_condition`?**
2. **¿Por qué `DRYRUN` antes de `ENFORCED` en Binauthz, siempre?**
3. **¿Por qué el pipeline no firma con una clave en disco sino con una clave KMS?**
4. **¿Por qué el export de Billing a BigQuery habilita unit economics que la UI no?**
5. **¿Cuándo compras un CUD y cuándo te quedas con SUDs?**

Las actividades te obligan a aterrizar cada una.
