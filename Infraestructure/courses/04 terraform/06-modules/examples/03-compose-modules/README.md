# Ejemplo 03 — Composición de módulos (root ↔ child)

## Concepto que demuestra

Un **root module** compone dos **child modules** locales. El output del primero (`network`) se pasa como input del segundo (`consumer`). Esto crea una dependencia implícita en el grafo: `consumer` no evalúa hasta que `network` haya producido su output.

También demuestra:

- Dos módulos distintos compartiendo el mismo provider (configurado por el root).
- La ausencia de `provider "..." {}` en los child modules.
- Un `terraform state list` que muestra los recursos prefijados por `module.<name>.`.

## Qué simula

Para evitar la nube seguimos con providers didácticos:

- `network`: produce un "VPC" como un archivo `network.json` con un `vpc_id` lógico.
- `consumer`: recibe el `vpc_id` y crea un archivo `app.conf` que lo referencia.

El patrón real es idéntico: el output de `module "vpc"` (p. ej. `vpc_id`) alimenta a `module "eks"`, `module "rds"`, etc.

## Estructura

```
03-compose-modules/
├── README.md
├── modules/
│   ├── network/
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── consumer/
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       └── outputs.tf
└── root/
    ├── versions.tf
    ├── providers.tf
    ├── main.tf
    └── outputs.tf
```

## Ejecución

```bash
cd root
rm -rf .terraform terraform.tfstate* /tmp/tf-06-ex03

terraform init
terraform plan
terraform apply -auto-approve

ls /tmp/tf-06-ex03/

terraform state list
#   module.network.random_id.vpc
#   module.network.local_file.network_json
#   module.consumer.local_file.app_conf

terraform output
```

## Qué mirar en el código

1. `root/main.tf`: `module "consumer" { vpc_id = module.network.vpc_id }` — dependencia implícita.
2. `modules/network/outputs.tf`: expone `vpc_id` como contrato.
3. `modules/consumer/variables.tf`: declara `vpc_id` como input obligatorio (sin `default`).
4. `terraform state list`: cada módulo tiene su **prefijo** en el state (pero el state file es uno solo, del root).

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform terraform.tfstate* /tmp/tf-06-ex03
```

## Preguntas de reflexión

1. Si quitas la referencia `module.network.vpc_id` y le pasas un string hardcoded a `consumer`, ¿Terraform garantiza el orden de creación?
2. ¿Cuántos state files existen tras `apply`? ¿Dónde viven los recursos de ambos módulos?
3. ¿Qué pasa si cambias el `name` de `module "network"` a `module "net"` en el root sin hacer `terraform state mv`? Pista: `tf-09` enseña `moved {}` como la solución limpia.
4. ¿Podrías extraer `consumer` a su propio root module con su propio backend? ¿Qué cambiaría?
