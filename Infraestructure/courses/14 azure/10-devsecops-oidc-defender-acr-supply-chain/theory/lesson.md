# az-10 — Leccion: DevSecOps en Azure (OIDC + Defender + ACR + supply chain)

> 12 secciones. Mayoritariamente conceptual con ejemplos de HCL y YAML. Prerrequisitos: `az-02`, `az-07`, `az-09`, cursos **github-actions**, **docker**, **devsecops** Nivel 4.

---

## 1. Por que OIDC y no "service principal con secret"

El patron historico para que un pipeline externo (GitHub Actions, GitLab, Jenkins) desplegara a Azure era:

1. Crear un **service principal** (`az ad sp create-for-rbac`).
2. Guardar su `clientSecret` en el vault del CI (p. ej. `secrets.AZURE_CREDENTIALS` en GHA).
3. Rotarlo "cuando acordaramos" (en la practica: casi nunca).

Problemas:

- El secret vive en un vault **fuera** de Azure (el de GitHub). Un leak de ese vault compromete tu subscription.
- La rotacion manual produce ventanas sin cobertura o secrets huerfanos acumulandose en `az ad sp list`.
- El principio **"zero long-lived credentials"** se rompe por diseno.

**OIDC Federation** cambia el modelo: GitHub emite un **ID token** firmado por su propia OIDC issuer, el workflow lo envia a Entra ID, y Entra ID — si confia en ese issuer **y** el `subject` del token coincide con un **federated credential** registrado — devuelve un token de acceso de Azure de corta duracion (1 h). **No hay secret**. La relacion de confianza se expresa declarativamente en Terraform.

> **Idea clave que repetiremos:** OIDC convierte la autenticacion CI->cloud de "guardar un secreto" a "pinnear un claim". El claim `subject` describe **que repo, que ref, que environment** puede obtener un token; cualquier cambio de ese tuple invalida la credencial.

---

## 2. OIDC federation en Entra ID: la pieza concreta

En Entra ID se materializa como un **federated identity credential** adjunto a un **app registration**. Esquema conceptual:

```
GitHub Actions runner
   | (OIDC token con claims: iss, aud, sub, repository, ref, environment, job_workflow_ref)
   v
Entra ID issuer validation
   | (comprueba iss = https://token.actions.githubusercontent.com)
   | (comprueba aud = api://AzureADTokenExchange)
   | (busca federated_credential con subject == claim.sub del token)
   v
Si matchea -> emite access_token (1h, scope de la subscription/RG objetivo)
Si no      -> AADSTS70021 "No matching federated identity record found"
```

Patrones de `subject` tipicos:

| Caso | Subject claim |
|------|---------------|
| Build desde rama main | `repo:acme/checkout:ref:refs/heads/main` |
| Deploy desde environment prod | `repo:acme/checkout:environment:prod` |
| Deploy desde tag semver | `repo:acme/checkout:ref:refs/tags/v*` (requiere wildcard support) |
| Reusable workflow compartido | `repo:acme/platform:ref:refs/heads/main` + `job_workflow_ref` claim |

**Lo que SI podes pinnear**: repo, owner, ref, environment, pull_request (atencion con fork PRs — en general **no** otorgar OIDC a PRs de forks), job_workflow_ref.

**Lo que NO deberia aparecer en tu subject**: valores libres del attacker (branch names no sanitizados en configuracion), estrellas o wildcards sobre `repository` (eso convierte el claim en un "cualquier repo mio puede").

HCL minimo (Terraform, `azuread` provider):

```hcl
resource "azuread_application" "deployer" {
  display_name = "gha-deployer-checkout"
}

resource "azuread_service_principal" "deployer" {
  client_id = azuread_application.deployer.client_id
}

resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.deployer.id
  display_name   = "gha-main-branch"
  description    = "GitHub Actions on main branch of checkout repo"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:acme/checkout:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "deployer_rg_contrib" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.deployer.object_id
}
```

Workflow YAML correspondiente:

```yaml
permissions:
  id-token: write     # necesario para que GHA emita el OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4
      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - run: az account show
```

Fijate: **no hay `client-secret`**. Los tres IDs viven en `vars` (publicos) porque **no son secretos** — solo identifican la app a usar; el acceso lo da el OIDC token efimero.

---

## 3. Scopes y least-privilege en el app registration

El app registration **por si solo no puede nada**. Necesitas role assignments. Tres principios:

1. **Scope al RG de la aplicacion, nunca al tenant ni a la subscription entera.** Un `Contributor` a nivel subscription da al pipeline poder de borrar todo (incluido el app registration que lo autentica).
2. **Un app registration por workload + environment** (checkout-dev, checkout-prod). Separar explosiona el modelo pero clava el blast-radius.
3. **Roles especificos antes que `Contributor`.** Para push a ACR, basta `AcrPush` (data plane). Para gestionar AKS, `Azure Kubernetes Service Cluster User Role` + `Azure Kubernetes Service RBAC Writer`. Evita `Owner` siempre.

