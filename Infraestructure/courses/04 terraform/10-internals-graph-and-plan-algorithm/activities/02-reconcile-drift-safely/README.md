# tf-10-02 — Reconciliar drift con `-refresh-only` (independiente)

## 1. Identificación

- **ID:** `tf-10-02-reconcile-drift-safely`
- **Tecnología:** terraform
- **Módulo:** `10-internals-graph-and-plan-algorithm`
- **Dificultad:** advanced
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

En producción, alguien edita un recurso **fuera** de Terraform. Puede haber sido un hotfix legítimo o un error humano. Ejecutar `terraform apply` sin pensar sobrescribe esa edición: a veces es correcto (revertir), a veces no (deshacer un hotfix sin pedir permiso).

`terraform plan -refresh-only` es la herramienta para **ver** el drift sin **actuar** sobre él todavía. Separa dos decisiones que un `plan`/`apply` normal mezcla: "¿qué cambió en la realidad?" y "¿qué quiero hacer con eso?".

En esta actividad tú provocas el drift, lo observas con `-refresh-only`, decides por escrito, y aplicas el camino que elegiste.

## 3. Objetivos

- Provocar drift externo intencionadamente sobre un `local_file`.
- Usar `terraform plan -refresh-only -out=…` para observar sin aplicar.
- Decidir **y justificar por escrito** si aceptar el drift (actualizar state) o revertir (pisar la realidad con la config).
- Ejecutar el camino elegido y verificar que el estado final coincide.

## 4. Prerrequisitos

- Terraform ≥ 1.5.
- `bash`.
- Sin costo.

## 5. Instrucciones

### 5.1 Montar el stack

```bash
mkdir -p /tmp/tf-10-02 && cd /tmp/tf-10-02

cp -r <RUTA_DEL_REPO>/courses/terraform/10-internals-graph-and-plan-algorithm/activities/02-reconcile-drift-safely/starter/. .

terraform init
terraform apply -auto-approve
cat note.txt
```

### 5.2 Provocar drift

Edita el archivo gestionado por Terraform **sin** pasar por Terraform:

```bash
echo "hotfix: parche manual del 2026-10-15" > note.txt
cat note.txt
```

### 5.3 Observar con `-refresh-only`

```bash
terraform plan -refresh-only -out=refresh.tfplan
```

Lee el output. Verás que el provider `local` **no reporta** el drift como "cambio de content"; lo reporta como "el recurso ya no existe", porque `local_file` identifica al recurso por el hash del content que *él* escribió. Cuando el content en disco difiere, considera que su recurso fue reemplazado. Es una peculiaridad didáctica útil: ilustra que **cada provider decide cómo interpretar la realidad post-refresh**.

Consecuencia práctica: `apply refresh.tfplan` eliminará `local_file.note` del state (no borra el archivo).

### 5.4 Decidir y justificar

Crea `/tmp/tf-10-02/decision.md` con **una** de las dos decisiones y su justificación. La estructura obligatoria:

```markdown
# Decisión

## Camino elegido
accept | revert

## Justificación (3-5 frases)

## Resultado esperado del state tras aplicar
```

### 5.5 Ejecutar el camino

- Si elegiste **accept** (adoptar la realidad, dejar de gestionar el archivo con TF):

  ```bash
  terraform apply refresh.tfplan   # state pierde a local_file.note
  # con `local_file`, "aceptar" implica también dejar de declararlo en HCL
  # (o re-adoptarlo con terraform import; aquí vamos por el camino simple).
  # Edita main.tf a mano y borra el bloque `resource "local_file" "note" {...}`.
  # Luego:
  terraform plan   # No changes.
  cat note.txt     # el content "hotfix..." sigue en disco, ya no gestionado
  ```

  Nota didáctica: en providers "normales" (p. ej. AWS tags), accept + alinear
  config a la nueva realidad bastaría; con `local_file`, al identificar al
  recurso por hash, el camino limpio es sacarlo de la config (o importarlo
  con `terraform import` tras ajustar el content en HCL).

- Si elegiste **revert**:

  ```bash
  rm refresh.tfplan
  terraform apply -auto-approve
  terraform plan   # debería ser "No changes."
  cat note.txt     # vuelve al content de la config
  ```

### 5.6 Validar

```bash
bash courses/terraform/10-internals-graph-and-plan-algorithm/activities/02-reconcile-drift-safely/tests/validate.sh
```

El validador acepta cualquiera de los dos caminos **siempre que** la decisión escrita en `decision.md` coincida con el estado final en disco y en el state.

## 6. Resultado esperado

- `terraform plan` final imprime `No changes.`
- `/tmp/tf-10-02/decision.md` existe, declara el camino elegido, y lo justifica.
- El contenido de `note.txt` es coherente con el camino declarado.

## 7. Criterios de aceptación

- El camino declarado en `decision.md` es exactamente `accept` o `revert`.
- `note.txt` coincide con el camino declarado:
  - `accept` → `note.txt` contiene "hotfix" (lo editado a mano) **y** `local_file.note` ya no aparece en `main.tf`.
  - `revert` → `note.txt` contiene el content original de la config **y** `local_file.note` sigue en `main.tf`.
- `terraform plan -detailed-exitcode` sale 0 (sin cambios).

## 8. Validación

```bash
bash courses/terraform/10-internals-graph-and-plan-algorithm/activities/02-reconcile-drift-safely/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `-refresh-only` necesita `-out` + `apply` para que el cambio del state persista en disco?
2. Si un `-refresh-only` muestra drift en 50 recursos a la vez, ¿cuál es un workflow sensato? ¿Aceptas todo? ¿Caso por caso?
3. ¿Qué pasaría si combinas `-refresh-only` con `-target=...`?
4. ¿Cómo diseñarías un cron diario que detecte drift y publique un reporte, sin aplicar nada?

## 10. Extensiones

- Cambia el stack para que `local_file.note` tenga `lifecycle { ignore_changes = [content] }`. Reproduce el drift y mira el plan: ¿qué cambia?
- Añade un segundo recurso dependiente del primero y observa cómo refresh afecta solo a lo que leyó.

## 11. Limpieza

```bash
cd /tmp/tf-10-02 && terraform destroy -auto-approve 2>/dev/null || true
cd / && rm -rf /tmp/tf-10-02
```
