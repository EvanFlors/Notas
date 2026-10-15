# Ejemplo 02 — Consumir un módulo del Registry (`terraform-aws-modules/vpc/aws`)

## Concepto que demuestra

Cómo **consumir** un módulo público del Terraform Registry: pin de versión, inputs documentados, outputs usados por el root, y qué pide `init` por debajo. Es un **walkthrough de lectura** — no se corre `apply` (requiere credenciales AWS reales y crea recursos de pago).

## Contexto

`terraform-aws-modules/vpc/aws` es uno de los módulos comunitarios más maduros del ecosistema. Lo mantenemos como referencia porque:

- Está mantenido activamente.
- Pinnea sus providers.
- Tiene docs completas (inputs/outputs tabulados).
- Tiene tests (`examples/`, `terraform test`).
- Respeta SemVer (los breaking changes van a majors).

Es un buen caso para ilustrar los criterios de **evaluación** que verás en la sección 11 de la lección y aplicarás en `activities/02`.

## Estructura

```
02-registry-module-vpc/
├── README.md           (este archivo)
├── versions.tf         (required_providers con aws pin)
├── providers.tf        (configuración del provider aws)
├── main.tf             (module "vpc" con source + version)
└── outputs.tf          (outputs del root tomados del módulo)
```

> No incluimos un `terraform.tfvars` porque este ejemplo no debería ejecutarse por default: `apply` crearía recursos AWS reales (VPC, subnets, NAT GW) con **costo**. Para probar `terraform init` sin tocar la nube, sigue abajo.

## Qué pedir y qué no

### Lo que puedes hacer sin cuenta AWS

```bash
cd /path/to/02-registry-module-vpc
rm -rf .terraform .terraform.lock.hcl

terraform init
#   Baja el módulo del Registry a .terraform/modules/vpc/.
#   Baja el provider aws (lo pin del root).
#   Si NO hay internet: falla con un error de red; es esperable, SKIP.

terraform fmt -check
terraform validate
#   validate no requiere credenciales; solo chequea sintaxis y referencias.

cat .terraform/modules/modules.json | head -20
#   Mira cómo Terraform resolvió el source "terraform-aws-modules/vpc/aws".
```

### Lo que **no** debes hacer sin pensarlo dos veces

```bash
terraform plan   # requiere credenciales AWS
terraform apply  # CREA RECURSOS DE PAGO
```

Si quieres de verdad llegar a `plan`, exporta credenciales de **una cuenta de laboratorio** y asume que una NAT Gateway cuesta ~$0.045/h + tráfico. Destruye con `destroy` al terminar.

## Qué mirar en el código

1. **El pin de versión**: `version = "~> 5.0"`. Rechaza automáticamente un `6.0` que podría traer breaking changes.
2. **La API de inputs**: solo pasamos los esenciales (`name`, `cidr`, `azs`, `private_subnets`, `public_subnets`). El módulo tiene decenas de inputs opcionales; no los tocamos.
3. **El contrato de outputs**: usamos `module.vpc.vpc_id`, `module.vpc.private_subnets`, etc. Esos nombres son **el contrato público**; si el autor los cambiara, rompería a los consumidores (por eso va a major).
4. **Ningún `provider` dentro del módulo**: lo configura el root.

## Evaluación rápida de este módulo

| Criterio | Verdict |
|----------|---------|
| Mantenimiento | OK (commits recientes, CI verde en el repo público) |
| Pin de providers | OK (`required_providers { aws = { version = ">= 5.46" } }` al momento de escribir) |
| Safe defaults | OK (no public buckets, no `0.0.0.0/0` sin flag explícito) |
| Tests | OK (`examples/` + `terraform test`) |
| Docs | OK (README autogenerado) |
| SemVer | OK (breaking changes van a major) |
| Superficie | **Grande** (centenares de inputs). Trade-off: cubre casos muy variados; curva de aprendizaje empinada. |

Veredicto: **adopt** con pin a `~> 5.0`. Lee el CHANGELOG antes de cambiar a `~> 6.0`.

## Limpieza

Si solo corriste `terraform init` + `validate`:

```bash
rm -rf .terraform .terraform.lock.hcl
```

Si llegaste a `apply` (no deberías sin leer primero):

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Preguntas de reflexión

1. ¿Por qué `source` y `version` son estáticos (no aceptan `var.x`)?
2. ¿Qué significa `version = "~> 5.0"` exactamente? ¿Y `~> 5.1.0`?
3. Si el módulo cambia `output "vpc_id"` por `output "id"` en la versión 6, ¿qué debe hacer un consumidor? ¿Por qué debió ir a major?
4. ¿Por qué `terraform init` baja el módulo aun sin credenciales AWS?
