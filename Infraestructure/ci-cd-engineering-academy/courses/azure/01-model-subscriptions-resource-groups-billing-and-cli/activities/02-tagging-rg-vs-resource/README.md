# Actividad 02 — Estrategia de tags: RG vs recurso + Azure Policy sketch

## 1. Identificación

- **ID:** `az-01-02-tagging-rg-vs-resource`
- **Tecnología:** `azure`
- **Módulo:** `az-01-model-subscriptions-resource-groups-billing-and-cli`
- **Dificultad:** beginner
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Security + FinOps te piden definir el **catálogo mínimo de tags** de la startup y escribir una Azure Policy que fuerce al menos **un tag obligatorio** (`env`) sobre nuevos recursos. En Azure, los tags pueden vivir **en el Resource Group** y **en el recurso individual** (ambos útiles, no heredan por defecto). Debes decidir qué va en cada nivel, materializarlo en JSON y documentar la intención.

**Importante**: no hay tenant Azure real. No se despliega nada. El entregable son 3 archivos JSON + 1 README.

## 3. Objetivos

Al terminar deberías poder:

- Nombrar un catálogo mínimo de tags (`env`, `owner`, `cost-center`, `workload`, `managed-by`) con valores canónicos.
- Decidir qué tags viven en el **Resource Group** y cuáles en cada **recurso individual** sin duplicar innecesariamente.
- Escribir JSON válido de los tags de un RG y de un recurso.
- Escribir una **Azure Policy sketch** con `effect` `append` / `modify` / `audit` sobre un tag obligatorio.
- Explicar por qué los tags del RG **no heredan** y cuándo quieres forzarlo con Policy.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§5 y §10).
- Haber recorrido `../../examples/02-rg-delete-cascades/` y `../../examples/03-budget-with-notifications/`.
- Herramientas: `bash`, `jq`, un editor de texto. **Opcional**: `az` CLI (solo `--help`).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-01-tagging
cd /tmp/az-01-tagging
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 3 archivos JSON

Nombres **exactos** (el validador los busca):

1. `tags-rg.json`
2. `tags-resource.json`
3. `tag-policy.json`

#### `tags-rg.json`

Un objeto JSON plano con los tags que vivirán en el **Resource Group** `rg-checkout-dev`. Debe contener **al menos** las claves:

- `env` (ejemplo: `"dev"`, `"stg"`, `"prod"`, `"sandbox"`).
- `owner` (ejemplo: `"team-checkout"` o email).
- `cost-center` (ejemplo: `"CC-1234"`).
- `workload` (ejemplo: `"checkout"`).
- `managed-by` (ejemplo: `"terraform"`, `"azd"`, `"manual"`).

Ejemplo mínimo:

```json
{
  "env": "dev",
  "owner": "team-checkout",
  "cost-center": "CC-1234",
  "workload": "checkout",
  "managed-by": "terraform"
}
```

#### `tags-resource.json`

Los tags que lleva un **recurso individual** dentro del RG — por ejemplo, el Storage Account `stcheckoutdev123`. Debe contener **al menos**:

- `component` (ejemplo: `"blob-storage"`, `"api"`, `"db"`).
- `data-classification` (ejemplo: `"internal"`, `"confidential"`, `"public"`).
- `backup-policy` (ejemplo: `"daily-7d"`, `"none"`).

**Puede** repetir `env`, `owner`, `cost-center`, `workload` si NO vas a confiar en Azure Policy para forzar la herencia; o puede **omitirlos** si asumes que la Policy `modify` del baseline los copiará desde el RG. Documenta tu elección en `README-INTENT.md`.

#### `tag-policy.json`

Un **sketch** de Azure Policy definition JSON (no deployable sin adaptar). Debe contener como mínimo:

- `properties.policyType` o `policyType` igual a `"Custom"`.
- `properties.mode` o `mode` igual a `"Indexed"` o `"All"`.
- `properties.policyRule.if` con una condición sobre `tags['env']` o `concat('tags[','env',']')`.
- `properties.policyRule.then.effect` que sea uno de: `audit`, `append`, `modify`, `deny`.

Ejemplo mínimo (sketch, el validador comprueba las claves clave):

```json
{
  "properties": {
    "displayName": "Require env tag on resources",
    "policyType": "Custom",
    "mode": "Indexed",
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "tags['env']",
        "exists": "false"
      },
      "then": {
        "effect": "audit"
      }
    }
  }
}
```

El JSON debe parsear con `jq .`.

### 5.3 Escribe `README-INTENT.md`

Un documento que explique:

- Para `tags-rg.json`: qué tags lleva y por qué viven en el **RG** (no en cada recurso).
- Para `tags-resource.json`: qué tags lleva y por qué viven en el **recurso** (no en el RG).
- Para `tag-policy.json`: qué `effect` elegiste (`audit` / `append` / `modify` / `deny`), a qué scope la adjuntarías (MG, Subscription, RG), y por qué.
- Un párrafo explícito sobre **herencia**: los tags del RG **no heredan** por defecto en Azure; menciona `Azure Policy` con effect `modify` o `append` como la vía para forzar la copia.

Secciones obligatorias (el validador las busca):

- `## tags-rg`
- `## tags-resource`
- `## tag-policy`
- `## Herencia` (o `## Inheritance` o `## Herencia-tags`).

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.4 Entregables

```
/tmp/az-01-tagging/
├── tags-rg.json
├── tags-resource.json
├── tag-policy.json
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 JSONs parsean con `jq .`.
- `tags-rg.json` contiene las 5 claves mínimas.
- `tags-resource.json` contiene las 3 claves mínimas específicas.
- `tag-policy.json` contiene las claves clave de una Azure Policy sketch.
- `README-INTENT.md` tiene las 4 secciones.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud sintáctica**: JSON válido.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: claves consistentes, lowercase, kebab-case en valores compuestos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-01-tagging
```

El validador comprueba sintaxis JSON y presencia de claves mínimas. **No** aplica la Policy a un tenant real.

## 9. Preguntas de reflexión

1. ¿Por qué `cost-center` conviene al **RG** y `data-classification` al **recurso**?
2. Si Azure Policy `modify` fuerza `env` desde el RG, ¿qué pasa cuando alguien crea un recurso con `env` explícito distinto?
3. ¿Elegirías `deny` sobre `audit` para forzar `env`? ¿Qué pasa con los recursos ya existentes sin tag?
4. ¿Puedes aplicar `append` a un recurso que no tenga un campo `tags` (p. ej. `Microsoft.OperationsManagement/solutions`)?
5. ¿Cómo audita Finance el gasto por `workload=checkout` si no todos los recursos llevan ese tag? ¿Se arregla con Cost Analysis groupBy=`workload`?

## 10. Extensiones

- Añade un cuarto JSON `tag-policy-initiative.json` que agrupe `require-env`, `require-owner` y `require-cost-center` en una **Initiative** (`policySetDefinition`).
- Añade un script `verify-tags.sh` que, dado un JSON, verifique que todas las claves obligatorias estén presentes.
- Documenta en `README-INTENT.md` cómo migrar un RG existente sin tags al baseline (Policy `modify` + remediación).

## 11. Limpieza

```bash
rm -rf /tmp/az-01-tagging
```

No hay infraestructura real que detener.
