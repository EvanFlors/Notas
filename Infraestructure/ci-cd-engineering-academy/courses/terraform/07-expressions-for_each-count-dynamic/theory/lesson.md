# Lección: Expresiones, `for_each`, `count` y bloques `dynamic`

> **ID:** `tf-07-expressions-for_each-count-dynamic` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `tf-04-variables-outputs-locals`, `tf-06-modules`.

---

## 1. Introducción intuitiva

HCL se parece a JSON con bloques, y los primeros tres módulos del curso lo usamos casi así: declarábamos **un** recurso con **unos** atributos y mirábamos el plan. Pronto nos cansamos: queremos *diez* buckets, *cinco* usuarios, *N* reglas de ingress. Pegar `resource "x" ...` diez veces es evidentemente malo, pero las dos vías de salida no son equivalentes.

`count` es la más obvia: "repíteme este recurso `N` veces". Funciona hasta que un día borras el elemento número 2 de la lista, Terraform reindexa, y el plan te dice que va a destruir y recrear los recursos 3 y 4. Si eran buckets S3 con datos, acabas de aprender a pulso la diferencia entre "repetir por índice" y "repetir por identidad".

`for_each` es la respuesta madura: en vez de indexar por entero, indexas por una clave estable del dominio (`"alice"`, `"bob"`), y Terraform entiende que `alice` es `alice` aunque `bob` se vaya del map. El coste es que tienes que *construir* ese map, y a menudo lo construyes con una `for` expression a partir de una lista de objetos.

Y luego está `dynamic`, que confunde al 100 % de la gente la primera vez. `dynamic` **no itera recursos**: itera **sub-bloques** dentro de un recurso. Un security group tiene varios `ingress {}` dentro; `dynamic "ingress"` los genera a partir de una colección. No crea más security groups.

El hilo del módulo es: "cómo convertir un YAML/JSON de entrada en N recursos con el ciclo de vida correcto y sin que al cambiar un elemento se te caiga media infra".

---

## 2. Fundamentos

### 2.1 HCL es un lenguaje de expresiones

HCL tiene dos capas: la **estructura** (bloques, atributos, tipos) y las **expresiones** que ponemos del lado derecho de un `=`. Toda expresión tiene un tipo (string, number, bool, list, set, map, object, tuple) y Terraform infiere ese tipo o lo exige.

```hcl
locals {
  env       = "dev"                       # string
  replicas  = 3                           # number
  enabled   = true                        # bool
  names     = ["alice", "bob", "carol"]   # list(string)
  by_name   = { alice = 30, bob = 25 }    # map(number)
  user      = { name = "alice", age = 30 } # object
}
```

La distinción `list` vs `set` vs `tuple` vs `map` vs `object` importa para `for_each`: solo acepta **map** o **set of string**. Una lista no sirve directamente — hay que convertir con `toset()` o construir un map.

### 2.2 Operadores y condicional

Aritméticos (`+ - * / %`), comparación (`== != < <= > >=`), lógicos (`&& || !`), concatenación de strings vía interpolación (`"${a}-${b}"`). El condicional ternario:

```hcl
locals {
  size = var.env == "prod" ? "large" : "small"
}
```

No hay `if` como sentencia dentro de un bloque; el `if` vive dentro de expresiones (`for ... if ...`) o como ternario.

### 2.3 Interpolación y heredoc

```hcl
locals {
  greeting = "hola, ${var.name}!"
  script   = <<-EOT
    #!/bin/bash
    echo "env=${var.env}"
  EOT
}
```

El `<<-EOT` (con guión) hace trim de la indentación común. Útil para scripts embebidos legibles.

---

## 3. Contexto histórico

- **Terraform 0.11 (2017)** — Primeras versiones de `count`. Sin `for_each`, sin `for` expressions. La gente armaba trucos con `element(list, count.index)` y "null placeholders" (horror).
- **Terraform 0.12 (2019)** — Rewrite grande del lenguaje. Aparecen: tipos ricos, `for` expressions, splats mejorados, `dynamic` blocks, interpolaciones de primera clase (ya no todo entre `${}`).
- **Terraform 0.12.6 (2019)** — Llega `for_each`. El patrón idiomático pasa de `count` a `for_each` para colecciones de recursos.
- **Terraform 0.13 (2020)** — `for_each` y `count` se extienden a **módulos** (no solo recursos).
- **Terraform 1.0 (2021)** — Estabilidad del lenguaje; todo lo anterior se congela.
- **Terraform 1.1+ (2022)** — `moved` blocks ayudan a refactorizar de `count` a `for_each` sin recrear, pero el salto sigue siendo doloroso.

