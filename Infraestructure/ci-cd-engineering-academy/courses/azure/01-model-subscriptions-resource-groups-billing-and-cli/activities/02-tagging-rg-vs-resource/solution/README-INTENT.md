# REFERENCE — tags-rg vs tags-resource + Azure Policy sketch

> Documento de intención: qué va en cada nivel, por qué, y cómo lo fuerza Azure Policy.

## Resumen

El catálogo mínimo de tags de la startup se divide en **dos niveles**:

| Nivel | Tags | Razón |
|-------|------|-------|
| **Resource Group** | `env`, `owner`, `cost-center`, `workload`, `managed-by`, `lifecycle`, `contact` | Metadata **del ciclo de vida y de la propiedad** del grupo. Vale para todo lo contenido. |
| **Recurso individual** | `component`, `data-classification`, `backup-policy`, `encryption`, `exposure` | Metadata **de este recurso concreto** que no aplica a sus vecinos. |

Azure **no hereda** los tags del RG a los recursos. Para forzar herencia se usa **Azure Policy** con effect `modify` (requiere un rol para remediación) o `append` (más suave: solo añade si no existe).

---

## tags-rg

### Qué lleva

```json
{
  "env": "dev",
  "owner": "team-checkout",
  "cost-center": "CC-1234",
  "workload": "checkout",
  "managed-by": "terraform",
  "lifecycle": "ephemeral",
  "contact": "team-checkout@example.com"
}
```

### Por qué vive en el RG (no en cada recurso)

- `env` y `workload` son **invariantes** por RG: en nuestro patrón "un RG = un ciclo de vida", todos los recursos del RG comparten entorno y workload.
- `owner`, `cost-center`, `contact` responden a **"¿quién paga?"** y **"¿a quién llamo?"** — información del grupo, no del artefacto individual.
- `managed-by` indica el origen (Terraform vs manual vs `azd`); en un RG serio es siempre el mismo.
- `lifecycle` (`ephemeral` / `persistent`) ayuda a scripts de limpieza automática: `az group list --tag lifecycle=ephemeral` + `az group delete`.

Vive **solo** en el RG para evitar deriva: si cada recurso lo repitiera y alguien lo editara individualmente, Finance vería gasto mal atribuido.

---

## tags-resource

### Qué lleva

```json
{
  "component": "blob-storage",
  "data-classification": "internal",
  "backup-policy": "daily-7d",
  "encryption": "cmk",
  "exposure": "private-endpoint-only"
}
```

### Por qué vive en el recurso (no en el RG)

- `component` distingue dentro del RG (`api` vs `db` vs `blob-storage`). Varía por recurso.
- `data-classification` depende del dato que almacena cada recurso: dos Storage Accounts del mismo RG pueden ser `internal` y `confidential`.
- `backup-policy` describe la política de backup aplicada al recurso (Azure Backup u otra); no aplica al RG.
- `encryption` y `exposure` dependen de la configuración real del recurso.

Los tags **del RG se omiten en el recurso** confiando en que la Policy del baseline (`tag-policy.json` con `effect=modify`) los copiará desde el RG. Si por algún motivo la Policy no se despliega, el recurso queda sin `env`/`workload`/`cost-center` — detectable con una query de Cost Analysis o con una Policy `audit` complementaria.

---

## tag-policy

### Qué hace

Audita (o modifica, según parámetro) recursos que no tienen `tags['env']`. En el `defaultValue` del parámetro `effect` arranca como **`audit`** para no romper despliegues existentes; cuando se despliegue la remediation task con el role `Tag Contributor`, se promueve a **`modify`** y la Policy pasa a **copiar el valor desde el RG**:

```json
"operations": [
  { "operation": "addOrReplace", "field": "tags['env']", "value": "[resourcegroup().tags['env']]" }
]
```

### A qué scope se adjunta

A **Management Group** `Sandbox MG` (y, cuando crezca, al MG `Landing Zones`). Herencia por scope → todas las subscriptions descendientes la aplican sin re-asignación.

En entornos pequeños sin MG, se adjunta a la **Subscription** directamente.

### Por qué `audit` → `modify` escalonado

- **`audit`** no bloquea nada; produce entradas de compliance que Finance/Security revisan. Útil en semana 1.
- **`modify`** rellena el tag automáticamente — eficiente, pero requiere que la Policy tenga un principal con permiso `Microsoft.Resources/tags/write` (de ahí `roleDefinitionIds` apuntando a `Tag Contributor`).
- **`append`** es más suave que `modify`: solo añade si falta, sin tocar valor existente ni requerir remediación.
- **`deny`** se evita en Fase 3 — bloquearía despliegues legítimos antes de que los pipelines estén alineados. Se puede escalar a `deny` en Fase 5 una vez el baseline esté estable.

### Qué NO cubre esta Policy

- Otros tags obligatorios (`owner`, `cost-center`): se añaden como **Initiative** (`policySetDefinition`) que agrupa `require-env`, `require-owner`, `require-cost-center`. Ver sección de extensiones del README.
- Validación de **valores** (`env` debe ser uno de `dev|stg|prod|sandbox`): es una Policy adicional con `allowedValues` sobre `tags['env']`.

---

## Herencia

Azure **no propaga** los tags del Resource Group a los recursos dentro de él **por defecto**. Esto es diferente de la intuición habitual (y diferente del comportamiento de algunas features de AWS como Cost Allocation Tags activadas en toda una Organization).

Vías para forzar la herencia:

1. **Azure Policy `modify`** (recomendado): la Policy `tag-policy.json` evalúa recursos en creación/actualización y copia tags desde `resourcegroup().tags['...']`. Requiere Managed Identity con rol `Tag Contributor`.
2. **Azure Policy `append`**: añade el tag si no existe. Más simple (no requiere remediación) pero no reconcilia recursos ya existentes sin tag.
3. **Infra as Code (Terraform / Bicep)** disciplinado: todos los módulos leen una variable `tags` y la aplican a cada recurso. La disciplina es humana; la Policy es automática — se combinan.
4. **`az tag` masivo**: operación puntual de remediación para recursos legacy sin tag; no sustituye a la Policy.

> **Pie en la trampa**: pensar que un `az group create --tags env=dev ...` seguido de `az storage account create ...` dejará el Storage Account con `env=dev`. **No es así**: el Storage Account arranca sin tags. Lo arregla la Policy, no la jerarquía.

---

## Rollout recomendado

1. Fase 3 (ahora): escribir Policy en `audit`, revisar violations durante 7 días.
2. Fase 4: desplegar remediation (Managed Identity + role assignment `Tag Contributor` en el scope de la Policy).
3. Fase 4+1 semana: promover `effect` a `modify`. Ejecutar `remediation task` sobre el inventario existente.
4. Fase 5: evaluar escalar a `deny` para nuevos recursos; mantener `modify` para los existentes.
