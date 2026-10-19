# REFERENCE — az-10-01-oidc-pipeline-tf-plan-and-adr

> Una **referencia** razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

# ADR 002 — Base DevSecOps del pipeline (OIDC + ACR + Defender + supply chain)

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisar con Security + Platform y materializarse con Terraform en Fase 4.

## Contexto

Hoy el pipeline de GitHub Actions despliega a Azure usando un **service principal con `client_secret`** almacenado en `AZURE_CREDENTIALS` (secret de GHA). El secret se roto hace 14 meses. Dos consecuencias:

- **Riesgo de leak**: cualquier compromiso del vault de GHA (p. ej. una action maliciosa en el workflow) expone credenciales de larga duracion a la subscription entera.
- **Fatiga de rotacion**: nadie rota lo que molesta rotar; el credential tiene 15 scopes porque "no se sabe cual se necesita".

Ademas, el equipo de Security pide (regulatorio PCI-light sobre `checkout-prod`):

1. **Zero long-lived credentials** en el pipeline.
2. **Firma criptografica** de las imagenes que llegan a prod + verificacion en admission.
3. **Vuln scanning continuo** de las imagenes publicadas en ACR, no solo "en el build".
4. **Alertas runtime** cuando algo raro ocurre dentro de los pods de prod.

Constraints de la org:

- Dos workloads: `checkout` (PCI-light, prod en Europa) y `analytics` (interno, dev-only).
- Base multi-subscription ya establecida en `az-09` (MGs CAF). Nuestras subscriptions objetivo: `sub-platform` (identidad), `sub-checkout-prod`, `sub-checkout-stg`, `sub-checkout-dev`, `sub-sandbox`.
- No vamos a mantener servidor Rekor propio: usamos el publico de sigstore.

## Decision

### 1. Identidad: OIDC Federation GHA -> Entra ID

Para cada combinacion `workload x environment` creamos un **app registration** dedicado con un **federated credential** pinneado al subject correspondiente:

| App registration | subject | Scope (role assignments) |
|------------------|---------|--------------------------|
| `gha-deployer-checkout-dev` | `repo:acme/checkout:ref:refs/heads/main` | `Contributor` en `rg-checkout-dev`; `AcrPush` en `acrcheckoutdev` |
| `gha-deployer-checkout-stg` | `repo:acme/checkout:environment:stg` | `Contributor` en `rg-checkout-stg`; `AcrPush` en `acrcheckoutstg` |
| `gha-deployer-checkout-prod` | `repo:acme/checkout:environment:prod` | `AKS RBAC Writer` en `aks-checkout-prod`; `AcrPush` en `acrcheckoutprod` |
| `gha-deployer-analytics-dev` | `repo:acme/analytics:ref:refs/heads/main` | `Contributor` en `rg-analytics-dev`; `AcrPush` en `acranalytics` |

**Prod usa `environment:` subject** (no `ref:`), para forzar que GHA aplique el environment protection rule (reviewers required + protected branches). Dev usa `ref:refs/heads/main` por simplicidad: push a main dispara deploy automatico.

**Sin `client_secret` en ningun momento.** Los IDs (`client-id`, `tenant-id`, `subscription-id`) viven en `vars` de GHA, publicos por diseno.

### 2. Registry: ACR por entorno, Premium solo donde justifica

| Registry | SKU | Private Link | admin_enabled | Trust |
|----------|-----|--------------|---------------|-------|
| `acrcheckoutprod` | **Premium** | Si | false | content trust ON (defensa en profundidad; verificacion real via cosign) |
| `acrcheckoutstg` | Standard | No | false | — |
| `acrcheckoutdev` | Standard | No | false | — |
| `acranalytics` | Basic | No | false | — |

Justificacion: `checkout-prod` necesita Private Link (requerido por el PCI-light control de superficie) y Zone Redundancy. Standard es suficiente para dev/stg. Basic basta para `analytics` (es interno, bajo volumen).

### 3. Supply chain: cosign keyless + Ratify en AKS

