# Ejemplo 02 — Lectura comentada de un `terraform plan` real

## Concepto que demuestra

Qué significan **cada símbolo** y **cada bloque** del output de `terraform plan`, en un ejemplo capturado y anotado. En particular:

- `+ create` — recurso nuevo.
- `- destroy` — recurso que se va.
- `~ update in-place` — modificación sin recrear.
- `-/+ replace` — forzar destroy + create por un atributo inmutable.
- `<= read` — data source que se resuelve en apply.
- `(known after apply)` — valores computados por el provider al crear.
- `# forces replacement` — anotación clave sobre por qué un `~` se convirtió en `-/+`.

## Contexto

Este ejemplo es **conceptual**: el output del plan es *capturado* (no ejecutado por ti). La idea es que puedas **leer** un plan línea a línea sin que nada te sorprenda. Verás plans reales a partir de `tf-02`.

## Objetivo

Al terminar deberías poder, dado un plan desconocido:

- Decir cuántos recursos **se crean**, se **destruyen** y se **modifican**.
- Identificar un **replacement** (`-/+`) y la causa (línea `# forces replacement`).
- Decir qué atributos aparecen `(known after apply)` y por qué.
- Reconocer un plan que es *drift* (cambios que no vienen de tu HCL).

## Prerrequisitos

- Haber leído §4 y §5 de `theory/lesson.md`.

## El escenario de partida

Supón que tienes esto en tus `.tf`:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "main", Env = "dev" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "public" }
}

resource "aws_instance" "web" {
  subnet_id     = aws_subnet.public.id
  ami           = "ami-0abcd1234"
  instance_type = "t3.small"
  tags          = { Name = "web" }
}
```

Y el `.tfstate` **ya** tiene estos recursos (porque se aplicó antes). Ahora editas:

- Cambias `tags = { Name = "main", Env = "dev" }` → `tags = { Name = "main", Env = "staging" }` en la VPC.
- Cambias `instance_type = "t3.small"` → `instance_type = "t3.medium"` en la instancia.
- Cambias `ami = "ami-0abcd1234"` → `ami = "ami-0ffff9999"` en la instancia.

Y corres `terraform plan`.

## Plan capturado (comentado)

```
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  ~ update in-place
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # aws_vpc.main will be updated in-place
  ~ resource "aws_vpc" "main" {
        id                               = "vpc-0a1b2c3d"
        cidr_block                       = "10.0.0.0/16"
      ~ tags                             = {
            "Name" = "main"
          ~ "Env"  = "dev" -> "staging"
        }
      ~ tags_all                         = {
            "Name" = "main"
          ~ "Env"  = "dev" -> "staging"
        }
        # (10 unchanged attributes hidden)
    }

  # aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
      ~ ami                              = "ami-0abcd1234" -> "ami-0ffff9999" # forces replacement
      ~ arn                              = "arn:aws:ec2:us-east-1:...:instance/i-0abc" -> (known after apply)
      ~ id                               = "i-0abc1234" -> (known after apply)
      ~ instance_type                    = "t3.small" -> "t3.medium"
      ~ private_ip                       = "10.0.1.42" -> (known after apply)
      ~ public_ip                        = "54.1.2.3"  -> (known after apply)
        subnet_id                        = "subnet-0a1b"
        tags                             = {
            "Name" = "web"
        }
        # (23 unchanged attributes hidden)
    }

