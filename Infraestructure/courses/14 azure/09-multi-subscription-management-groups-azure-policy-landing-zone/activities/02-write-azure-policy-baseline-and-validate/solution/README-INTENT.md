# Baseline de Azure Policy — intent de las 3 definitions

Documento de referencia que acompaña a los 3 `policyDefinition` del baseline. Explica, por policy, qué hace, dónde se asigna, qué parámetros expone y qué excepciones aplica.

---

## policy-deny-locations

**Qué hace**: deniega la creación de cualquier recurso cuya `location` **no** esté en el set permitido. Por defecto, solo se permiten `westeurope` y `northeurope` (compliance EU). Exceptúa recursos con `location = "global"` (Front Door, DNS Zones, Traffic Manager, Role Definitions) y Microsoft Entra ID B2C directories, que son recursos globales y no respetan la región.

**Dónde se asigna**: en el **MG `contoso` (Intermediate Root)** para que herede a toda la org. Se asigna con `enforcementMode = "Default"` (activo).

**Parámetros expuestos**:

- `allowedLocations` (Array): lista de regiones permitidas. Default `["westeurope", "northeurope"]`. Permite reutilizar la misma definición con distintas listas en MGs hijos si en el futuro aparece una excepción (p. ej. `Landing Zones/Online/global-cdn` necesita `eastus` por latencia a tooling SaaS).

**Por qué exceptuar `global`**: Azure asigna `location = "global"` a los recursos cuya consistencia es globalmente replicada (Front Door, DNS Zones, Traffic Manager, Role Definitions, Role Assignments). Si no exceptuáramos `global`, la primera vez que un deploy intenta crear un Front Door o una Private DNS Zone, el `deny` lo bloquearía — rompiendo workloads legítimos. Los **servicios globales** siempre deben exceptuarse, con `NotAction` en SCPs de AWS y con `field: location notEquals "global"` en Azure Policy.

**Excepciones**: no se contemplan excepciones de usuarios/roles particulares. Si un desarrollador necesita puntualmente crear algo en `uksouth`, se crea una **Azure Policy exemption** con TTL (p. ej. 7 días) y un `exemptionCategory: Waiver` justificado por ticket.

---

## policy-deny-public-ip

**Qué hace**: deniega la creación de recursos de tipo `Microsoft.Network/publicIPAddresses` en el scope asignado.

**Dónde se asigna**: en el **MG `Landing Zones/Corp`**, no en `Online` ni en `Platform`. Justificación:

- `Platform/Connectivity` necesita publicar un Public IP para el hub (si en el futuro habilitamos Azure Firewall o VPN Gateway).
- `Landing Zones/Online` por diseño expone endpoints públicos (analytics dashboards) — denegarlo rompería el workload.
- `Landing Zones/Corp` por diseño es "interno"; cualquier workload corporativo debe usar Private Endpoints + ExpressRoute (o Front Door si expone al mundo), nunca Public IPs directos. Esta policy fuerza esa arquitectura.

**Parámetros expuestos**: ninguno (regla simple binaria). Si en el futuro quisiéramos un parámetro `effect` para pasarla de `deny` a `audit` en una migración, se añade una entrada en `parameters`.

**Excepciones**: ninguna en el baseline. Un Public IP legítimo en Corp (p. ej. un bastion compartido) requerirá una **policy exemption** justificada por ticket + fecha de retirada (migrar a Azure Bastion sin IP pública expuesta).

**Comparación con SCP de AWS**: el equivalente es una SCP que deniegue `ec2:AllocateAddress` o `s3:PutBucketPublicAccessBlock` con `IgnorePublicAcls = false`. En AWS a menudo se controla con S3 Block Public Access a nivel de account; en Azure es más limpio con una Policy a nivel de MG.

---

## policy-audit-diagnostic-settings

**Qué hace**: para cada `Microsoft.KeyVault/vaults`, Azure busca un recurso hijo `Microsoft.Insights/diagnosticSettings` con `logs.enabled = true` y un `workspaceId` configurado. Si no existe, marca el Key Vault como **non-compliant** en el reporte de compliance del tenant. **No bloquea** la creación (sería `deny`); solo auditia.

**Dónde se asigna**: en el **MG `contoso` (Intermediate Root)** para cobertura total. Alternativa: solo en `Landing Zones` si prefieres no auditar los Key Vaults internos de `Platform` (los cuales ya tienen diagnostic settings gestionados por el deploy ALZ).

**Parámetros expuestos**:

- `logAnalyticsWorkspaceId` (String): resource ID del workspace central de **Log Analytics** (típicamente en `management-prod` sub). Si se deja vacío, cualquier workspace se considera válido. En nuestro baseline no vinculamos un workspace específico aún — la validación es "existe un diagnostic setting apuntando a algún Log Analytics".

**Por qué `auditIfNotExists` y no `deny`**: los `diagnostic settings` son un **recurso hijo separado** del Key Vault, creado por una operación ARM distinta (`Microsoft.Insights/diagnosticSettings@2021-05-01-preview`). Si usáramos `deny`, bloquearíamos la creación del Key Vault inicial — pero las diagnostic settings se crean típicamente **después**. `auditIfNotExists` evalúa el estado conjunto en el barrido periódico de compliance (~24h). Si quisiéramos **forzar** la creación en vez de solo auditar, cambiaríamos a `deployIfNotExists` (DINE) con una Managed Identity que tenga `Monitoring Contributor` sobre el Key Vault y `Log Analytics Contributor` sobre el workspace.

**Mención a Log Analytics**: el baseline asume un **Log Analytics workspace** central en la subscription `management-prod` (MG `Platform/Management`). Todos los diagnostic settings deben apuntar ahí. La compliance de esta policy, junto con la assignment de la initiative *Deploy-Diagnostics-LogAnalytics* en Fase 2, garantiza que ningún recurso quede sin trazabilidad.

**Extensión natural**: duplicar esta policy para otros tipos sensibles — `Microsoft.Storage/storageAccounts`, `Microsoft.Sql/servers/databases`, `Microsoft.Network/applicationGateways`, `Microsoft.ContainerService/managedClusters` — o mejor, agruparlas en una **initiative** `enforce-diagnostic-settings` y asignarla en bloque.

---

## Resumen de asignaciones

| Policy | Scope de assignment | Efecto efectivo | Comentario |
|--------|---------------------|-----------------|------------|
| `policy-deny-locations` | MG `contoso` | `deny` | Compliance EU; parametrizable por MG hijo. |
| `policy-deny-public-ip` | MG `Landing Zones/Corp` | `deny` | Fuerza arquitectura con Private Endpoints. |
| `policy-audit-diagnostic-settings` | MG `contoso` | `auditIfNotExists` | Detectivo; informa non-compliance en reporte. |

Fase 2 (planificado): agrupar las 3 en una **initiative** `platform-baseline-v1` y asignar la initiative en vez de las policies individuales — un solo mando para toda la org.
