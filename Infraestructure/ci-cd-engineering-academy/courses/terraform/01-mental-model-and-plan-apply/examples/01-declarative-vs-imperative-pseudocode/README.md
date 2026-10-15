# Ejemplo 01 — Declarativo vs imperativo (pseudocódigo)

## Concepto que demuestra

El mismo objetivo ("tener una VPC con dos subnets y una instancia EC2 corriendo nginx") expresado de **dos maneras radicalmente distintas**: un script imperativo que describe *cómo llegar al estado deseado* paso a paso, y una descripción declarativa (al estilo HCL) que solo dice *cuál es el estado deseado*.

El objetivo no es "ver código HCL" (eso llega en `tf-02`). Es internalizar la **asimetría**: dónde vive la lógica de reconciliación, quién detecta "esto ya existe", quién calcula el diff.

## Contexto

Antes de escribir `resource "aws_vpc" "main" { ... }`, hay que entender *qué desaparece* al pasar al modelo declarativo. Mucha lógica que en un script tienes que escribir tú — "¿ya existe?", "¿qué cambió?", "¿en qué orden?" — en IaC declarativa la hace la herramienta.

Este ejemplo es **conceptual y en pseudocódigo**. No se puede ejecutar. No requiere Terraform, AWS, ni línea de comandos.

## Objetivo

Al terminar deberías poder responder sin consultar:

- ¿Quién decide el **orden** de las operaciones en cada modelo?
- ¿Quién detecta "esto ya existe, no lo cree de nuevo"?
- ¿Qué pasa si el script se corta a mitad?
- ¿Qué pasa si el `apply` se corta a mitad?
- Si tienes que **cambiar el tamaño** de la EC2, ¿cuánto código tocas en cada modelo?

## Prerrequisitos

- Haber leído §1, §2 y §4 de `theory/lesson.md`.

## Escenario común

**Meta:** en una cuenta AWS vacía, dejar funcionando:

1. Una VPC con CIDR `10.0.0.0/16`.
2. Dos subnets: `10.0.1.0/24` (pública), `10.0.2.0/24` (privada).
3. Un Internet Gateway asociado a la VPC.
4. Una tabla de rutas pública con default route al IGW.
5. Una instancia EC2 `t3.small` en la subnet pública, con una Security Group que abra el puerto 80.
6. (La AMI y la user-data que arranca nginx se asumen dadas.)

Vamos a describir esto de dos maneras.

---

## Diagrama 1 — Imperativo (pseudocódigo tipo script)