Error comun: dar `Contributor` **y** `User Access Administrator` al pipeline "porque hace falta para asignar roles a la Managed Identity del cluster". Mejor: separa esa parte en un workflow one-shot ejecutado por un humano con PIM, no por el runner continuo.

---

## 4. ACR: SKUs, Private Link y repository-scoped tokens

**Azure Container Registry** es el registry OCI de Azure. Tres SKUs:

| SKU | Precio aprox | Features |
|-----|--------------|----------|
| Basic | ~5 USD/mes | 10 GB storage incluidos. Un solo region. |
| Standard | ~20 USD/mes | 100 GB storage. Webhooks. |
| Premium | ~165 USD/mes | 500 GB. **Geo-replication**, **Private Link / Private Endpoint**, **Content Trust** (clasico, en deprecacion suave a favor de cosign), **ACR Tasks** (builds server-side), **Zone Redundancy**, **repository-scoped tokens**. |

Decision tipica: **Premium en prod** (Private Link + geo + Tasks); Standard en dev si no necesitas Private Link.

**Private Link**: ACR deja de responder por su FQDN publico desde la VNet objetivo; se accede via Private Endpoint con IP privada. Combinado con `publicNetworkAccess = Disabled`, cierra la superficie publica. AKS puede resolver el endpoint via Private DNS Zone.

**Repository-scoped tokens**: en lugar de un principal con acceso a todo el registry, generas tokens con scope `repositories/checkout:pull`. Util para equipos que solo deben pullear ciertas imagenes (consumidores externos, builds de otras unidades).

Terraform minimo:

```hcl
resource "azurerm_container_registry" "main" {
  name                = "acrcheckoutprod"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  sku                 = "Premium"
  admin_enabled       = false          # nunca true en prod — abre user/pass
  public_network_access_enabled = false
  zone_redundancy_enabled       = true

  trust_policy {
    enabled = true                      # content trust clasico (Notary v1)
  }
  retention_policy {
    days    = 30
    enabled = true
  }
}
```

> **Trampa**: `admin_enabled = true` crea un user/password dentro del registry. Lo deja habilitado "para pruebas" y nunca se cierra; cualquier leak compromete el registry entero. **No lo actives.**

---

## 5. Microsoft Defender for Cloud: el paraguas CSPM + CWPP

**Defender for Cloud** unifica dos capacidades distintas:

- **CSPM (Cloud Security Posture Management)**: inventario, recomendaciones de configuracion, Secure Score, compliance (CIS/PCI/NIST). Hay un tier **Foundational** gratis y un tier **Defender CSPM** paid con agentless scanning, Attack Path Analysis, data-aware posture, identity posture.
- **CWPP (Cloud Workload Protection Platform)**: proteccion runtime por tipo de recurso. Catalogo de "planes":

| Plan | Que hace |
|------|----------|
| Defender for Servers | Vuln assessment, endpoint protection, JIT VM access, File Integrity Monitoring. |
| Defender for Containers | **Vuln scanning de imagenes en ACR** (push + ongoing), **runtime threat detection en AKS** (via DaemonSet), control plane posture, admission controller recommendations. |
| Defender for Databases | SQL/Postgres/Mongo threat detection. |
| Defender for Storage | Malware scan de blobs, deteccion de uploads sospechosos. |
| Defender for Key Vault | Alertas por acceso anomalo, intentos de exfiltracion. |
| Defender for App Service | Deteccion de web attacks en App Service. |

**Multi-cloud**: desde el portal de Azure puedes conectar una cuenta AWS o un proyecto GCP y Defender escanea sus recursos (traduce EKS/ECR/RDS a sus equivalentes). Util como "single pane of glass" en orgs multi-cloud sin desplegar un SIEM dedicado.

**Defender for Containers** concretamente:

```
Push a ACR  ->  trigger vuln scan (MDVM engine)
            ->  resultados visibles en Portal + API + Log Analytics
            ->  recomendaciones por imagen (CVE, severity, package, fix version)

AKS cluster -> instala DaemonSet "Defender sensor"
            -> genera alertas runtime (reverse shell, mining, lateral movement)
            -> publica a Log Analytics / Sentinel
```

Terraform:

```hcl
resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "key_vault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}
```

> **Costos**: Containers factura por vCPU de AKS (~7 USD/vCPU/mes) + por imagen escaneada (~0.29 USD cada una). Un cluster de 10 vCPU con 500 imagenes/mes esta en ~215 USD/mes de este plan solo. Habilitar solo donde aplica.

---

## 6. Microsoft Sentinel: SIEM/SOAR encima de todo

