# az-10 — DevSecOps en Azure: OIDC, Defender, ACR y supply chain

## Identificacion

- **ID:** `az-10-devsecops-oidc-defender-acr-supply-chain`
- **Curso:** `azure`
- **Nivel:** produccion
- **Duracion estimada:** 6 h
- **Prerrequisitos:** `az-02` (Entra ID + RBAC + Managed Identities), `az-07` (AKS + Workload Identity), `az-09` (MGs + Policy + Landing Zone), curso **github-actions**, curso **docker**, curso **devsecops** Nivel 4.

## Objetivo

Aterrizar los controles DevSecOps del programa en el ecosistema Azure. Al terminar deberias poder — **en papel y con Terraform plan-only** — disenar un pipeline que (1) autentica GitHub Actions contra Entra ID **sin ningun secreto** usando **OIDC federation**, (2) construye y firma imagenes en **Azure Container Registry (ACR Premium)** con **cosign keyless**, (3) habilita **Microsoft Defender for Cloud** (plan Containers) para escaneo de vulnerabilidades y runtime, y (4) despliega a **AKS con Workload Identity**, bloqueando en admission las imagenes no firmadas.

## Alcance

Este modulo cubre:

- **OIDC Federation** GitHub Actions -> Entra ID **app registration** con **federated credential** (subject claim pinneado a `repo:owner/repo:ref:refs/heads/main` o `repo:owner/repo:environment:prod`); comparacion con el modelo de **service principal + client secret** y por que lo reemplaza.
- **ACR**: SKUs Basic/Standard/Premium (Premium necesario para geo-replication, Private Link, Content Trust *clasico*, Tasks, Zone Redundant); **ACR Tasks** para builds server-side sin runner propio; **repository-scoped tokens** para pulls limitados.
- **Microsoft Defender for Cloud**: paraguas CSPM + CWPP; **Defender for Containers** (vuln scanning ACR + runtime en AKS), **Defender for Key Vault**, **Defender for Storage**, **Defender for App Service**; alertas y recomendaciones; integracion con **Microsoft Sentinel** (SIEM/SOAR); multi-cloud (puede escanear AWS/GCP).
- **Supply chain**: **cosign keyless** firmando con el token OIDC del runner de GHA (sin claves persistentes), publicacion de la firma como artifact OCI en ACR; **verificacion en admission** con Ratify (o Kyverno + sigstore) en AKS.
- **Azure Policy for AKS** (OPA/Rego bajo el capo): mismas skills del curso devsecops; policies "deny images without signature" en el ingress al cluster.
- **Deployment Stacks** como mecanismo IaC gestionado con guardrails de deletion (sucesor de Blueprints).

Lo que **no** cubre (se vio o se vera):

- Base multi-subscription y Landing Zone -> `az-09`.
- AKS y Workload Identity base -> `az-07`.
- Defender for Cloud a profundidad SIEM/SOAR con Sentinel -> curso **devsecops** Nivel 5.
- Terraform operativo contra un tenant real: aqui el laboratorio es **plan-only** (archivos `.tf` que se leen y validan sin `terraform apply`).

Este modulo es **mayoritariamente conceptual + ADR + Terraform plan-only + YAMLs de GitHub Actions + policies de admission**. **No** se provisiona nada en un tenant Azure real. Las dos actividades son disenos escritos + artefactos de pipeline validados estructuralmente; el unico *tooling* es `bash`, `jq`, `python3` y un editor Markdown/YAML.

## Materiales

- **`theory/lesson.md`** — leccion profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y analisis, no ejecucion):
  - `01-oidc-federation-github-to-azure/` — anatomia del federated credential: `subject`, `issuer`, `audiences`; variantes por branch, por environment, por tag.
  - `02-acr-cosign-sign-and-verify/` — flujo keyless `cosign sign` + `cosign verify` contra una imagen en ACR, con transparencia Rekor.
  - `03-defender-for-containers-config/` — que habilita el plan Containers (ACR vuln scan + AKS runtime), que cuesta, que genera.
- **`activities/`** — dos actividades **independientes**:
  - `01-oidc-pipeline-tf-plan-and-adr/` — disenar la base de identidad federada + ACR + Defender con un **ADR**, archivos **Terraform plan-only** y un **workflow YAML de GitHub Actions** que use OIDC.
  - `02-cosign-signed-image-admission-pipeline/` — escribir el **workflow de build/sign/push**, la **policy de admission** que verifica firma en AKS y un `README-INTENT.md` justificando decisiones.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar que es un federated credential y por que reemplaza al client secret; diferencia entre **Defender for Cloud** y **Microsoft Sentinel**; que es "keyless signing" con cosign. |
| Operativa (sin infra) | Escribir el bloque `azuread_application_federated_identity_credential` de Terraform; escribir un workflow `actions/azure-login` con `permissions: id-token: write`; escribir la policy de admission que rechaza imagenes no firmadas. |
| Arquitectonica | Elegir ACR Premium vs Standard para un workload dado; decidir donde vive la Managed Identity que lee ACR desde AKS; justificar `cosign keyless` vs claves asimetricas en KMS. |

## Criterios de evaluacion

- Dado un workflow con `creds: ${{ secrets.AZURE_CREDENTIALS }}`, lo migras a OIDC federated credential y explicas por que es mas seguro.
- Lees un `federated_credential` y predices que branches/environments pueden asumir el app registration.
- Nombras tres cosas que **Defender for Containers** detecta y donde las ves (Portal / Log Analytics / Sentinel).
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `ADR-DEVSECOPS-SUPPLY-CHAIN.md` con decision de identidades, registry, defender y supply chain (sale de la actividad `01`).
- **Terraform plan-only**: `main.tf`, `oidc.tf`, `acr.tf`, `defender.tf` validos sintacticamente (sale de la actividad `01`).
- **Workflow GHA** `.github/workflows/build-sign-push.yml` con `permissions: id-token: write` y `uses: azure/login@...` sin secrets (sale de la actividad `02`).
- **Admission policy** YAML (Ratify o Kyverno) que verifica cosign signature en el cluster AKS (sale de la actividad `02`).

## Costos

**Ninguno**. Todo el modulo se desarrolla localmente contra archivos de texto, JSON, YAML y HCL. **No** se requiere tenant Azure, suscripcion ni runner activo. **No se ejecuta `terraform apply`.** Si en una fase posterior decides provisionar lo disenado:

- **Entra ID app registration + federated credential**: gratis.
- **ACR Basic**: ~5 USD/mes. **Standard**: ~20 USD/mes. **Premium**: ~165 USD/mes (necesario para Private Link y geo-replication).
- **Defender for Cloud**: CSPM Foundational gratis; **CSPM** plan paid ~5 USD/billable resource/mes; **Defender for Containers** ~7 USD/vCPU/mes (AKS nodes) + ~0.29 USD por imagen escaneada en ACR.
- **cosign + Rekor publico**: gratis.
- **AKS**: cluster control plane gratis en tier Free (SLO), ~0.10 USD/h en tier Standard (SLA 99.95). Nodos facturados aparte.

> **Importante**: este modulo **no** usa IDs reales de tenant ni de subscription, ni secretos reales. Todos los identificadores que veas en ejemplos (`00000000-0000-0000-0000-000000000000`, `tenant-id-placeholder`, `sub-id-placeholder`) son **ficticios**.

## Siguiente modulo

Fin del nivel 4 de la pista Azure. El capstone del programa integra az-10 con `az-07` (AKS) y `az-09` (Landing Zone) + el curso **devsecops**.
