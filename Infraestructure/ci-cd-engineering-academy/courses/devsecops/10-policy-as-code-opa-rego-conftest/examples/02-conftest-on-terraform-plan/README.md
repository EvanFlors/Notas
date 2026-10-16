# Ejemplo 02 — Conftest sobre un Terraform plan JSON

> Local, sin cuenta cloud. Usa un `plan.json` **sintético** (no se corre `terraform`).
> SKIP automático si `conftest` no está instalado.

## 1. Qué vas a hacer

- Partir de un `terraform plan` **ya serializado** a JSON (lo proveemos).
- Escribir 2 policies Rego (`terraform/s3.rego`, `terraform/sg.rego`).
- Ejecutar `conftest test` sobre el JSON y leer violaciones.

## 2. Prerrequisitos

- `conftest` (`brew install conftest`).
- **No** se requiere Terraform instalado. El `plan.json` del ejemplo es un fixture.

## 3. Fixture: `plan.json`

Representa el output de `terraform show -json plan.out` con 3 recursos (uno malo S3, uno malo SG, uno EC2 inocuo). Guárdalo tal cual.

```json
{
  "format_version": "1.2",
  "terraform_version": "1.7.0",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_s3_bucket.public_assets",
          "mode": "managed",
          "type": "aws_s3_bucket",
          "name": "public_assets",
          "values": {
            "bucket": "my-public-assets-12345",
            "acl": "public-read",
            "versioning": [{"enabled": false}]
          }
        },
        {
          "address": "aws_security_group.wide_open",
          "mode": "managed",
          "type": "aws_security_group",
          "name": "wide_open",
          "values": {
            "name": "wide_open",
            "ingress": [
              {
                "from_port": 22,
                "to_port": 22,
                "protocol": "tcp",
                "cidr_blocks": ["0.0.0.0/0"]
              }
            ]
          }
        },
        {
          "address": "aws_instance.app",
          "mode": "managed",
          "type": "aws_instance",
          "name": "app",
          "values": {
            "instance_type": "t3.small",
            "ami": "ami-0abcdef1234567890",
            "tags": {"cost_center": "eng"}
          }
        }
      ]
    }
  }
}
```

## 4. Policies

### `policy/terraform/s3.rego`

```rego
package main

import rego.v1

deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket"
    r.values.acl == "public-read"
    msg := sprintf("S3 bucket %q has acl=public-read (forbidden)", [r.address])
}

deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket"
    some v in r.values.versioning
    v.enabled == false
    msg := sprintf("S3 bucket %q has versioning disabled", [r.address])
}
```

### `policy/terraform/sg.rego`

```rego
package main

import rego.v1

deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_security_group"
    some ing in r.values.ingress
    "0.0.0.0/0" in ing.cidr_blocks
    msg := sprintf(
        "SG %q allows %d/%s from 0.0.0.0/0",
        [r.address, ing.from_port, ing.protocol]
    )
}
```

> Nota: usamos `package main` porque es la convención por defecto de Conftest. Para repos grandes se recomienda un namespace por dominio (`package terraform.s3`) + `--namespace terraform.s3`.

## 5. Walk-through

```bash
tmp="/tmp/sec-10-02-conftest-tf"
mkdir -p "$tmp/policy/terraform" && cd "$tmp"

# escribe plan.json (seccion 3) y las dos policies (seccion 4)

conftest test plan.json
```

Salida esperada (resumen):

```
FAIL - plan.json - main - S3 bucket "aws_s3_bucket.public_assets" has acl=public-read (forbidden)
FAIL - plan.json - main - S3 bucket "aws_s3_bucket.public_assets" has versioning disabled
FAIL - plan.json - main - SG "aws_security_group.wide_open" allows 22/tcp from 0.0.0.0/0

3 tests, 0 passed, 0 warnings, 3 failures, 0 exceptions
```

Exit code: `1`. En CI, esto rompe la build.

## 6. Variante: `warn` en vez de `deny`

Cambia `deny` → `warn` en `s3.rego` para la regla de versioning. Vuelve a correr:

```
WARN - plan.json - main - S3 bucket "aws_s3_bucket.public_assets" has versioning disabled
FAIL - plan.json - main - S3 bucket "aws_s3_bucket.public_assets" has acl=public-read (forbidden)
FAIL - plan.json - main - SG "aws_security_group.wide_open" allows 22/tcp from 0.0.0.0/0

3 tests, 0 passed, 1 warnings, 2 failures, 0 exceptions
```

Exit code: `1` por los 2 `deny` restantes; el `warn` **no** falla la build por sí mismo.

## 7. Cómo se generaría `plan.json` en una pipeline real

```bash
terraform init
terraform plan -out plan.out
terraform show -json plan.out > plan.json
conftest test plan.json
```

El fixture aquí evita esos pasos para que el ejemplo sea offline y determinista.

## 8. Preguntas de autocomprobación

1. ¿Qué pasa si un recurso **no tiene** `values.ingress`? ¿La regla explota?
2. ¿Cómo expresar "el bloque de ingress completo tiene que estar vacío si `environment == 'prod'`"?
3. ¿Dónde pondrías esta validación en el pipeline: antes de `terraform apply` o después?

(Respuestas: 1) no explota, la expresión queda indefinida y la regla no dispara — ese es el punto; 2) añadir filtro extra `input.variables.environment.value == "prod"` o similar; 3) **antes** del apply, para fallar en PR, nunca en producción.)

## 9. Limpieza

```bash
rm -rf /tmp/sec-10-02-conftest-tf
```
