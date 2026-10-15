# Actividad 01 — Renombrar un recurso con `terraform state mv`

## 1. Identificación

- **ID:** `tf-05-01-rename-resource-with-state-mv`
- **Tecnología:** `terraform`
- **Módulo:** `tf-05-state-basics`
- **Dificultad:** beginner
- **Duración estimada:** 30–40 min
- **Tipo:** guided-lab

## 2. Contexto

Un refactor tan trivial como "quiero que este recurso se llame distinto" puede, mal hecho, destruir y recrear un recurso. En `random_pet` es inocuo; en una instancia EC2, una DB RDS o una EIP reservada es un incidente. La operación correcta separa el **cambio de nombre lógico** (en HCL) del **cambio de nombre en el state** (`terraform state mv`). Esta actividad te hace pasar por ambas: primero *verás* el plan destructivo que produce el renombre ingenuo, luego aplicarás `state mv` y comprobarás que el plan queda en no-op.

## 3. Objetivos

Al terminar deberías poder:

- Reproducir el plan destructivo que resulta de renombrar un recurso **sin** tocar el state.
- Ejecutar `terraform state mv <from> <to>` correctamente.
- Verificar con `terraform plan` que el stack queda en no-op tras el renombre.
- Explicar en 2 frases por qué `state mv` es necesario y qué pasaría sin él en un recurso de producción.

## 4. Prerrequisitos

- Terraform ≥ 1.5 (`terraform version`).
- Shell Bash.
- `/tmp/` escribible.
- Ningún provider cloud, ninguna credencial. Sin coste.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
WORK=/tmp/tf-05-01-rename
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R starter/. "$WORK/"
cd "$WORK"
```

Debes tener: `main.tf`, `versions.tf` y un `README.md` local.

### 5.2 Primer apply

Aprovisiona el stack **antes** de refactorizar nada:

```bash
terraform init
terraform apply -auto-approve

terraform state list
# random_pet.old_name
# local_file.greeting_file
```

Anota el valor actual:

```bash
terraform state show random_pet.old_name | grep '^    id'
# por ejemplo:  id        = "funny-rabbit"
```

Ese `id` es el nombre aleatorio generado. Objetivo del ejercicio: **conservarlo** tras el renombre.

### 5.3 Reproducir (y descartar) el renombre ingenuo

Edita `main.tf` y cambia `random_pet "old_name"` por `random_pet "new_name"`. Deja intacto el resto. Guarda.

Corre `terraform plan`:

```bash
terraform plan
```

Verás algo así:

```
Plan: 1 to add, 1 to change, 1 to destroy.
```

Terraform propone **destruir** `random_pet.old_name` y **crear** `random_pet.new_name`. En este caso el `local_file.greeting_file` también cambia (porque referencia el id del pet, que se regeneraría). **No apliques este plan.**

### 5.4 Hacer el renombre correctamente

```bash
terraform state mv random_pet.old_name random_pet.new_name
# Move "random_pet.old_name" to "random_pet.new_name"
# Successfully moved 1 object(s).
```

Verifica:

```bash
terraform state list
# random_pet.new_name
# local_file.greeting_file

terraform state show random_pet.new_name | grep '^    id'
# el MISMO id que antes
```

### 5.5 Validar el no-op

```bash
terraform plan
# No changes. Your infrastructure matches the configuration.
```

Si ves ese mensaje, has conseguido el refactor sin recrear nada.

### 5.6 Ejecutar la validación automática

Desde el directorio de la actividad (no desde `$WORK`):

```bash
bash tests/validate.sh /tmp/tf-05-01-rename
```

Debe terminar con `OK: rename completed cleanly`.

### 5.7 Responder las preguntas de reflexión

Escribe tus respuestas en `$WORK/REFLECTION.md`. No es evaluado por el validador — es para ti.

## 6. Resultado esperado

- `terraform state list` lista `random_pet.new_name` (y **no** `random_pet.old_name`).
- `terraform plan` imprime `No changes.`.
- El `id` del `random_pet` se conserva idéntico al que había antes del refactor.
- `tests/validate.sh` pasa con `OK`.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: `plan` en no-op; address renombrada; `id` preservado.
- [ ] **Calidad**: HCL formateado (`terraform fmt`).
- [ ] **Seguridad**: ningún `.tfstate` dejado en el repo (solo en `/tmp/`).
- [ ] **Reproducibilidad**: cualquier colega puede re-ejecutar los mismos pasos y obtener el mismo resultado.
- [ ] **Mantenibilidad**: podrías explicarlo en 2 minutos a un junior.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-05-01-rename
```

El script verifica, en el directorio `$WORK`:

1. Existe un state file.
2. El state contiene `random_pet.new_name`.
3. El state **no** contiene `random_pet.old_name`.
4. `terraform plan` termina en "No changes".
5. El HCL referencia `random_pet.new_name` (y no `old_name`).

Para la verificación manual del no-op: `terraform plan -detailed-exitcode` devuelve `0` cuando no hay cambios, `2` cuando los hay. Lo usamos en el validador.

## 9. Preguntas de reflexión

Responde en `$WORK/REFLECTION.md`:

1. ¿Qué atributo específico de un `random_pet` se perdería si hubieses aplicado el plan destructivo?
2. En términos del state: ¿qué cambia `terraform state mv` exactamente? ¿Qué **no** cambia?
3. ¿Qué equivalente **declarativo** existe (desde Terraform 1.1) y por qué suele preferirse en equipo? (Pista: bloque `moved`.)
4. Imagina que `random_pet` fuera una base de datos de prod con 500 GB. ¿Qué pasos añadirías antes de hacer el renombre?
5. Si tienes 20 recursos a renombrar en un refactor grande, ¿`state mv` manual o bloques `moved` en el HCL? Argumenta.

## 10. Extensiones (opcional)

- **E1** — Reemplaza `terraform state mv` por un bloque `moved {}` en el HCL. Verifica que `terraform plan` detecta el renombre y lo aplica como no-op. (Luego puedes borrar el bloque `moved` cuando ya nadie opere con el nombre viejo.)
- **E2** — Añade un segundo `random_pet` llamado `random_pet.secondary` y practica mover **dos** recursos en una sesión.
- **E3** — Rompe el state a propósito: haz `terraform state rm random_pet.new_name` y luego usa `terraform import random_pet.new_name <id>` para re-adoptarlo. Verifica que el `plan` queda en no-op.

## 11. Limpieza

```bash
cd "$WORK"
terraform destroy -auto-approve
cd /
rm -rf /tmp/tf-05-01-rename
```
