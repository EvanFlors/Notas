# tf-09-01 — Renombrar un recurso con `moved {}` sin recrear

## 1. Identificación

- **ID:** `tf-09-01-rename-resource-with-moved`
- **Tecnología:** terraform
- **Módulo:** `09-providers-deep-and-lifecycle`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Un refactor típico: alguien eligió un nombre feo para un recurso y querés renombrarlo. En un stack real (una DB, un bucket con datos) un `destroy + create` es catástrofe. Esta actividad te lleva por:

1. **Reproducir el problema**: cambiar el nombre en HCL y ver el `destroy + create` en el plan.
2. **Aplicar la solución**: agregar un `moved {}` block y verificar que el plan quede en `No changes.`
3. **Verificar la realidad**: el archivo del disco mantiene su contenido e inode original.

Usamos `local_file` como recurso didáctico; el patrón se traslada 1:1 a `aws_db_instance`, `aws_s3_bucket`, `google_sql_database_instance`, etc.

## 3. Objetivos

Al terminar deberías poder:

- Reproducir un rename naïve y leer el plan destructivo que produce.
- Escribir un bloque `moved {}` que convierte ese plan en `No changes.`
- Explicar la diferencia con `terraform state mv`.

## 4. Prerrequisitos

- Terraform **≥ 1.5** o OpenTofu **≥ 1.6** instalado. Verifica con `terraform version` o `tofu version` (el validador acepta cualquiera).
- Permiso de escritura en `/tmp/`.
- `bash` ≥ 4.
- Sin costo: solo providers didácticos (`local`, `random`).

## 5. Instrucciones

### Paso 0 — preparar el directorio de trabajo

Trabaja en `/tmp/tf-09-01/`:

```bash
rm -rf /tmp/tf-09-01
mkdir -p /tmp/tf-09-01
cp -R "$(pwd)/starter/." /tmp/tf-09-01/
cd /tmp/tf-09-01
```

(Si corres el validador desde la raíz del repo, usa la ruta absoluta al `starter/`.)

### Paso 1 — apply inicial del starter

El starter contiene un `main.tf` con un recurso llamado `local_file.old_name` apuntando a `/tmp/tf-09-01/greeting.txt`.

```bash
terraform init
terraform apply -auto-approve
terraform state list
#   local_file.old_name
```

Verifica que el archivo existe:

```bash
cat /tmp/tf-09-01/greeting.txt
#   hola desde tf-09-01
```

### Paso 2 — reproducir el rename NAÏVE (observación)

Edita `main.tf` y **cambia el nombre del recurso** de `old_name` a `new_name`:

```hcl
resource "local_file" "new_name" {
  filename = "/tmp/tf-09-01/greeting.txt"
  content  = "hola desde tf-09-01\n"
}
```

Corré **solo plan**, sin apply:

```bash
terraform plan
```

Verás `1 to add, 1 to destroy.` Ese es el problema.

### Paso 3 — agregar el bloque `moved {}`

En el **mismo `main.tf`**, agregá al final:

```hcl
moved {
  from = local_file.old_name
  to   = local_file.new_name
}
```

Corré plan de nuevo:

```bash
terraform plan
```

Debe decir `No changes.` o `0 to add, 0 to change, 0 to destroy.`

Aplicá:

```bash
terraform apply -auto-approve
terraform state list
#   local_file.new_name
```

### Paso 4 — validar

Desde el directorio de la actividad:

```bash
bash tests/validate.sh
```

Debe imprimir `RESULT: PASS`.

El validador comprueba:

1. Que `/tmp/tf-09-01/` contiene un stack con state inicializado.
2. Que el state tiene **solo** `local_file.new_name` (no `old_name`).
3. Que `main.tf` contiene un bloque `moved` con `from = local_file.old_name` y `to = local_file.new_name`.
4. Que `terraform plan -detailed-exitcode` sale con **exit 0** (= sin cambios).
5. Que el archivo `/tmp/tf-09-01/greeting.txt` existe con el contenido esperado.

## 6. Resultado esperado

- `terraform state list` muestra `local_file.new_name`.
- `terraform plan` dice `No changes.`
- `main.tf` tiene el bloque `moved`.
- `bash tests/validate.sh` → `RESULT: PASS`.

## 7. Criterios de aceptación

- No se destruyó ni recreó el recurso: el `apply` del Paso 3 muestra `0 destroyed`.
- El bloque `moved` está presente y correcto.
- El archivo del disco no se tocó entre Paso 1 y Paso 3 (opcional: comparar `stat -c '%i' /tmp/tf-09-01/greeting.txt` antes y después — mismo inode).

## 8. Validación

```bash
bash courses/terraform/09-providers-deep-and-lifecycle/activities/01-rename-resource-with-moved/tests/validate.sh
```

Si prefieres apuntar a otro directorio de trabajo:

```bash
BASE_DIR=/tmp/tf-09-01 bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué diferencia hay entre tu solución y hacer `terraform state mv local_file.old_name local_file.new_name`? ¿Cuál queda en Git?
2. Si el equipo tiene tres backends (dev/stg/prod), ¿cuándo podés borrar el bloque `moved` del código?
3. ¿Qué pasaría si pusieras el bloque `moved` **sin** renombrar el `resource` (es decir, dejas `local_file.old_name` en el HCL)?
4. ¿`moved` sirve también para mover un recurso **entre módulos**? Dá un ejemplo de `from` / `to`.

## 10. Extensiones

- Convertí `local_file.new_name` a `for_each` sobre un `map(string)` y usá un `moved` con `to = local_file.new_name["main"]` para no recrearlo.
- Movelo a un **módulo local**: `module.files.local_file.greeting`, con el `moved` correspondiente.

## 11. Limpieza

```bash
cd /tmp/tf-09-01 && terraform destroy -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-09-01
```