**Sentinel** no es parte de Defender for Cloud; es un **SIEM** separado que se "conecta encima" de un Log Analytics Workspace. Ingesta logs (connectors nativos de Entra ID, Defender for Cloud, Office 365, firewalls), permite escribir **analytics rules** (KQL) que generan **incidents**, y define **playbooks** (Logic Apps) para respuesta automatica.

Mapeo mental:

| Pieza | Equivalente AWS |
|-------|-----------------|
| Defender for Cloud (CSPM+CWPP) | Security Hub + Inspector + GuardDuty |
| Microsoft Sentinel | Security Lake + Detective (parcial) + custom SOAR |
| Log Analytics Workspace | CloudWatch Logs (destino) |

En el modulo az-10 **no** construimos Sentinel: su uso serio aparece en el curso devsecops Nivel 5. Aqui basta saber que Defender for Containers puede empujar sus alertas a Sentinel con un conector nativo.

---

## 7. cosign keyless: firma sin claves persistentes

La supply chain moderna no quiere "una clave privada que firme imagenes" (otro secret que custodiar). **cosign keyless** usa el mismo OIDC token del runner para pedir a **Fulcio** un certificado X.509 efimero (10 min), firma la imagen con la clave privada temporal correspondiente, publica la firma y el certificado como un artifact OCI junto a la imagen, y registra la transparencia en **Rekor** (log append-only publico).

Flujo:

```
GHA runner
  | OIDC token (identidad del workflow)
  v
Fulcio CA  -> emite cert X.509 con el subject del token (10 min TTL)
  |
  v
cosign sign --identity-token $TOKEN  acr.azurecr.io/checkout@sha256:...
  |
  v
Rekor log  <- registra (hash de la firma, cert, timestamp)
  |
  v
ACR  <- recibe la firma como OCI artifact adyacente a la imagen
```

Verificacion (en el cluster o en CI):

```bash
cosign verify \
  --certificate-identity "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  acr.azurecr.io/checkout@sha256:<digest>
```

Lo pinneas por **workflow concreto** (`certificate-identity`) y por **issuer** (`certificate-oidc-issuer`). Un atacante que comprometa otro workflow no puede falsificar firmas de este.

Workflow GHA:

```yaml
jobs:
  build-sign:
    permissions:
      id-token: write       # OIDC a Azure Y a Fulcio
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - run: az acr login --name acrcheckoutprod
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}
      - uses: sigstore/cosign-installer@v3
      - name: Sign image (keyless)
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign sign --yes \
            acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}
```

Nota: cosign **no** necesita secret alguno — lee el OIDC token del propio runner.

---

## 8. Admission control: Ratify vs Kyverno + sigstore

Firmar es la mitad del trabajo; el cluster debe **rechazar** imagenes sin firma. Dos opciones mainstream en AKS:

### 8.1 Ratify (CNCF, Microsoft-sponsored)

Admission controller especifico para verificacion de artefactos (firmas cosign, SBOMs, vuln reports). Config:

```yaml
apiVersion: config.ratify.deislabs.io/v1beta1
kind: Store
metadata:
  name: store-oras
spec:
  name: oras
---
apiVersion: config.ratify.deislabs.io/v1beta1
kind: Verifier
metadata:
  name: verifier-notation-cosign
spec:
  name: cosign
  artifactTypes: application/vnd.dev.cosign.artifact.sig.v1+json
  parameters:
    key: ""   # keyless
    certificate-identity: "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main"
    certificate-oidc-issuer: "https://token.actions.githubusercontent.com"
```

### 8.2 Kyverno + sigstore

Kyverno es un policy engine generalista. Policy:

```yaml
apiVersion: kyverno.io/v2beta1
kind: ClusterPolicy
metadata:
  name: require-cosign-signature
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences:
            - "acrcheckoutprod.azurecr.io/checkout:*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

**Cual usar**: Ratify si solo necesitas verificacion de artefactos y queres soporte Microsoft; Kyverno si ya lo tenes para otras policies (require-labels, require-resources, etc.) y queres consolidar.

**Azure Policy for AKS** (built-in `[Preview] Kubernetes clusters should not allow container privilege escalation` etc.) **no** cubre verificacion cosign a dia de hoy — requiere Kyverno/Ratify instalados.

---

## 9. Workload Identity para el cluster que lee ACR

El cluster AKS necesita credenciales para pullear imagenes privadas desde ACR. Opciones:

1. **ACR integration** (`az aks update --attach-acr <name>`): asigna el role `AcrPull` al kubelet identity del cluster. Simple. Preferida para el 90% de los casos.
2. **Workload Identity** por SA: el pod que corre `kubectl pull` indirectamente (p. ej. ArgoCD) autentica con una Managed Identity federada a su ServiceAccount; util cuando distintos namespaces leen distintos registries.

Para los pods normales que **solo corren** la imagen, el pull lo hace el kubelet con la identity del cluster — no es el pod quien habla con ACR.

```hcl
resource "azurerm_role_assignment" "aks_pull_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