Plan: 1 to add, 1 to change, 1 to destroy.
```

Léelo despacio, bloque por bloque.

### Bloque 1 — `aws_vpc.main`

```
  # aws_vpc.main will be updated in-place
  ~ resource "aws_vpc" "main" {
```

- `~` → **update in-place**. El provider sabe que cambiar tags de una VPC no requiere destruirla.
- `# aws_vpc.main will be updated in-place` → mensaje human-readable al principio del bloque.

```
        id                               = "vpc-0a1b2c3d"
```

- Sin marca a la izquierda → **no cambia**. El `id` es un valor conocido del state.

```
        cidr_block                       = "10.0.0.0/16"
```

- Sin marca → no cambia. Está impreso solo porque Terraform muestra el objeto completo para contexto.

```
      ~ tags                             = {
            "Name" = "main"
          ~ "Env"  = "dev" -> "staging"
        }
```

- `~` en `tags` → el mapa cambia. Dentro, solo `Env` tiene `~` con `dev -> staging`; `Name` no tiene marca porque no cambia.

```
      ~ tags_all                         = {
```

- `tags_all` es un atributo *computado* por el provider AWS que incluye los tags *default* del provider más los del recurso. Si cambias `tags`, `tags_all` suele cambiar también. Es ruido útil: te confirma que el provider ya calculó el resultado efectivo.

```
        # (10 unchanged attributes hidden)
```

- Economía visual: Terraform **oculta por default** los atributos que no cambian para no ahogarte en ruido. Para verlos todos: `-no-color` + `TF_LOG=TRACE` o simplemente lee `terraform state show aws_vpc.main`.

### Bloque 2 — `aws_instance.web`

```
  # aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
```

- `-/+` → **destroy + create**. "Must be replaced" al inicio del bloque.
- Esto es lo **peligroso**: la instancia actual (`i-0abc1234`) se **borra** y se crea una nueva. En producción, downtime y pérdida de estado efímero.

```
      ~ ami                              = "ami-0abcd1234" -> "ami-0ffff9999" # forces replacement
```

- **Clave**: `# forces replacement` al final de la línea → **este** atributo es el que fuerza el `-/+`. El provider AWS sabe que la AMI de una EC2 no se puede cambiar en caliente — hay que recrear.
- Siempre busca estas líneas cuando veas `-/+`: te dicen exactamente qué atributo cambió de "mutable" a "requiere reemplazo".

```
      ~ arn                              = "arn:aws:ec2:...:instance/i-0abc" -> (known after apply)
      ~ id                               = "i-0abc1234" -> (known after apply)
      ~ private_ip                       = "10.0.1.42" -> (known after apply)
      ~ public_ip                        = "54.1.2.3"  -> (known after apply)
```

- Como la instancia se recrea, su ARN, ID, private_ip y public_ip serán **nuevos**. Terraform aún no los conoce (los asignará AWS al crear) → `(known after apply)`.
- Esto es **exactamente** la razón de ser del state (§4.4 de la lección): el state guarda el ID actual (`i-0abc1234`) para que puedas referenciarlo; tras el apply, lo reemplazará con el nuevo.

```
      ~ instance_type                    = "t3.small" -> "t3.medium"
```

- Cambia de tipo. **Esto solo** sería un `~` (AWS permite cambiar instance_type con un stop/start). Pero el **replacement ya está forzado** por la AMI, así que todos los cambios se absorben en el `-/+`.

```
        subnet_id                        = "subnet-0a1b"
        tags                             = {
            "Name" = "web"
        }
```

- Sin marca → no cambian. Impresos por contexto.

```
        # (23 unchanged attributes hidden)
```

- Instancia EC2 tiene muchos atributos. Terraform oculta los que no cambian.

### Resumen

```
Plan: 1 to add, 1 to change, 1 to destroy.
```

- `1 to add` → la nueva EC2 (parte "+" del `-/+`).
- `1 to change` → la VPC (`~`).
- `1 to destroy` → la vieja EC2 (parte "-" del `-/+`).

**El `-/+` se cuenta como un add + un destroy.** Si ves `Plan: X to add, Y to change, Z to destroy` y hay replacements, add y destroy suben juntos.

---

## Otros símbolos que verás con el tiempo

### `+ create` puro (recurso nuevo)

```
  # aws_s3_bucket.logs will be created
  + resource "aws_s3_bucket" "logs" {
      + bucket        = "my-logs-dev"
      + id            = (known after apply)
      + arn           = (known after apply)
      + force_destroy = false
    }
```

Clásico. Todo el bloque va precedido de `+`. Casi todos los atributos computados aparecen como `(known after apply)`.

### `- destroy` puro

```
  # aws_s3_bucket.logs will be destroyed
  - resource "aws_s3_bucket" "logs" {
      - bucket = "my-logs-dev" -> null
      - id     = "my-logs-dev" -> null
    }
```

El recurso estaba en el state. Lo borraste del HCL. Terraform propone destruirlo.

### `<= read` (data source)

```
  # data.aws_ami.ubuntu will be read during apply
  <= data "aws_ami" "ubuntu" {
        most_recent = true
        owners      = ["099720109477"]
        id          = (known after apply)
    }
```

Un `data` source normalmente se resuelve en **plan** (y no aparece como "change"). Si sus argumentos dependen de recursos que aún no existen, se defiere a **apply** y aparece con `<=` en el plan. No cuenta como add/change/destroy.

### Drift detectado

Supón que no cambiaste nada en el HCL pero el próximo plan muestra:

```
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:

  # aws_security_group.web has been changed
  ~ resource "aws_security_group" "web" {
        id = "sg-0a1b"
      ~ ingress = [
          - {
              - cidr_blocks = ["10.0.0.0/16"]
              - from_port   = 22
              ...
            },
            # (1 unchanged element hidden)
        ]
    }
```

Esto es **drift**: alguien (consola, otro script, otro humano) **modificó** la Security Group fuera de Terraform. El bloque "Objects have changed outside of Terraform" aparece **antes** del plan normal. Y luego el plan propone **restaurar** lo que dice tu HCL.

**Lee la nota antes del plan**. Si no lo haces, aplicarás "a ciegas" sobre un cambio manual que podría haber sido legítimo.

---

## Resultado esperado

Después de leer este ejemplo deberías poder, dado un plan:

1. Contar add/change/destroy de un vistazo.
2. Encontrar `# forces replacement` y nombrar el atributo culpable.
3. Explicar por qué un atributo aparece como `(known after apply)` y de dónde saldrá ese valor.
4. Distinguir "cambio por diff normal" de "cambio por drift" (presencia del aviso "Objects have changed outside of Terraform").

## Interpretación

- **El plan es un contrato que lees**. Si no lo entiendes, no apliques. Es más barato preguntar que recrear la DB de prod.
- Los `-/+` son el **principal riesgo** de un `apply`. El 90% de los incidentes de "¿por qué se cayó?" después de un `terraform apply` corresponden a un `-/+` que nadie leyó.
- Los `(known after apply)` **no son errores**; son atributos computados por el provider al crear. Si todo tu plan está lleno de ellos, es porque estás creando desde cero (normal).
- El plan **se puede guardar** con `-out=plan.tfplan` y aplicar con `terraform apply plan.tfplan`. Lo revisado es exactamente lo que se aplica, sin TOCTOU entre fases.

## Errores frecuentes

- **"Hay muchos cambios, lo apruebo rápido."** No. Cada `-/+` es una decisión de reemplazar un recurso. Léelo.
- **"`~` siempre es seguro."** No siempre: cambiar un atributo de la base de datos puede implicar restart. "Seguro" lo decide tu negocio, no el símbolo.
- **"`(known after apply)` significa que algo está mal."** No, significa que el valor se sabrá al crear. Normal en recursos nuevos.
- **"El plan refleja lo que va a pasar exactamente."** Casi, pero puede haber diferencias si el apply no se hace del plan guardado y la realidad cambió en medio (TOCTOU).

## Relación con escenarios reales

- **Plan en PR**: en CI, el plan se publica como comentario en el PR y es parte del code review de infra.
- **Plan JSON**: `terraform show -json plan.tfplan` emite el plan en JSON para que herramientas como OPA/Conftest o Checkov evalúen policies sobre él antes de permitir el apply (lo verás en `tf-12`).
- **Diffs enormes**: si tu plan tiene 500 cambios, probablemente estás tocando algo compartido o acabas de refactorizar nombres sin usar `moved` blocks (verás `tf-09`).

## Limpieza

Nada que limpiar — este ejemplo es conceptual (plan capturado).
