# Solución — tf-05-01

El refactor correcto es:

1. **Primero** aplicar el starter tal cual (crea `random_pet.old_name` + `local_file.greeting_file`).
2. Renombrar en el HCL `random_pet "old_name"` → `random_pet "new_name"` **y** su referencia dentro de `local_file.greeting_file`.
3. Reconciliar el state **sin recrear nada**:

   ```bash
   terraform state mv random_pet.old_name random_pet.new_name
   ```

4. Confirmar no-op:

   ```bash
   terraform plan -detailed-exitcode   # debe salir con 0
   ```

Si prefieres el script automatizado:

```bash
bash rename.sh /tmp/tf-05-01-rename
```

Comparar con la solución canónica: `main.tf` de esta carpeta frente al `main.tf` que dejaste en `/tmp/tf-05-01-rename/`.

### Equivalente declarativo (preferido en equipo)

En lugar de `terraform state mv`, Terraform 1.1+ permite registrar el renombre **en el HCL** con un bloque `moved`:

```hcl
moved {
  from = random_pet.old_name
  to   = random_pet.new_name
}

resource "random_pet" "new_name" {
  length    = 2
  separator = "-"
}
```

Al correr `terraform plan`, Terraform ve el bloque `moved`, actualiza el state silenciosamente y reporta no-op. El bloque se puede eliminar del HCL una vez que todos los stacks que compartían el nombre viejo hayan corrido al menos una vez. Esto se profundiza en `tf-09`.