- **Firma**: todas las imagenes de `checkout` se firman con `cosign sign --yes` en el runner de GHA. Keyless (OIDC del runner contra Fulcio). Transparencia publica en Rekor es aceptable (los digests no revelan secretos y el repo es privado).
- **Verificacion**: Ratify instalado en AKS, Verifier `cosign` con `certificate-identity` pinneado a `.github/workflows/build-sign-push.yml@refs/heads/main` y `certificate-oidc-issuer` fijo al OIDC de GHA.
- **Policy de admission**: `enforce` desde el dia uno en namespaces de prod; `audit` durante 7 dias en stg; sin policy en dev (para no bloquear iteracion local).

### 4. Defender for Cloud

| Plan | tier | Donde | Por que |
|------|------|-------|---------|
| Defender for Containers | Standard | `sub-checkout-prod`, `sub-checkout-stg` | Vuln scanning ACR + runtime AKS. |
| Defender for Key Vault | Standard | `sub-checkout-prod` | Alertas por acceso anomalo al vault que custodia la BD. |
| Defender for Storage | Standard | `sub-checkout-prod` | Malware scan del Storage Account usado para uploads. |
| Defender CSPM | Standard | Todas | Attack Path Analysis, Secure Score. |

**Dev y sandbox**: solo CSPM Foundational (gratis). Para dev usamos `trivy` en el pipeline (gratis) y no pagamos Defender.

### 5. Microsoft Sentinel

Fuera de scope de `az-10`. Conectamos Defender for Cloud al Log Analytics Workspace `la-security-prod` y preparamos el terreno para Sentinel en Fase 5 (DevSecOps Nivel 5).

### 6. Terraform plan-only (archivos entregados)

- `terraform/main.tf` — providers.
- `terraform/oidc.tf` — app registrations + service principals + federated credentials.
- `terraform/acr.tf` — registries por entorno.
- `terraform/defender.tf` — Security Center pricing (Containers / KeyVaults / Storage).

En Fase 4, `terraform init && terraform plan && terraform apply` tras sustituir los placeholders de IDs reales.

## Consecuencias

### Positivas

- Cero secretos de larga duracion en GHA secrets.
- Rotacion deja de ser un operation task recurrente.
- Blast-radius de un workflow comprometido queda acotado al RG del environment que podia tocar.
- Imagenes rechazadas en admission si no estan firmadas por el workflow esperado.
- Vuln scanning continuo (push + ongoing) de prod y stg.
- Compliance Europa + PCI-light defendible frente al auditor.

### Negativas

- Mas app registrations y mas role assignments (4 app registrations para 2 workloads). **Mitigacion**: Terraform modulariza con un module `federated_app_registration`.
- Defender for Containers cuesta ~215 USD/mes en el cluster de prod (10 vCPU + 500 imagenes/mes). **Mitigacion**: solo habilitado en prod/stg; dev usa trivy.
- Ratify instalado anade un admission webhook mas; downtime del webhook rompe deploys. **Mitigacion**: HA del webhook (2 replicas), `failurePolicy: Ignore` solo en namespaces no criticos.
- cosign keyless publica metadatos en Rekor (publico). Para proyectos propietarios con nombres sensibles, considerar Rekor privado (fuera de scope).

## Alternativas descartadas

### Alt A: Service principal con client_secret rotado por script

- **Por que no**: no elimina la clase de riesgo "secret en vault externo". Rotacion automatica solo mitiga parcialmente.

### Alt B: Managed Identity del runner self-hosted en Azure

- Correr runners self-hosted en una VM/Container App con MI asignada. Sin OIDC federation.
- **Por que no**: operar runners self-hosted anade coste y superficie (patching, aislamiento). OIDC federation da el mismo beneficio sin runners propios.

### Alt C: Firma con clave propia (cosign no-keyless) en Key Vault

- **Por que no**: introduce un secret (la priv key) que custodiar. Keyless elimina esa custody. Keyless gana por defecto; solo revertimos si Rekor publico se vuelve un problema regulatorio.

### Alt D: Dejar la auth con client_secret y endurecer solo cosign/Defender

- **Por que no**: resuelve el 70% del riesgo pero deja la puerta de entrada abierta. La migracion a OIDC es barata (horas) comparada con el riesgo residual.

---

## Nota sobre IDs

Todos los IDs (tenant, subscription, client) en los `.tf` son placeholders `00000000-0000-0000-0000-000000000000`. En Fase 4 se sustituiran por los reales desde un `tfvars` versionado por cuenta.
