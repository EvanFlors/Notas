# tf-09-02 — Adoptar un recurso existente con `import {}` blocks

## 1. Identificación

- **ID:** `tf-09-02-import-block-vs-cli`
- **Tecnología:** terraform
- **Módulo:** `09-providers-deep-and-lifecycle`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Un recurso existe en el "mundo real" (fue creado por fuera de Terraform, por un script, por alguien en la consola, por un provisionador legacy). Lo querés **adoptar** en tu stack: que entre al state **sin ser recreado**, y que quede escrito en HCL de forma versionada.

Hay dos caminos:

1. **Camino viejo**: `terraform import <addr> <id>` desde la CLI. Procedural, no deja huella en el código.
2. **Camino moderno (TF ≥ 1.5)**: bloque `import {}` en HCL. Queda en Git. Revisable en PR.

Para que la actividad funcione **sin cloud y sin coste**, usamos `random_id` del provider `hashicorp/random`, uno de los pocos recursos didácticos que **soporta import** nativamente (el provider `local_file` no lo soporta). El escenario simulado: otro sistema (otro equipo, un script, un servicio de generación de identificadores) produjo un identificador base64 que ahora queremos **traer al state** para gestionar su rotación desde Terraform.

Esta actividad es **independiente**: tenés el contexto y los criterios, no te damos la solución. Resolvela con `import {}` blocks.

## 3. Objetivos

Al terminar deberías poder:

- Simular un "identificador producido fuera de Terraform" (el starter da el valor exacto).
- Escribir un bloque `import {}` para adoptarlo en un `resource "random_id" "adopted"`.
- Verificar que `terraform plan` dice `will be imported` y no `will be created`.
- Verificar que `terraform state list` lo contiene tras el `apply`.
- Justificar por qué `import {}` block es preferible al comando CLI en un repo con varios ingenieros.

## 4. Prerrequisitos

- Terraform **≥ 1.5** o OpenTofu **≥ 1.6**. Verificá con `terraform version` o `tofu version`.
- Permiso de escritura en `/tmp/`.
- `bash` ≥ 4.
- Sin costo.

## 5. Instrucciones

### Paso 0 — preparar el directorio de trabajo

El starter incluye:

- `bootstrap.sh` — un script que imprime el **identificador pre-existente** (una cadena base64, 6 caracteres = 4 bytes). Es lo que te daría otro sistema en la vida real cuando pedís "cuál es el ID que ya está en producción".
- `main.tf` — stack vacío (solo bloque `terraform { ... }`).

```bash
rm -rf /tmp/tf-09-02
mkdir -p /tmp/tf-09-02
cp -R "$(pwd)/starter/." /tmp/tf-09-02/
cd /tmp/tf-09-02

bash bootstrap.sh
# Imprime algo como:
#   Pre-existing random_id (base64url, 4 bytes): AAAAAA
#   Use this exact id in your import block.
```

El ID a adoptar es **`AAAAAA`** (fijo y conocido, para que el validador funcione reproduciblemente).

### Paso 1 — intento NAÏVE (observación, no se queda)

Si simplemente agregaras:

```hcl
resource "random_id" "adopted" {
  byte_length = 4
}
```

y aplicaras, Terraform **generaría otro ID random** diferente del que ya existe en producción. Perderías la trazabilidad con el "mundo real". **No lo hagas**; es solo para entender el problema.

### Paso 2 — adoptar con `import {}`

Tu tarea:

1. En `main.tf`, declarar:
   ```hcl
   resource "random_id" "adopted" {
     byte_length = 4
   }
   ```
2. Agregar, al mismo nivel que el `resource`, un bloque:
   ```hcl
   import {
     to = random_id.adopted
     id = "AAAAAA"
   }
   ```
3. `terraform init`
4. `terraform plan` — debe decir algo como `random_id.adopted will be imported`, **no** `will be created`.
5. `terraform apply -auto-approve`
6. `terraform state list` debe mostrar `random_id.adopted`.
7. `terraform plan` posterior debe ser `No changes.`

### Paso 3 — validar

```bash
bash tests/validate.sh
```

Debe imprimir `RESULT: PASS`.

El validador comprueba:

1. Terraform/OpenTofu disponible, versión ≥ 1.5 / ≥ 1.6.
2. `main.tf` existe en el directorio de trabajo.
3. `main.tf` contiene un bloque `import {}` con `to = random_id.adopted` e `id = "AAAAAA"`.
4. `main.tf` declara el `resource "random_id" "adopted"`.
5. `terraform state list` contiene `random_id.adopted`.
6. `terraform plan -detailed-exitcode` sale con **exit 0** (ya no hay cambios).

## 6. Resultado esperado

- El state de Terraform **adopta** el ID `AAAAAA` tal cual (sin generar uno nuevo).
- `terraform state list` contiene `random_id.adopted`.
- `terraform plan` dice `No changes.`
- `main.tf` tiene un bloque `import {}` versionable.

## 7. Criterios de aceptación

- La adopción se hizo con `import {}` block (NO con `terraform import` CLI). El validador exige el bloque en el archivo.
- `byte_length = 4` del recurso coincide con el tamaño del `id` importado (`AAAAAA` base64url = 4 bytes).
- No queda `destroy` ni `create` pendiente.

## 8. Validación

```bash
bash courses/terraform/09-providers-deep-and-lifecycle/activities/02-import-block-vs-cli/tests/validate.sh
```

O con directorio custom:

```bash
BASE_DIR=/tmp/tf-09-02 bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si pusieras un `byte_length` distinto en el `resource`, ¿qué diría el **próximo** plan? ¿Por qué?
2. ¿Qué información necesitarías darle a `import {}` para un `aws_s3_bucket`? ¿Y para un `aws_iam_role`? (Pista: cada provider documenta el `id` que acepta su `import`.)
3. ¿Cuándo podrías borrar el bloque `import` del código?
4. Si en lugar de un ID fuera una base de datos de producción, ¿qué agregarías al `resource` adoptado inmediatamente después del import para evitar sustos? (Pista: ver lección sección 3.)
5. ¿Qué ventaja operacional concreta tiene `import {}` block sobre el comando `terraform import` para un equipo con 10 ingenieros y tres environments?

## 10. Extensiones

- Agregá `lifecycle { prevent_destroy = true }` al recurso adoptado y verificá que un `terraform destroy` falla.
- Investigá qué dice `terraform plan -generate-config-out=generated.tf` cuando el `resource` todavía no está declarado y solo tenés el bloque `import`.
- Adoptá un segundo `random_id` con otro ID conocido en el mismo stack.

## 11. Limpieza

```bash
cd /tmp/tf-09-02 && terraform destroy -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-09-02
```
