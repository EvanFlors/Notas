# tf-10-01 — ¿Por qué se está reemplazando esto? (debug independiente)

## 1. Identificación

- **ID:** `tf-10-01-why-is-this-being-replaced`
- **Tecnología:** terraform
- **Módulo:** `10-internals-graph-and-plan-algorithm`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Alguien en tu equipo abrió un PR con un stack trivial de Terraform. En su CI, cada `plan` propone recrear el mismo recurso **aunque nadie haya tocado nada**. Dice "parece que Terraform está loco". No. Terraform propone exactamente lo que la config le pide; el bug está en la config. Tu trabajo es encontrarlo **con evidencia**, no por inspección visual.

El patrón ("el `null_resource` que se replace solo") es tan común que merece aprender a diagnosticarlo con `terraform show -json` + `jq`. Esa habilidad te servirá para plans mucho más grandes y feos.

Esta actividad es **independent**: no te vamos a decir cuál es el bug. Tú lo encuentras.

## 3. Objetivos

- Reproducir un plan "raro" que propone replace de un recurso en cada corrida.
- Diagnosticar la causa raíz usando `terraform show -json` y `jq` (no por lectura directa del HCL).
- Documentar el diagnóstico con **evidencia extraída del `plan.json`**.
- Aplicar un fix mínimo y verificar que el plan ya no propone cambios.

## 4. Prerrequisitos

- Terraform ≥ 1.5.
- `jq` ≥ 1.6.
- `bash`.
- Sin costo.

## 5. Instrucciones

### 5.1 Reproducir el stack roto

```bash
mkdir -p /tmp/tf-10-01 && cd /tmp/tf-10-01

# Copia el starter desde el repo:
cp -r <RUTA_DEL_REPO>/courses/terraform/10-internals-graph-and-plan-algorithm/activities/01-why-is-this-being-replaced/starter/. .

terraform init
terraform apply -auto-approve
```

### 5.2 Observar el síntoma

Corre `plan` dos o tres veces seguidas:

```bash
terraform plan
terraform plan
```

Verás que **cada** plan propone `replace` del mismo `null_resource`. Esto no debería pasar en un stack estable: significa que algo del input al recurso cambia entre invocaciones.

### 5.3 Diagnosticar con evidencia

**No** leas el HCL todavía. Investiga con el flujo que vale para plans grandes:

```bash
terraform plan -out=plan.out
terraform show -json plan.out > plan.json

# ¿qué recursos cambian?
jq '.resource_changes[] | select(.change.actions != ["no-op"])
   | {address, actions: .change.actions}' plan.json

# ¿qué atributo disparó el replace?
jq '.resource_changes[] | select(.change.actions | contains(["delete"]))
   | {address, replace_paths: .change.replace_paths}' plan.json

# ¿qué contenía before vs after del atributo culpable?
jq '.resource_changes[] | select(.change.actions | contains(["delete"]))
   | {address, before: .change.before, after: .change.after}' plan.json
```

A partir del output: identifica el atributo que cambia entre `before` y `after`. Formula una hipótesis sobre **por qué** cambia (sin mirar el HCL todavía) y después confírmala leyendo la config.

### 5.4 Aplicar el fix

El fix es mínimo (una línea del HCL del starter). Guarda tu versión arreglada en el mismo `/tmp/tf-10-01/main.tf` (sobrescribe el del starter). Reglas:

- No agregues `lifecycle { ignore_changes = ... }` para "silenciar" el síntoma. Eso enmascara el bug.
- No borres el `null_resource` ni el bloque `triggers`.
- El fix debe conservar la **intención** del `triggers`: que el recurso se recree cuando cambia una entrada **relevante**, no en cada run.

Pista estructural: hay funciones de HCL que devuelven algo distinto cada vez que se evalúan. Si una de ellas vive en `triggers`, cada `plan` reevalúa, cada evaluación es distinta → cada plan propone replace.

### 5.5 Verificar

```bash
terraform apply -auto-approve
terraform plan   # debe decir "No changes."
```

### 5.6 Entregable escrito

En `/tmp/tf-10-01/writeup.md`:

```markdown
# Writeup — tf-10-01

## Síntoma observado

## Diagnóstico (con evidencia de plan.json)
- Recurso afectado:
- Atributo culpable:
- before:
- after:
- Causa raíz (en una frase):

## Fix aplicado (diff mínimo del HCL)

## Verificación
```

## 6. Resultado esperado

- `terraform plan` final imprime `No changes.`
- `/tmp/tf-10-01/writeup.md` existe y menciona el recurso afectado, el atributo culpable y la causa raíz.
- Hay un archivo `/tmp/tf-10-01/plan.json` como evidencia del diagnóstico.

## 7. Criterios de aceptación

- El `terraform plan` corrido dos veces seguidas no propone cambios.
- El fix **no** usa `ignore_changes` ni elimina el `triggers`.
- El writeup identifica el atributo culpable **citando `plan.json`**, no solo intuición.

## 8. Validación

```bash
bash courses/terraform/10-internals-graph-and-plan-algorithm/activities/01-why-is-this-being-replaced/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué otras funciones de HCL serían peligrosas en `triggers`? (Pista: todas las no deterministas.)
2. ¿Por qué el provider `null` reportó este atributo como `ForceNew` en vez de `update`?
3. Si quisieras que `triggers` recree el recurso al cambiar un archivo externo, ¿qué función usarías?
4. ¿Cómo lo detectarías *antes* del apply con una policy sobre `plan.json`?

## 10. Extensiones

- Reescribe el `triggers` para que recree el recurso solo cuando cambia el contenido de un archivo (`filemd5(...)` o similar).
- Añade un segundo `null_resource` con `replace_triggered_by = [null_resource.boot]` y observa el cascading en el plan JSON.

## 11. Limpieza

```bash
cd /tmp/tf-10-01 && terraform destroy -auto-approve 2>/dev/null || true
cd / && rm -rf /tmp/tf-10-01
```
