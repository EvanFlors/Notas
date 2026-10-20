# README-INTENT — MI vs Service Principal con secret

> Walkthrough del plan Terraform y comparación lado a lado. **No se ha aplicado nada**: todos los UUID y tenant IDs son placeholders. Fase 4 materializa este diseño con credenciales reales.

## Escenario recomendado (Managed Identity)

**Archivos involucrados**: `main.tf`, `variables.tf`.

**Plan mental — qué se crearía, en qué orden**

1. `azurerm_resource_group.demo` — el RG `rg-mi-demo` en `westeurope`. Unidad de deletion.
2. `azurerm_user_assigned_identity.app` — la Managed Identity `mi-checkout-app`. Al crearla, Entra ID emite un `principalId` (objectId del service principal subyacente).
3. `azurerm_key_vault.kv` con `enable_rbac_authorization = true` — Key Vault en modo RBAC data-plane (no access policies legacy).
4. `azurerm_role_assignment.mi_reads_secrets` — concede `Key Vault Secrets User` al `principal_id` de la MI, con `scope = azurerm_key_vault.kv.id` (el vault concreto, no el RG).
5. Red mínima (`azurerm_virtual_network`, `azurerm_subnet`, `azurerm_network_interface`) para dar un sitio a la VM.
6. `azurerm_linux_virtual_machine.app` con bloque `identity { type = "UserAssigned"; identity_ids = [...] }` — la pieza clave: al llevar ese bloque, IMDS en la VM podrá emitir tokens a nombre de la MI.

**Día 1 operativo**

La app arranca. `DefaultAzureCredential` del SDK Azure detecta que está en una VM con MI adjunta y llama a IMDS (`169.254.169.254`). Obtiene un access token para el audience `https://vault.azure.net`. Llama a `GET /secrets/db-password` del Key Vault con `Authorization: Bearer <token>`. Key Vault valida el token y, vía RBAC, comprueba que el `principalId` tiene `Key Vault Secrets User` en el scope del vault. Responde el secret. **Cero intervención humana. Cero secretos en código o env.**

**Día 180 operativo**

Idéntico. Azure rota el token de la MI cada ~24 h de forma transparente. Nadie "hace nada". No hay reminders en el calendar, no hay runbooks de rotación, no hay riesgo de olvido.

## Antipatron (Service Principal con secret)

**Archivos involucrados**: `main-antipattern.tf`, `variables.tf`.

**Plan mental — qué se crearía, en qué orden**

1. `azuread_application.checkout` — la app registration en Entra ID (plantilla global).
2. `azuread_service_principal.checkout` — instancia del app registration en el tenant (lo que RBAC asigna).
3. `azuread_service_principal_password.checkout` — **genera un client secret** con `end_date_relative = "4320h"` (≈180 días). El valor queda en el state de Terraform.
4. `azurerm_resource_group.demo`, `azurerm_key_vault.kv` — mismos recursos que en el patrón MI para que la comparación sea 1:1.
5. `azurerm_role_assignment.sp_reads_secrets` — mismo role, mismo scope. El único cambio real es *cómo* el workload obtiene el token.

**Día 1 operativo (pasos EXTRA respecto a MI)**

- Alguien copia el client secret del state al env de la app como `AZURE_CLIENT_SECRET`.
- Lo guarda también en el runner de CI para despliegues futuros.
- Un operador probablemente lo pegará, aunque sea temporalmente, en su `.bashrc` para debugging.
- Hay que documentar la fecha de caducidad y meterla en un calendar / recordatorio.

**Día 180 operativo**

El secret caduca. Si alguien recordó rotarlo (nuevo `azuread_service_principal_password`, actualizar env de la app, CI, operador…), todo bien. Si no, **prod cae**.

**Si el secret se filtra en día 90**

Hay 90 días adicionales de blast radius mínimo hasta que alguien lo note. La única mitigación es revocar manualmente el password y rotar todos los sitios donde se usa. No hay rotación automática.

## Comparacion

Comparación en los 4 ejes clave:

| Eje | Managed Identity | Service Principal + client secret |
|-----|------------------|-----------------------------------|
| **Rotación de credenciales** | Automática (~24 h), transparente, cero tareas humanas. | Manual, cada 6 meses, requiere ventana de cambio y comunicación. |
| **Blast radius de un leak** | No hay credencial que pueda leakear fuera de Azure. Un token concreto dura ~1 h y es sólo utilizable con el `aud` correcto desde la red/contexto del recurso. | El `client_secret` filtrado funciona desde cualquier IP hasta su revocación manual. Blast radius de días u horas, no segundos. |
| **Auditabilidad** | Las llamadas quedan atribuidas al `principalId` de la MI, siempre desde el recurso al que está adjunta — anomalía fácil de detectar. | Las llamadas quedan atribuidas al `objectId` del SPN, pero el origen puede ser *cualquiera* que tenga el secret (CI, dev local, 3rd party con el env filtrado). Analítica mucho más ruidosa. |
| **Recuperación tras incidente** | Rotar = destruir y recrear la MI (user-assigned) o rehacer el role assignment. Terraform-nativo. No hay secretos que distribuir. | Revocar password, generar uno nuevo, redistribuirlo a *todos* los consumidores, reiniciar workloads. Muchos pasos manuales, cada uno con oportunidad de romper algo. |

## Jerarquia de credenciales

Orden de preferencia defendible con los ejes anteriores:

1. **Managed Identity** (user-assigned preferido sobre system-assigned para fleets). Solo aplica cuando el workload corre dentro de un recurso Azure que la soporta (VM, VMSS, App Service, Container Apps, Functions, AKS vía Workload Identity…).
2. **OIDC Federated credential** (sobre un SPN, sin password). Aplica cuando el workload corre fuera de Azure pero el IdP del workload sí emite tokens OIDC: GitHub Actions, GitLab CI, otro Entra ID, K8s externo… El SPN confía en el `issuer` + `subject` del token y no custodia material secreto.
3. **Certificate** (sobre un SPN). Hay material criptográfico que custodiar, pero al menos no es un string copy-pasteable y la rotación con PKI está más resuelta.
4. **Client secret** (sobre un SPN). Último recurso. Si no queda alternativa, forzar: almacenamiento en Key Vault, rotación programada (`<=90` días), métricas de uso, alertas por acceso desde IP inesperada.

El workload de este módulo corre dentro de Azure (VM), así que el nivel (1) es alcanzable y debe elegirse. El workload del módulo `az-10` corre en GitHub Actions y por tanto el nivel (1) no aplica — ahí se usa (2) OIDC Federation.

## Notas de seguridad del propio entregable

- **No se ha aplicado nada**. No existe RG `rg-mi-demo` ni `rg-sp-demo` en ninguna subscription.
- **Todos los UUID / tenant IDs son placeholders**. En el main.tf se usa `data.azurerm_client_config.current.tenant_id` precisamente para no hardcodear.
- Si en Fase 4 se materializa esto, el state de Terraform debe vivir en un backend con encryption-at-rest + RBAC restrictivo (típicamente storage account con private endpoint + MI del runner con `Storage Blob Data Contributor`).

## Referencias cruzadas

- Lección §3 (MI system vs user-assigned), §8 (jerarquía de credenciales).
- Ejemplo `02-managed-identity-vm-to-keyvault/`.
- Módulo `az-06-key-vault-and-managed-identities-consumer` para el "consumer side" completo.
- Módulo `az-10-devsecops-oidc-defender-acr-supply-chain` para el nivel (2) OIDC Federation desde GitHub Actions.
