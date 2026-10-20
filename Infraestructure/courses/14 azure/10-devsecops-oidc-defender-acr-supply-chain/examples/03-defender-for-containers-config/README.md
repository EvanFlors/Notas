# Ejemplo 03 — Habilitar Defender for Containers (ACR + AKS)

> Lectura y analisis. Sin ejecucion. Objetivo: saber que habilitar en Defender for Cloud para cubrir **vuln scanning de ACR** y **runtime detection en AKS**, y leer el coste con criterio.

## 1. El esquema del plan

```
Microsoft Defender for Cloud (suscripcion)
  |
  +-- Plan: Defender CSPM            [tier Standard, opcional] -> posture, attack path
  +-- Plan: Defender for Servers     [tier Standard, opcional] -> endpoints en VMs
  +-- Plan: Defender for Containers  [tier Standard, requerido para az-10]
  |      - ACR vuln scanning (push + on-schedule)
  |      - AKS runtime detection (DaemonSet)
  |      - control plane posture
  +-- Plan: Defender for Key Vault   [tier Standard, recomendado]
  +-- Plan: Defender for Storage     [tier Standard, segun workload]
```

Activar un plan es por **subscription**. Multi-sub -> hay que hacerlo en cada una (o via Azure Policy `deployIfNotExists`).

## 2. Terraform minimo

```hcl
# Habilita el plan "Containers" en Standard (paid tier)
resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

# Recomendados (defensa en profundidad; opcionales en lab, criticos en prod)
resource "azurerm_security_center_subscription_pricing" "key_vault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

# Workspace donde publicar logs/alerts (puede ser el mismo que usas para App Insights)
resource "azurerm_log_analytics_workspace" "security" {
  name                = "la-security-${var.environment}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

# Opt-in de "auto-provisioning" del Defender agent en AKS (DaemonSet)
# NOTA: la API cambia; verificar en Fase 4. Alternativa: habilitar via `az aks update`.
```

## 3. Que detecta en ACR (vuln scanning)

Tras habilitar el plan Containers, **cada push a ACR** dispara una scan contra el **Microsoft Defender Vulnerability Management (MDVM)** engine. Resultados accesibles por:

- Portal: Defender for Cloud -> Recommendations -> "Container registry images should have vulnerability findings resolved".
- API: `GET /subscriptions/{sub}/providers/Microsoft.Security/assessments/...`
- Log Analytics: tabla `SecurityAlert` + `SecurityRecommendation`.

Formato tipico de un hallazgo:

| Campo | Ejemplo |
|-------|---------|
| Registry | `acrcheckoutprod` |
| Repository | `checkout` |
| Tag / digest | `sha256:abcd...` |
| CVE | `CVE-2024-4603` |
| Package | `openssl 3.0.11-r0` |
| Severity | `High` |
| Fix available | `3.0.12-r0` (si existe upstream) |

Base de datos de CVE: Red Hat + Microsoft + NVD. Linuxes soportados: Alpine, Debian, Ubuntu, CentOS/RHEL, Mariner, Amazon Linux. Imagenes **distroless** o con packages exoticos pueden no ser cubiertas; verifica con un test antes de confiar.

## 4. Que detecta en AKS (runtime)

Se instala un **DaemonSet** por node (el "Defender sensor"). Captura syscalls, procesos, conexiones. Detecta:

- Reverse shell en pod (`bash -i >& /dev/tcp/...`).
- Crypto mining (patrones de uso CPU + conexiones a pools conocidos).
- Lateral movement (service account anomalos usados para pedir secrets).
- Container escape attempts (`cap_add: SYS_ADMIN` + syscalls peligrosos).
- Imagenes conocidas maliciosas pulled recientemente.

Las alertas aparecen en:

- Portal: Defender for Cloud -> Security Alerts.
- Microsoft Sentinel: via data connector "Microsoft Defender for Cloud".
- Email/webhook: via Action Groups.

## 5. Que NO hace Defender for Containers

- No verifica **firma cosign**. Eso es trabajo de Ratify/Kyverno (ver ejemplo 02).
- No sustituye un **WAF** (eso es App Gateway WAF / Front Door WAF).
- No reemplaza un **SIEM**: Defender detecta; Sentinel correlaciona + hace playbooks.
- No escanea CVEs **de la aplicacion**: scanea el OS/packages de la imagen. Para dependencies de la app, usa Trivy/Snyk/GHCR en el pipeline.

## 6. Coste con criterio

| Pieza | Precio aprox 2026 |
|-------|-------------------|
| Defender for Containers — AKS | ~7 USD / vCPU-month del nodo |
| Defender for Containers — ACR scans | ~0.29 USD / imagen escaneada |
| Log Analytics ingestion | ~2.5 USD / GB |
| Microsoft Sentinel (adicional) | ~2.0 USD / GB (encima de LA) |

Simulacion: cluster AKS de 3 nodos x 4 vCPU = 12 vCPU -> **~84 USD/mes solo por AKS protection**. 500 pushes/mes -> **~145 USD/mes de ACR scans**. Log Analytics 10 GB/mes -> ~25 USD. Total: **~250 USD/mes** aproximado para un workload mediano. Dimensiona antes de habilitar.

**Trucos**:

- Habilita Containers solo en subscriptions con AKS/ACR en uso real (no en sandbox).
- Para dev, usa `trivy` en el pipeline (gratis) y reserva Defender para stg/prod.
- Retention de Log Analytics 30 d en lugar de 90 d reduce costo si no tienes compliance que lo exija.

## 7. Preguntas de autocomprobacion

1. Si pushearas 1000 imagenes/mes a ACR en una subscription con el plan Containers habilitado, ¿cuanto facturaria Defender solo por ACR?
2. ¿Que diferencia hay entre un "finding" de ACR (recomendacion) y una "alert" de AKS (incident)?
3. ¿Como pararias temporalmente las scans de un repo concreto sin desactivar el plan entero?
4. ¿Que capturarias en Sentinel que no aparece en Defender for Cloud a secas?
5. Para una org 100% serverless (Container Apps + Functions, sin AKS), ¿sigue justificando habilitar Defender for Containers?
