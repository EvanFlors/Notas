# Solution — stack partido en 3 ambientes

Esta es una referencia. Intenta la actividad primero por tu cuenta.

## Layout

```
solution/
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/  { versions.tf, main.tf, terraform.tfvars }
    ├── stg/  { versions.tf, main.tf, terraform.tfvars }
    └── prod/ { versions.tf, main.tf, terraform.tfvars }
```

## Decisiones

- Sin `terraform.workspace`, sin `var.environment == "prod"` dentro del módulo. El ambiente es un **dato** (`var.environment`) usado sólo para naming/tagging.
- Cada `envs/<X>/versions.tf` declara `backend "local"` apuntando a `terraform.tfstate` **en el propio directorio**. En producción, cada uno apuntaría a un backend remoto distinto (bucket/key/credenciales distintos).
- La promoción cruzada entre ambientes se haría versionando el módulo. Aquí usamos `source = "../../modules/app"` para no complicar la actividad — ver pregunta de reflexión #3.

## Correr

```bash
cp -R solution/. /tmp/tf-08-01-solution/
cd /tmp/tf-08-01-solution
for env in dev stg prod; do
  (cd envs/$env && terraform init && terraform apply -auto-approve)
done
bash .../tests/validate.sh /tmp/tf-08-01-solution
```
