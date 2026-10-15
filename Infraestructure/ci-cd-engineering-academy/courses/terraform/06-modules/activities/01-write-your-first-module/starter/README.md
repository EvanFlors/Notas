# Starter — tf-06-01

No hay código inicial. Trabaja en `/tmp/tf-06-01/greeting-site/`.

Lee el `README.md` de la actividad y crea tú el árbol de archivos.

El validador espera, dentro de `/tmp/tf-06-01/greeting-site/`:

- `README.md`, `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`.
- `examples/basic/versions.tf`, `examples/basic/providers.tf`, `examples/basic/main.tf`.
- Que `terraform init -input=false` + `terraform validate` en `examples/basic/` salga sin error.
- Al menos una `validation {}` en `variables.tf`.
- Que `variables.tf` **no** omita `description` en ninguna variable, y que `outputs.tf` tampoco.
- Que `main.tf` del módulo **no** contenga la línea `provider "`.

Si Terraform/OpenTofu no está instalado, el validador imprime instrucciones y sale con SKIP.