---

## 10. Deployment Stacks: IaC con guardrails

**Deployment Stacks** (GA desde 2024) empaqueta un conjunto de recursos ARM/Bicep como un **stack** gestionado por Azure, con:

- **Deny settings**: evita que alguien borre o modifique recursos del stack via Portal/CLI por fuera del IaC.
- **Action on unmanage**: al remover un recurso del template, Azure puede dejarlo intacto, borrarlo, o solo "desadoptarlo".
- **Scope**: subscription, RG o MG.

Es el sucesor de **Blueprints** (deprecados). En DevSecOps es util porque un stack con `deny-delete` sobre el Key Vault o el ACR impide que un pipeline comprometido borre el registry entero.

```bash
az stack sub create \
  --name checkout-prod \
  --location westeurope \
  --template-file main.bicep \
  --deny-settings-mode denyDelete \
  --action-on-unmanage deleteResources
```

Terraform aun no cubre Deployment Stacks como recurso nativo; se invoca via `azapi_resource` o se delega en CLI dentro del pipeline.

---

## 11. Mapping con AWS (modulo aws-16 equivalente)

| Concepto | Azure | AWS |
|----------|-------|-----|
| OIDC federation desde GHA | Entra ID app registration + federated credential | IAM OIDC provider + IAM role trust policy con `sts.amazonaws.com` audience |
| Registry OCI managed | ACR (SKUs Basic/Standard/Premium) | ECR (private/public) |
| Vuln scanning registry | Defender for Containers (ACR scan) | Amazon Inspector v2 (ECR scan) |
| Runtime threat detection cluster | Defender for Containers DaemonSet (AKS) | GuardDuty EKS Protection |
| CSPM | Defender CSPM | Security Hub + Config |
| SIEM encima | Microsoft Sentinel | Security Lake + custom |
| Firma de imagenes | cosign (OSS) | cosign (OSS) + ECR tags + Signer |
| Admission verifier | Ratify / Kyverno | Kyverno / OPA Gatekeeper |
| IaC con guardrails | Deployment Stacks | CloudFormation StackSets + SCP |

Las skills de admission (Rego/Kyverno) son identicas; la autenticacion es analoga; cosign es identico. La diferencia real esta en **nombres** y **superficie de UI**.

---

## 12. Trampas, errores comunes, y como depurar

### 12.1 OIDC falla con `AADSTS70021`

Significa "no matching federated identity record". Pasos:

1. Capturar el claim `sub` del token enviado: en el runner, `curl $ACTIONS_ID_TOKEN_REQUEST_URL -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN"` y decodificar el JWT en jwt.io.
2. Comparar literalmente con el `subject` del `federated_credential`. Caracteres invisibles, mayusculas, o `refs/heads/main` vs `main` suelen ser la causa.
3. Comprobar que el workflow tiene `permissions: id-token: write` (sin eso, GHA ni siquiera emite token).

### 12.2 `cosign sign` falla con "no identity token"

El runner no esta solicitando OIDC a Fulcio. Soluciones: `COSIGN_EXPERIMENTAL=1` (en versiones viejas), confirmar `permissions: id-token: write` en el job, cosign >= 2.0.

### 12.3 Admission rechaza una imagen "legitima"

Causas tipicas:

- Firma en otro registry (migraste de ACR dev a ACR prod y la firma se quedo en dev).
- `certificate-identity` apunta a `.github/workflows/old-build.yml` y renombraste el workflow.
- Reloj del cluster desfasado > 10 min -> cert efimero vencido.

Depuracion: `kubectl describe pod <failing>` muestra el motivo de la admission denial; `cosign verify` desde una laptop replica la logica.

### 12.4 Defender for Containers no scanea

- Verifica que el **plan Containers** este en `Standard` para la subscription (no es gratis).
- La primera scan tarda ~15 min tras el push. Impaciencia != bug.
- Imagenes multi-arch: cada manifest de arch cuenta como una scan.

### 12.5 El pipeline tiene permisos de mas

Smell: el app registration del pipeline tiene `Owner` en subscription. Fix: moverlo a `Contributor` scoped al RG + `AcrPush` scoped al registry + `Azure Kubernetes Service RBAC Writer` scoped al cluster. Si duele reducir, es porque el modelo mental era "una app, mi reino"; corregilo antes de que algo arda.

---

> Fin de la leccion. Las dos actividades (`01-oidc-pipeline-tf-plan-and-adr`, `02-cosign-signed-image-admission-pipeline`) te hacen escribir el disenio y los artefactos del pipeline. Ninguna requiere tenant Azure real.