Moraleja histórica: el equipo de HashiCorp aprendió por las malas que `count` solo no bastaba. `for_each` fue respuesta directa a los pies cortados.

---

## 4. Funcionamiento interno

### 4.1 Cómo representa el grafo cada meta-argument

Terraform construye un **DAG** de recursos. Cada nodo del grafo tiene una **dirección** (`address`) estable que se guarda en el state.

- `count = 3` sobre `aws_user.this` crea tres nodos: `aws_user.this[0]`, `aws_user.this[1]`, `aws_user.this[2]`. La clave es el entero.
- `for_each = { alice = {...}, bob = {...} }` sobre `aws_user.this` crea nodos: `aws_user.this["alice"]`, `aws_user.this["bob"]`. La clave es el string.

Esta "clave en la dirección" es la que Terraform compara entre el state (lo que ya existe) y el config (lo que queremos). Si la clave existe en ambos lados: compara atributos. Si solo está en el config: `create`. Si solo está en el state: `destroy`.

### 4.2 La trampa de `count` (reindex)

Config inicial:

```hcl
variable "users" { default = ["alice", "bob", "carol"] }

resource "null_resource" "u" {
  count = length(var.users)
  triggers = { name = var.users[count.index] }
}
```

State tras el `apply`:

```
null_resource.u[0]  -> name=alice
null_resource.u[1]  -> name=bob
null_resource.u[2]  -> name=carol
```

El estudiante elimina a `bob`. Nuevo config:

```hcl
variable "users" { default = ["alice", "carol"] }
```

¿Qué planea Terraform?

```
null_resource.u[1]  name: "bob"   -> "carol"   # modify (requires replace)
null_resource.u[2]  destroy
```

Resultado: **se destruye y recrea `carol`**, aunque conceptualmente no cambió nada para ella. Es la trampa clásica.

### 4.3 `for_each` elimina la trampa

```hcl
variable "users" { default = ["alice", "bob", "carol"] }

resource "null_resource" "u" {
  for_each = toset(var.users)
  triggers = { name = each.key }
}
```

State:

```
null_resource.u["alice"]
null_resource.u["bob"]
null_resource.u["carol"]
```

Eliminamos a `bob`. Plan:

```
null_resource.u["bob"]  destroy
```

Nada más se toca. La **identidad** del recurso (su dirección en el grafo) depende de un valor estable del dominio (el nombre), no de la posición en una lista.

### 4.4 `dynamic` es sintáctico, no semántico

Un `aws_security_group` tiene varios sub-bloques `ingress {}`. Si quieres 5 reglas sin escribir 5 bloques, usas `dynamic`:

```hcl
resource "aws_security_group" "web" {
  name = "web"

  dynamic "ingress" {
    for_each = var.rules
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.proto
      cidr_blocks = ingress.value.cidrs
    }
  }
}
```

Esto **expande** los sub-bloques antes de que el grafo se construya. Al grafo le llega *un* `aws_security_group.web` con 5 `ingress` adentro. `dynamic` no toca el ciclo de vida.

Error común: tratar `dynamic` como si creara recursos. No lo hace. Para N recursos: `for_each` o `count`. Para N sub-bloques en un recurso: `dynamic`.

---

## 5. `for` expressions

Son la navaja suiza de HCL. Dos formas:

**Comprehension de lista** `[for ...]`:

```hcl
locals {
  names    = ["alice", "bob", "carol"]
  upper    = [for n in local.names : upper(n)]              # ["ALICE","BOB","CAROL"]
  short    = [for n in local.names : n if length(n) < 5]    # ["alice","bob"]
}
```

**Comprehension de map** `{for ...}`:

```hcl
locals {
  users_list = [
    { name = "alice", email = "alice@acme.io" },
    { name = "bob",   email = "bob@acme.io"   },
  ]

  # Lista de objetos -> map keyed por nombre. Este es EL patrón para alimentar for_each.
  users_by_name = { for u in local.users_list : u.name => u }
}
```

Resultado:

