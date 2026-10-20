# Starter — tf-05-01

Copia este directorio a `/tmp/tf-05-01-rename/` y trabaja ahí:

```bash
WORK=/tmp/tf-05-01-rename
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R . "$WORK/"
cd "$WORK"
```

Pasos (ver README de la actividad para contexto):

```bash
terraform init
terraform apply -auto-approve

# Editar main.tf: random_pet "old_name" -> random_pet "new_name"
# y actualizar la referencia dentro de local_file.greeting_file.

terraform state mv random_pet.old_name random_pet.new_name

terraform plan        # debe decir: No changes.
```

Luego valida con `bash tests/validate.sh /tmp/tf-05-01-rename` desde el directorio de la actividad.
