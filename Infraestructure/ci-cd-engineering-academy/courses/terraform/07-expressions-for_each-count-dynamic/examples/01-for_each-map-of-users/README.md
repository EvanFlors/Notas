# Ejemplo 01 — `for_each` sobre un map de usuarios

Un `local_file` por usuario, con claves estables (nombre). Al añadir, quitar o reordenar usuarios en el map, el plan solo refleja el cambio real.

## Archivos

- `main.tf` — el stack.
- `variables.tf` — tipo del input.
- `terraform.tfvars` — datos.

## Cómo correrlo

```bash
cd examples/01-for_each-map-of-users
terraform init
terraform apply -auto-approve
ls out/
# alice.txt  bob.txt  carol.txt
```

## Experimentos sugeridos

1. Edita `terraform.tfvars` y elimina a `bob`. Corre `terraform plan`. Deberías ver:
   ```
   # local_file.user["bob"] will be destroyed
   ```
   Y nada más. `alice` y `carol` no se tocan.

2. Añade a `dave`. Plan:
   ```
   # local_file.user["dave"] will be created
   ```

3. Reordena las claves del map en el `.tfvars`. Plan: `No changes.` La clave es la identidad, no la posición.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out/
```