```
# imperativo.sh  (pseudocódigo — no ejecutar)
# El SCRIPT es responsable de todo: orden, detección de existencia,
# cálculo de qué cambia, manejo de errores a mitad.

set -e

# ---- 1. VPC ----
vpc_id=$(aws_get vpc --tag Name=main)
if [ -z "$vpc_id" ]; then
  vpc_id=$(aws_create vpc --cidr 10.0.0.0/16 --tag Name=main)
else
  current_cidr=$(aws_get vpc_attr "$vpc_id" cidr)
  if [ "$current_cidr" != "10.0.0.0/16" ]; then
    echo "ERROR: la VPC existe pero con otro CIDR. ¿Qué hago?"
    exit 1
  fi
fi

# ---- 2. Subnets ----
pub_subnet_id=$(aws_get subnet --vpc "$vpc_id" --tag Name=public)
if [ -z "$pub_subnet_id" ]; then
  pub_subnet_id=$(aws_create subnet --vpc "$vpc_id" \
                     --cidr 10.0.1.0/24 --tag Name=public)
fi
priv_subnet_id=$(aws_get subnet --vpc "$vpc_id" --tag Name=private)
if [ -z "$priv_subnet_id" ]; then
  priv_subnet_id=$(aws_create subnet --vpc "$vpc_id" \
                      --cidr 10.0.2.0/24 --tag Name=private)
fi

# ---- 3. Internet Gateway ----
igw_id=$(aws_get igw --vpc "$vpc_id")
if [ -z "$igw_id" ]; then
  igw_id=$(aws_create igw --tag Name=main)
  aws_attach igw "$igw_id" "$vpc_id"
fi

# ---- 4. Route table ----
rt_id=$(aws_get rtb --vpc "$vpc_id" --tag Name=public)
if [ -z "$rt_id" ]; then
  rt_id=$(aws_create rtb --vpc "$vpc_id" --tag Name=public)
  aws_create route --rtb "$rt_id" --dest 0.0.0.0/0 --gw "$igw_id"
  aws_associate rtb-subnet "$rt_id" "$pub_subnet_id"
fi

# ---- 5. Security group ----
sg_id=$(aws_get sg --vpc "$vpc_id" --name web)
if [ -z "$sg_id" ]; then
  sg_id=$(aws_create sg --vpc "$vpc_id" --name web --desc "web")
  aws_create sg-rule --sg "$sg_id" --port 80 --proto tcp --cidr 0.0.0.0/0
fi

# ---- 6. EC2 ----
instance_id=$(aws_get instance --tag Name=web)
if [ -z "$instance_id" ]; then
  instance_id=$(aws_create instance \
                   --subnet "$pub_subnet_id" \
                   --sg "$sg_id" \
                   --type t3.small \
                   --ami ami-abc \
                   --user-data "...nginx..." \
                   --tag Name=web)
else
  current_type=$(aws_get instance_attr "$instance_id" type)
  if [ "$current_type" != "t3.small" ]; then
    echo "WARN: la instancia existe con otro tipo. ¿Modifico? ¿Reemplazo?"
    # ... lógica a mano ...
  fi
fi

echo "Done. instance=$instance_id"
```

Léelo. Preguntas:

- **¿Qué pasa si el script se corta** después de crear la VPC pero antes del IGW? Al re-correr, los `if` detectan la VPC y la crean *si no existe*. Pero el que escribió el script tuvo que **programar cada `if`**. Omite uno y la segunda corrida intentará crear algo duplicado.
- **¿Qué pasa si quieres cambiar el tipo** de EC2 de `t3.small` a `t3.medium`? El script tiene que **codificar la lógica**: "si existe y es de otro tipo, ¿qué hago?". La respuesta real (hay que *stop → modify → start*) es específica del recurso y la tienes que saber.
- **¿Qué pasa si borras algo del script**? Nada — el script solo crea. Para borrar necesitas *otro* script simétrico.
- **¿Dónde está la "verdad"**? En lo que hay en AWS. El script no tiene memoria entre corridas.

Esto es "IaC imperativa" o, más honestamente, "scripts de aprovisionamiento". Es lo que hace casi todo el mundo antes de IaC.

---

## Diagrama 2 — Declarativo (pseudocódigo tipo HCL)

```hcl
# declarativo.tf   (pseudocódigo — simplificado)
# El ARCHIVO solo describe QUÉ debe existir, no cómo llegar.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "main" }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  tags       = { Name = "public" }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  tags       = { Name = "private" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id
  name   = "web"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  instance_type          = "t3.small"
  ami                    = "ami-abc"
  user_data              = "...nginx..."
  tags                   = { Name = "web" }
}
```

Observa lo que **no** aparece:

- **No hay `if existe entonces nada`.** Las comparaciones las hace Terraform leyendo el state y el refresh.
- **No hay orden explícito.** Terraform construye un **grafo** a partir de las referencias (`aws_vpc.main.id` crea una dependencia implícita de `aws_subnet.public` a `aws_vpc.main`) y las crea en el orden topológico, en paralelo donde es seguro.
- **No hay manejo de "ya existe".** El state responde esa pregunta.
- **No hay comandos de borrado.** Si quitas `resource "aws_instance" "web"` del archivo, el próximo plan muestra `- destroy` y el apply la borra.
- **No hay manejo de "cambió un atributo".** Cambia `t3.small` → `t3.medium` y el plan te dirá `~ update in-place` (porque el provider sabe que el tipo se puede modificar sin recrear). Cambia la `ami` y verás `-/+ replace`.