```hcl
{
  alice = { name = "alice", email = "alice@acme.io" }
  bob   = { name = "bob",   email = "bob@acme.io"   }
}
```

Ahora `for_each = local.users_by_name` da claves estables sin que la fuente tenga que ser un map escrito a mano.

---

## 6. Funciones de uso diario

### 6.1 Colecciones

| Función | Para qué |
|---------|----------|
| `concat(a, b, ...)` | Une listas. |
| `merge(m1, m2, ...)` | Une maps; el último gana en caso de clave repetida. |
| `lookup(m, k, default)` | Valor por clave con fallback. |
| `coalesce(a, b, ...)` | Primer argumento no vacío (no null, no ""). |
| `compact(list)` | Quita cadenas vacías. |
| `flatten(list)` | Aplana un nivel. |
| `distinct(list)` | Deduplica. |
| `toset(list)` | Convierte a set (orden irrelevante, elementos únicos). Imprescindible para `for_each = toset(var.names)`. |
| `tomap(x)` | Fuerza a map. |
| `keys(m)` / `values(m)` | Como en Python. |

### 6.2 Seguras (no explotan si falta el dato)

```hcl
locals {
  port = try(var.cfg.port, 8080)   # si var.cfg no tiene port, usa 8080
  ok   = can(regex("^[0-9]+$", var.id))  # true/false
}
```

`try(a, b, ...)` evalúa en orden y devuelve el primero que no lance error. `can(expr)` devuelve `true` si `expr` evalúa sin error. Son la diferencia entre un módulo que falla con stack trace feo y uno que degrada bien.

### 6.3 Encoding y archivos

```hcl
locals {
  users    = yamldecode(file("${path.module}/users.yaml"))
  rendered = templatefile("${path.module}/user.tftpl", { name = "alice" })
  json     = jsonencode({ a = 1, b = [2, 3] })
}
```

`yamldecode(file(...))` es el patrón más común para separar **datos** del **código**: el YAML lo editan ingenieros de plataforma; el HCL define el cómo.

---

## 7. Splat expressions

Azúcar sobre `for`:

```hcl
# Con count:
resource "null_resource" "u" {
  count    = 3
  triggers = { n = tostring(count.index) }
}

output "ns" {
  value = null_resource.u[*].triggers.n   # ["0","1","2"]
}
```

Con `for_each`, splat sigue funcionando pero devuelve valores ordenados **lexicográficamente por clave**:

```hcl
resource "null_resource" "u" {
  for_each = toset(["carol", "alice", "bob"])
  triggers = { n = each.key }
}

output "ns" {
  value = values(null_resource.u)[*].triggers.n
  # ["alice","bob","carol"]  (orden lexicográfico, no de inserción)
}
```

Determinista, pero el estudiante debe saber que `for_each` no preserva orden "humano".

---

## 8. `count` vs `for_each` — guía de decisión

| Pregunta | Usa `count` si... | Usa `for_each` si... |
|----------|-------------------|----------------------|
| ¿Los elementos tienen identidad propia (nombre, dominio, etc.)? | No, son fungibles ("3 workers idénticos"). | Sí, cada uno es distinto ("alice", "bob", "carol"). |
| ¿Vas a añadir/quitar elementos en el medio? | Nunca, solo creces al final. | Es probable; necesitas no romper los demás. |
| ¿Necesitas 0 o 1 recurso según una condición? | `count = var.enabled ? 1 : 0` sigue siendo idiomático. | Overkill. |
| ¿Las claves se conocen antes de `apply`? | N/A. | Sí (si no, falla con "cannot be determined"). |

Regla práctica: **`for_each` por defecto; `count` solo para el patrón 0/1**.

### 8.1 Ejemplo donde `count` falla y `for_each` no

```hcl
# count:
variable "buckets" { default = ["logs", "data", "backup"] }
resource "aws_s3_bucket" "b" {
  count  = length(var.buckets)
  bucket = "acme-${var.buckets[count.index]}"
}
```

Borras `"data"` → Terraform planea:

```
# aws_s3_bucket.b[1] must be replaced
-/+ resource "aws_s3_bucket" "b" {
    ~ bucket = "acme-data"  -> "acme-backup"  # forces replacement
    ...
}
# aws_s3_bucket.b[2] will be destroyed
```

Destruye y recrea `backup`, destruye `data`. **Pérdida de datos** si el bucket tenía objetos.

Con `for_each`:

