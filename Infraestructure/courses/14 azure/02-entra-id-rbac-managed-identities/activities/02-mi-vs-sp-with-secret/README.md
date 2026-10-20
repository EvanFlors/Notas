# Actividad 02 — Plan Terraform + walkthrough: MI vs Service Principal con secret

## 1. Identificación

- **ID:** `az-02-02-mi-vs-sp-with-secret`
- **Tecnología:** `azure`
- **Módulo:** `az-02-entra-id-rbac-managed-identities`
- **Dificultad:** intermediate
- **Duración estimada:** 85–100 min
- **Tipo:** architecture (independent — sin dependencia funcional de la actividad 01, aunque la refuerza)

## 2. Contexto

Un equipo ha heredado un workload que lee Key Vault desde una VM Linux usando un **Service Principal con client secret** inyectado como variable de entorno. Rotan "a mano" cada 6 meses y el secret está también en el `.bashrc` del operador. Vas a defender ante el equipo la migración a **Managed Identity**.

Tu encargo:

1. Modelar en Terraform (sin `apply`) **dos escenarios lado a lado**:
   - `main.tf` (recomendado): VM con **user-assigned Managed Identity** + `azurerm_role_assignment` concediendo `Key Vault Secrets User` sobre el vault.
   - `main-antipattern.tf`: SP con `azurerm_application` + `azurerm_service_principal` + `azurerm_service_principal_password` (client secret) + role assignment equivalente, como anti-patrón documentado.
2. Escribir un **walkthrough** del "plan mental" (qué recursos se crearían, en qué orden, qué cambia en el día 1 y en el día 180) y una **comparación en 4 ejes** (rotación, blast radius, auditabilidad, recuperación de incidente).

**Importante**: no hay subscription Azure, no se corre `terraform init` ni `apply`, no se exponen secrets reales. Todos los UUID / tenant IDs son placeholders. El validador no necesita `terraform` instalado.

## 3. Objetivos

Al terminar deberías poder:

- Escribir HCL `azurerm` legible para el patrón MI (user-assigned) → Key Vault con role assignment data-plane.
- Modelar el anti-patrón SP+secret con los mismos recursos equivalentes (Key Vault + role assignment) para que la comparación sea 1:1.
- Argumentar por escrito la jerarquía **MI > OIDC federated > certificate > client secret** y cuándo cada opción es la correcta.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§3 MI, §8 credenciales de SPN).
- Haber recorrido `../../examples/02-managed-identity-vm-to-keyvault/`.
- Herramientas: `bash`. Opcional: `terraform` para `fmt`/`validate` local (**no requerido** por el validador del repo).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-02-misp
cd /tmp/az-02-misp
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los archivos Terraform

Nombres **exactos** (el validador los busca):

1. `main.tf` — escenario **recomendado** (MI).
2. `main-antipattern.tf` — escenario **anti-patrón** (SPN + secret).
3. `variables.tf` — variables compartidas (al menos `location` con default `westeurope`).

#### Requisitos — `main.tf` (MI, recomendado)

- Bloque `terraform { required_providers { azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" } } }`.
- Bloque `provider "azurerm" { features {} }`.
- Al menos **estos recursos** (nombres de recurso Terraform libres, pero tipos exactos):
  - `azurerm_resource_group` para el RG.
  - `azurerm_user_assigned_identity` para la MI.
  - `azurerm_key_vault` con `enable_rbac_authorization = true`.
  - `azurerm_role_assignment` con `role_definition_name = "Key Vault Secrets User"` y `principal_id = azurerm_user_assigned_identity.<name>.principal_id`.
  - `azurerm_linux_virtual_machine` con bloque `identity { type = "UserAssigned"; identity_ids = [azurerm_user_assigned_identity.<name>.id] }`.
- **No** debe contener ningún `azurerm_service_principal_password`, `azurerm_application_password`, `client_secret`, `password` ni `pwd`.
- Comentarios en español describiendo el flujo IMDS → token → Key Vault.

#### Requisitos — `main-antipattern.tf` (SPN+secret, documentado como anti-patrón)