**Dónde vive la complejidad en cada modelo:**

| Pregunta | Imperativo | Declarativo |
|----------|------------|-------------|
| ¿En qué orden crear? | Lo decides tú (orden del script). | Lo deriva Terraform del grafo. |
| ¿Ya existe? | `if` que escribes tú por cada recurso. | State. |
| ¿Qué cambió? | Comparas atributos a mano. | Plan calcula el diff. |
| ¿Cómo aplicar el cambio? | Lo codificas tú (es `modify` o `replace`?). | El provider lo sabe (`~` o `-/+`). |
| ¿Qué borrar? | Script simétrico de teardown. | Borra el `resource` del `.tf` y aplica. |
| ¿Si se corta a mitad? | Depende de tus `if`. | State refleja lo aplicado, el próximo plan continúa. |

**La herramienta ha absorbido** una cantidad enorme de lógica que antes era tuya. A cambio, exige un **state** (de ahí §4.4 de la lección) y un contrato: el código es la fuente de verdad.

---

## Resultado esperado

Después de leer los dos diagramas deberías poder:

1. Decir dónde vive la lógica de *reconciliación* en cada modelo.
2. Explicar por qué el modelo declarativo **necesita state** y el imperativo no.
3. Enumerar al menos 3 preguntas que el modelo imperativo exige al escritor del script y el declarativo *no*.
4. Decir qué pasa en cada modelo si cambias `t3.small` → `t3.medium` sin tocar nada más.

## Interpretación

- "Idempotencia emergente" vs "idempotencia programada": el modelo declarativo es idempotente *por diseño* (si no cambia nada en el .tf, el plan está vacío). El imperativo es idempotente *si tu`if` está bien escrito* — y rara vez lo está para todos los recursos.
- Si tu script imperativo "madura" bien, acaba reinventando el state (algún JSON o DB donde apuntar IDs). Terraform es la versión profesional de ese impulso.
- Esto no significa "imperativo malo". Hay casos (pipelines efímeros, migraciones one-shot) donde un script bien escrito gana. Lo que **no gana** es gestionar infra persistente a largo plazo.

## Errores frecuentes

- **"HCL es un lenguaje de programación."** No, es un lenguaje de configuración con expresiones. No tiene loops `while`, no tiene recursión arbitraria, no tiene IO. Las limitaciones son deliberadas: HCL quiere ser *leíble*, no *potente*.
- **"El declarativo es más corto, pues es mejor."** No es solo tamaño: la complejidad se mueve de ti (script) a la herramienta (state + provider). A cambio pagas con operar el state (backend, locking, backup) y entender el modelo del provider.
- **"Si no entiendo qué hace el `apply`, mejor imperativo que es explícito."** Al revés: en imperativo tienes que entender *el script* **y** *la API cloud*. En declarativo entiendes el **plan** y el proveedor hace la traducción. El plan es más corto de leer que un script bash de 400 líneas.

## Relación con escenarios reales

- **Migrar scripts a Terraform**: el patrón típico es importar los recursos existentes al state (`terraform import` o `import` blocks) y luego borrar los scripts. Verás esto en `tf-09`.
- **Scripts para one-shot**: migraciones de datos, bootstrapping de un bucket de state (meta-circular), tareas que ni siquiera pretenden ser idempotentes — ahí un script es correcto. Terraform **no** es la respuesta para todo.
- **Mixto en CI**: muchos pipelines combinan Terraform (para infra persistente) + scripts (para pasos imperativos: subir una build, invalidar una CDN, migrar la DB).

## Limpieza

Nada que limpiar — este ejemplo es conceptual.