```hcl
resource "aws_s3_bucket" "b" {
  for_each = toset(var.buckets)
  bucket   = "acme-${each.key}"
}
```

Borras `"data"` → plan:

```
# aws_s3_bucket.b["data"] will be destroyed
```

Solo lo que pediste.

---

## 9. `dynamic` blocks a fondo

Sintaxis general:

```hcl
dynamic "<sub-bloque>" {
  for_each = <coleccion>
  iterator = <nombre>        # opcional; por default se llama como el sub-bloque
  content {
    # usar <nombre>.key y <nombre>.value
  }
}
```

Ejemplo con `null_resource` (didáctico, sin cloud):

```hcl
resource "null_resource" "configured" {
  triggers = {
    rules = jsonencode([
      for r in var.rules : {
        from = r.from, to = r.to, proto = r.proto
      }
    ])
  }
}
```

(No todos los recursos tienen sub-bloques; `dynamic` se nota más con `aws_security_group`, `aws_lb_listener_rule`, `kubernetes_deployment`.)

**Anti-patrones**:

- `dynamic` para expandir *todo* un recurso: usa `for_each` sobre el recurso.
- `dynamic` sobre atributos simples: para atributos repetidos se usa una lista; `dynamic` es solo para **bloques**.
- `dynamic` triplemente anidado: señal de que la estructura de datos de entrada está mal; aplánala con `flatten` + `for`.

---

## 10. `terraform console`

REPL para expresiones. Lee el `terraform.tfstate` del directorio actual y pone a tu disposición `var.*`, `local.*`, `module.*`, `resource.*`, funciones y operadores.

```
$ terraform console
> upper("hola")
"HOLA"
> [for n in ["a","b"] : upper(n)]
tolist([
  "A",
  "B",
])
> { for u in local.users_list : u.name => u.email }
{
  "alice" = "alice@acme.io"
  "bob"   = "bob@acme.io"
}
```

Usos:

1. **Depurar una expresión antes de meterla al código**. Más barato que `plan` cada vez.
2. **Explorar un state** tras `apply`: `null_resource.u["alice"].triggers`.
3. **Enseñar**: todo lo de la sección 5 y 6 se practica aquí sin tocar providers.

---

## 11. Patrón "data-driven infra"

Juntando todo:

```yaml
# users.yaml
- name: alice
  email: alice@acme.io
  groups: [eng, admins]
- name: bob
  email: bob@acme.io
  groups: [eng]
```

```hcl
locals {
  users_raw = yamldecode(file("${path.module}/users.yaml"))
  users     = { for u in local.users_raw : u.name => u }
}

resource "local_file" "user_profile" {
  for_each = local.users
  filename = "${path.module}/out/${each.key}.txt"
  content  = "name=${each.value.name}\nemail=${each.value.email}\ngroups=${join(",", each.value.groups)}\n"
}
```

- Añadir un usuario: editar YAML. HCL no se toca.
- Quitar a `bob`: solo `local_file.user_profile["bob"]` se elimina.
- Renombrar a `alice` → `alicia`: destroy `["alice"]` + create `["alicia"]` (esperable y correcto: cambió la identidad).

Esta es la plantilla real de "N recursos desde datos" que vas a replicar durante el resto del curso.

---

## 12. Preguntas de evaluación

Responde sin consultar la lección:

1. Da **un ejemplo concreto** donde `count` fuerza un destroy+create innecesario y `for_each` no.
2. ¿Qué devuelve `[for u in [{name="a"},{name="b"}] : u.name]`? ¿Y `{for u in esa_lista : u.name => u}`?
3. Diferencia entre `dynamic "ingress"` y `for_each` sobre un recurso. ¿Cuál cambia el grafo?
4. ¿Por qué `for_each = toset(var.names)` necesita que las claves se conozcan en plan time? ¿Qué pasa si una clave viene de un atributo computado?
5. ¿Cuál es la diferencia entre `try(a, b)` y `coalesce(a, b)`?
6. En `null_resource.u[*].triggers.n` con `for_each`, ¿en qué orden salen los valores?
7. ¿Por qué `dynamic` no debería anidarse más de dos niveles? ¿Qué refactor aplicarías?
8. Un compañero propone `count = var.create_user ? 1 : 0` para un `aws_iam_user`. ¿Lo aceptas o lo cambias a `for_each`? Justifica.