- Bloque `azurerm_application` (o `azuread_application`).
- Bloque `azurerm_service_principal` (o `azuread_service_principal`).
- Bloque `azurerm_service_principal_password` **o** `azuread_service_principal_password` **o** `azuread_application_password` — para modelar el client secret.
- `azurerm_role_assignment` dando `Key Vault Secrets User` al `object_id`/`principal_id` del SPN sobre el mismo vault.
- Un comentario de bloque **destacado** en el encabezado del archivo marcándolo como anti-patrón, mencionando "ANTI-PATTERN" o "ANTIPATRON" en mayúsculas y explicando por qué no se usa en producción.

#### Requisitos — `variables.tf`

- Al menos la variable `location` con `type = string` y `default = "westeurope"` (o cualquier `eu-*`).
- No debe contener secrets reales ni UUIDs reales de tenant/subscription.

### 5.3 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca, con tolerancia a mayúsculas/acentos):

- `## Escenario recomendado (Managed Identity)` — walkthrough paso a paso del plan: qué recursos se crean, en qué orden, qué pasa el día 1 y el día 180.
- `## Antipatron (Service Principal con secret)` — walkthrough del plan equivalente destacando los pasos *extra* (crear app, generar password, almacenar en vault secundario / env var, planear rotación).
- `## Comparacion` — tabla o lista comparando **ambos escenarios en 4 ejes**: rotación de credenciales, blast radius de un leak, auditabilidad, recuperación tras incidente. Debe mencionar literalmente los 4 ejes.
- `## Jerarquia de credenciales` — párrafo justificando `MI > OIDC federated > certificate > client secret` y cuándo elegir cada una.
- Mención explícita de **Managed Identity**, **Service Principal**, **Key Vault** e **IMDS**.
- Nota explícita de que **no se ha aplicado nada** y de que los IDs son placeholders.

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.4 Entregables

```
/tmp/az-02-misp/
├── main.tf
├── main-antipattern.tf
├── variables.tf
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 archivos HCL existen y son legibles.
- El validador pasa en verde (ver §8).
- Un revisor puede leer `README-INTENT.md` y entender por qué MI gana en los 4 ejes.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud sintáctica (ligera)**: los archivos contienen los bloques esperados; no se requiere `terraform validate`.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/`.
- **Seguridad**: ningún secret, UUID real o tenant id en los archivos commiteados.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-02-misp
```

El validador comprueba presencia de bloques HCL por grep (`azurerm_user_assigned_identity`, `azurerm_role_assignment`, `azurerm_linux_virtual_machine`, `enable_rbac_authorization`, etc.), ausencia de secrets/UUID reales, y secciones del README. **No** llama a `terraform init`, **no** necesita credenciales Azure y **no** aplica nada.

## 9. Preguntas de reflexión

1. ¿Qué cambia en la rotación operativa entre MI y SPN+secret cada 6 meses?
2. Si el secret del SPN se filtra en un `.bashrc` compartido, ¿cómo lo detectas y cuánto tardas en revocarlo? ¿Y con MI?
3. ¿Por qué un SPN con **certificate** sigue siendo peor que una MI aunque elimine el string?
4. ¿En qué caso **sí** necesitas un SPN y la MI no te sirve? (pista: workload fuera de Azure).
5. Si tu CI/CD vive en GitHub Actions, ¿por qué OIDC Federation gana sobre un SPN con secret guardado como `AZURE_CLIENT_SECRET`?

## 10. Extensiones

- Añade `main-oidc.tf` modelando el patrón OIDC Federation (SPN + `azurerm_federated_identity_credential`) para GitHub Actions.
- Añade al walkthrough un diagrama (ASCII en code fence) comparando el flujo de token MI vs el flujo de login SPN+secret.
- Enumera en `README-INTENT.md` las métricas que un equipo de SRE puede trackear para demostrar la mejora tras la migración.

## 11. Limpieza

```bash
rm -rf /tmp/az-02-misp
```

No hay infraestructura que detener.
