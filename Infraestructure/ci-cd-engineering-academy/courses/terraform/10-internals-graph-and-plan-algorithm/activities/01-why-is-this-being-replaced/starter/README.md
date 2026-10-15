# Starter — tf-10-01

Copia este directorio a `/tmp/tf-10-01/` y sigue el README de la actividad.

```bash
mkdir -p /tmp/tf-10-01 && cp -r ./ /tmp/tf-10-01/
cd /tmp/tf-10-01
terraform init
terraform apply -auto-approve
terraform plan        # <-- síntoma
terraform plan        # <-- vuelve a proponer lo mismo
```

Investiga con `terraform show -json plan.out | jq` antes de leer `main.tf` a fondo.
