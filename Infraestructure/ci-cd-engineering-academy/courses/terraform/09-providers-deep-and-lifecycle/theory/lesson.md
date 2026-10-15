# tf-09 — Providers avanzados y control del ciclo de vida

> Lección de referencia. Léela completa antes de las actividades. Las secciones 4 a 9 son el núcleo operativo del módulo.

---

## 1. Por qué este módulo existe

En los primeros módulos aprendiste a declarar recursos, parametrizarlos y entender el state. Eso basta para que Terraform **cree** infraestructura. Lo que no basta — y lo que separa a quien lo usa en juguetes de quien lo opera en producción — es lo que ocurre **después**: renombrar un recurso sin recrearlo, adoptar algo que ya existe, decidir qué atributos debe ignorar TF, evitar un downtime al reemplazar un balanceador, impedir que un `terraform apply` distraído borre la base de datos de prod.

Todo eso vive en dos lugares del lenguaje: el **bloque `provider`** (y sus `alias`) y el **bloque `lifecycle`** dentro de cada `resource`. A eso se suman tres bloques "de nivel raíz" que son los que convierten refactorings dolorosos en commits ordinarios: `moved`, `import` y `removed`.

Al terminar deberías poder **leer un plan destructivo y saber en 30 segundos qué bloque arreglarlo**.

---

## 2. Configuración fina de providers

### 2.1 `required_providers` + `provider`

En cualquier stack serio hay dos bloques distintos:

```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "local"  {}
provider "random" {}
```

- `required_providers` fija **qué plugin** se baja y en qué rango de versiones. Es lo que respeta el **lockfile** `.terraform.lock.hcl` (hashes incluidos).
- `provider "x" { ... }` configura **esa instancia** del plugin (región, credenciales, endpoints).

Ambos pueden coexistir sin fricción con `terraform init` incluso si no has escrito el bloque `provider` — TF asume defaults. Pero el momento en que necesitas **más de una instancia del mismo provider** (dos regiones, dos cuentas), aparece `alias`.

### 2.2 `alias`: varias instancias del mismo provider

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "sa_east_1"
  region = "sa-east-1"
}

resource "aws_s3_bucket" "logs_us" {
  bucket = "org-logs-us"
}

resource "aws_s3_bucket" "logs_br" {
  provider = aws.sa_east_1
  bucket   = "org-logs-br"
}
```

Puntos finos:

- El provider **sin alias** es el "default"; los recursos que no declaran `provider = ...` lo usan.
- Un recurso referencia un alias con `provider = aws.sa_east_1` (sin comillas; es una referencia, no un string).
- En **módulos hijos**, el provider no se "hereda mágicamente" cuando hay alias: hay que pasar el mapa `providers = { aws = aws.sa_east_1 }` en el bloque `module`.
- Cambiar el alias de un recurso ya creado implica, por default, destroy+create (TF ve "este recurso ahora pertenece a otro provider"). Para evitarlo: `moved` block (sección 7).

### 2.3 Patrón multi-cuenta / multi-región sin workspaces

Los workspaces (`tf-08`) no son la respuesta a "quiero multi-región". Los **aliases** sí lo son dentro de un mismo stack, cuando los recursos están naturalmente acoplados (ej.: réplica cross-region de un bucket). Si los stacks son independientes, directorios separados siguen ganando.

---

## 3. `lifecycle`: cuatro meta-arguments, cuatro problemas distintos

El bloque `lifecycle` vive **dentro** de un `resource`. Sus cuatro atributos atacan problemas muy diferentes.

### 3.1 `create_before_destroy = true`

**Problema**: reemplazar un recurso en caliente produce downtime, porque TF por default **destruye primero y crea después**.

**Solución**: invertir el orden.

```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = var.ami_id

  lifecycle {
    create_before_destroy = true
  }
}
```

**Restricción crítica**: el recurso no puede tener restricciones de **unicidad global** que colisionen entre la versión vieja y la nueva. Si el recurso tiene un `name` fijo (no `name_prefix`), al intentar crear el reemplazo con el mismo nombre, el provider responde "ya existe" y el `create` falla. Resultado: el viejo sigue vivo y el nuevo nunca se creó.

La convención es: cuando declaras `create_before_destroy`, **derivá el nombre** del recurso (sufijo random, timestamp, `name_prefix` del provider si lo soporta). Es el patrón del `examples/01-create-before-destroy-lb/`.

### 3.2 `prevent_destroy = true`

**Problema**: alguien, algún día, va a correr un `terraform destroy` o un refactor accidental que proponga borrar la base de datos de producción.

**Solución**: un veto duro declarativo.

```hcl
resource "aws_db_instance" "prod" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

Cualquier plan que proponga `-` sobre ese recurso **aborta con error**. No se desactiva por una flag en apply; hay que editar el HCL y hacer un commit — que, obviamente, se revisa en PR.

Límites honestos:

- No protege contra `terraform state rm aws_db_instance.prod` seguido de `terraform destroy` (porque TF ya no "ve" el recurso).
- No protege contra borrado desde la consola cloud.
- No sustituye a políticas IAM, backups, snapshots ni policy-as-code.

Es una **primera línea de defensa**, no la única.

### 3.3 `ignore_changes = [...]`

**Problema**: hay atributos del recurso que **otro sistema** modifica legítimamente (tags inyectados por SCPs, `desired_capacity` ajustado por auto-scaling, campos auto-rotados). Si TF los ve "fuera de lo declarado", cada plan muestra un diff que vuelve a sobrescribir ese valor.

**Solución**: decirle a TF que **no genere diff** para esos atributos.

```hcl
resource "aws_autoscaling_group" "web" {
  # ...
  desired_capacity = 2

  lifecycle {
    ignore_changes = [desired_capacity, tag]
  }
}
```

Qué pasa internamente:

- TF **sigue leyendo** el valor real desde la API en el refresh.
- Lo **guarda en el state** para trazabilidad.
- Pero **no compara** ese atributo contra el HCL — no genera `~` sobre él.

Formas aceptadas:

- Lista de atributos: `ignore_changes = [tags, desired_capacity]`.
- Un atributo específico de un mapa: `ignore_changes = [tags["Owner"]]`.
- Todo: `ignore_changes = all` (brocha gorda; evitar salvo "adopción temporal").

### 3.4 `replace_triggered_by = [...]`

**Problema**: cuando cambia **otro recurso**, quiero que **este** se reemplace, aunque sus propios atributos no hayan cambiado.

**Solución**:

```hcl
resource "null_resource" "deploy" {
  # ...
  lifecycle {
    replace_triggered_by = [aws_launch_template.web.latest_version]
  }
}
```

Caso típico: forzar que una instancia o un recurso wrapper se recree cuando cambia la versión de la plantilla de la que se derivó. Es menos común que los otros tres meta-arguments; úsalo cuando la dependencia es "cuando tú cambias de identidad, yo soy obsoleto".

---

## 4. `provisioner`: por qué es siempre el último recurso

Los provisioners (`local-exec`, `remote-exec`, `file`) ejecutan comandos **imperativos** durante `apply`. HashiCorp los documenta como *last resort*. Hay razones concretas:

1. **No participan del plan.** `terraform plan` no simula provisioners. Si un `remote-exec` va a fallar, lo descubrís en apply, con el recurso ya creado y potencialmente dañado.
2. **No son idempotentes.** Terraform asume CRUD declarativo; un provisioner es "run this shell". Correrlo dos veces puede duplicar efectos.
3. **Rompen el modelo state ⇄ realidad.** El provisioner cambia la realidad sin dejar huella en el state.
4. **Se pierden al cambiar provider.** Si migras de un provider a otro para el mismo recurso, el provisioner no "viaja".
5. **Fallo = taint.** Si un provisioner falla, el recurso queda marcado y se **destruirá y recreará** al próximo apply, con todo lo que eso implica en producción.

El **único** uso que a veces se defiende sin incomodidad es `when = destroy`:

```hcl
provisioner "local-exec" {
  when    = destroy
  command = "echo 'destroying ${self.id}' >> /tmp/audit.log"
}
```

Para todo lo demás, preferir alternativas declarativas:

- Imágenes preconstruidas (Packer).
- `user_data` / `cloud-init` para bootstrap de VM.
- Módulos del provider que ya hagan la operación.
- Un **pipeline posterior** (Ansible, GitHub Actions) que haga el "software provisioning" tras el `apply`.

---

## 5. Reemplazo manual: `-replace` sustituye a `taint`

Antes se forzaba una recreación con:

```bash
terraform taint aws_instance.web   # marca el recurso como "sucio"
terraform apply                     # lo destruye y recrea
```

Problema: `taint` **modifica el state al margen del código**. Dos personas pueden ver código idéntico pero planes distintos.

Desde Terraform 0.15.2 (y en todas las versiones modernas), `taint` está **deprecado**. Se usa:

```bash
terraform apply -replace=aws_instance.web
```

- El plan explícitamente muestra `# aws_instance.web will be replaced, as requested`.
- No deja state "sucio" entre comandos.
- Se puede combinar con `-target` para operaciones quirúrgicas (sabiendo que `-target` también es escape hatch).

Caso de uso típico: un pool de instancias con configuración "sucia" (alguien entró por SSH y rompió algo). `-replace` fuerza la rotación sin tocar el código.

---

## 6. `moved {}`: renombrar sin recrear

### 6.1 El problema

Supongamos que tenés:

```hcl
resource "local_file" "greeting" {
  filename = "/tmp/hello.txt"
  content  = "hi"
}
```

y decidís renombrar a `local_file.welcome`. Si solo cambias el HCL:

```
# local_file.greeting will be destroyed
# local_file.welcome will be created
```

Destroy + create. Para `local_file` no pasa nada; para un `aws_db_instance` sería una catástrofe.

### 6.2 La solución

Agregas, al **mismo nivel que los `resource`**, un bloque `moved`:

```hcl
resource "local_file" "welcome" {
  filename = "/tmp/hello.txt"
  content  = "hi"
}

moved {
  from = local_file.greeting
  to   = local_file.welcome
}
```

Resultado del plan: `No changes.` Terraform entiende que es un rename y actualiza el **address** del recurso en el state sin tocar la realidad.

### 6.3 Casos cubiertos

- Renombrar un recurso: `resource.old` → `resource.new`.
- Mover entre módulos: `module.a.aws_s3_bucket.x` → `module.b.aws_s3_bucket.x`.
- Convertir un recurso individual a `for_each`: `aws_iam_user.alice` → `aws_iam_user.users["alice"]`.

### 6.4 `moved` vs `terraform state mv`

| | `moved {}` | `terraform state mv` |
|---|---|---|
| Versionado | Sí (vive en Git) | No (comando ad-hoc) |
| Revisable en PR | Sí | No |
| Reproducible en otro environment | Sí (todos aplican el mismo HCL) | No (hay que recordar correr el comando) |
| Historial | Sí (el commit) | No |

Regla: **siempre `moved`**, salvo cosas puntuales que no van a repetirse en otro backend.

Nota operativa: una vez que el rename se propagó a **todos los backends** (dev/stg/prod), el bloque `moved` puede borrarse. Mientras alguien no haya aplicado todavía, hay que dejarlo.

---

## 7. `import {}`: adoptar lo que ya existe, en código

### 7.1 El problema

Un recurso fue creado por consola (o por otro equipo, o antes de Terraform). Lo quieres adoptar en tu stack. Hay dos caminos.

### 7.2 Camino viejo: comando `terraform import`

```bash
terraform import aws_s3_bucket.logs org-logs-2019
```

- Procedural. No deja constancia en el código.
- Hay que **escribir el HCL antes a mano** para que coincida con lo que hay en la nube.
- Si lo haces en una máquina y no documentas, nadie sabe que ese recurso entró por import.

### 7.3 Camino moderno (TF ≥ 1.5): bloque `import {}`

```hcl
import {
  to = local_file.adopted
  id = "/tmp/existing.txt"
}

resource "local_file" "adopted" {
  filename = "/tmp/existing.txt"
  content  = file("/tmp/existing.txt")
}
```

- `to` referencia el address del recurso en TU código.
- `id` es el identificador que ese provider usa para localizar el recurso en el mundo real (en AWS puede ser un ARN, un bucket name, etc.).
- `terraform plan` muestra: `# local_file.adopted will be imported`. En `apply`, pasa al state **sin recrearlo**.

Bonus: `terraform plan -generate-config-out=generated.tf` genera un esqueleto HCL del recurso adoptado basado en lo que lee el provider. Útil para arrancar.

### 7.4 Cuándo borrar el `import` block

Igual que `moved`: una vez propagado a todos los backends donde ese recurso ya está en state, el bloque puede retirarse. No causa daño dejarlo (TF detecta "ya está importado" y es no-op), pero sumado a cientos deja ruido.

---

## 8. `removed {}`: quitar del state sin destruir en la nube

(TF ≥ 1.7 / OpenTofu ≥ 1.6.)

### 8.1 El problema

Querés **sacar un recurso del código** pero NO destruirlo. Casos:

- Otro equipo se hizo cargo y ahora lo gestiona en otro state.
- Es un recurso compartido que mal pertenecía a este stack.
- Lo adoptó un sistema externo (ClickOps consciente, control plane distinto).

### 8.2 Camino viejo: `terraform state rm`

```bash
terraform state rm aws_s3_bucket.shared
```

Procedural, no versionado, mismo problema que `taint`.

### 8.3 Camino moderno: `removed {}`

```hcl
removed {
  from = aws_s3_bucket.shared

  lifecycle {
    destroy = false
  }
}
```

- Borrás el `resource "aws_s3_bucket" "shared"` del código.
- Agregás este `removed` block.
- `terraform plan` dice: `# aws_s3_bucket.shared will no longer be managed by Terraform` (equivalente, texto exacto varía por versión).
- `destroy = false` deja el recurso vivo en la nube.
- `destroy = true` (o ausente, en OpenTofu) permite el destroy — pero entonces ya no es más que un `terraform destroy` del recurso.

El bloque puede eliminarse una vez propagado.

---

## 9. Lectura de un plan destructivo: árbol de decisión

Supongamos que corres `terraform plan` y ves:

```
# aws_db_instance.prod will be destroyed
# (because its name has been changed)

# aws_db_instance.production will be created
```

Diagnóstico paso a paso:

1. **¿Es un rename?** (El recurso vieja y nueva tienen el mismo tipo, solo cambió el `name` o la etiqueta en HCL.)
   → **`moved {}`** entre `aws_db_instance.prod` y `aws_db_instance.production`.
2. **¿Es un cambio de atributo `ForceNew`?** (TF muestra `-/+ destroy and then create replacement`, y lista `name:` o `engine:` en rojo.)
   → Decidir: ¿realmente quiero reemplazar? Si no, revertir el cambio en HCL. Si sí, agregar `lifecycle { create_before_destroy = true }` para evitar downtime (si la unicidad lo permite).
3. **¿Es un recurso que no debería tocarse jamás?**
   → Agregar `lifecycle { prevent_destroy = true }` como barrera.
4. **¿Es porque el recurso dejó de estar en el código pero ya no me pertenece?**
   → **`removed { lifecycle { destroy = false } }`**.
5. **¿Es porque TF ve atributos modificados por otro sistema?**
   → **`lifecycle { ignore_changes = [...] }`** para esos atributos específicos.
6. **¿Es porque el `provider` cambió (alias nuevo)?**
   → **`moved {}`** cubriendo también cambios de provider cuando aplica, o importar explícitamente al provider nuevo.

El error más común en producción: **leer el plan a toda prisa, decir "sí, apply", y recrear un recurso con estado**. La disciplina de aplicar este árbol antes de teclear `yes` es la mitad del valor de este módulo.

---

## 10. Interacción con módulos (nota rápida)

Los bloques `provider`, `moved`, `import` y `removed` tienen matices en módulos:

- `provider` con alias **no se hereda** mágicamente. En el `module "x" {}` del root se escribe `providers = { aws = aws.sa_east_1 }`.
- `moved` puede referenciar direcciones dentro de módulos: `module.a.aws_s3_bucket.x`.
- `import` dentro de un módulo funciona si el `to` apunta a un address del módulo. En TF reciente también funciona a nivel root referenciando el address del módulo.
- `removed` tiene matices entre Terraform y OpenTofu: Terraform permite el remover a nivel root referenciando addresses de módulos; OpenTofu amplió la sintaxis a `removed { from = module.a.aws_s3_bucket.x }`.

En el **capstone** del curso construirás módulos propios y harás un refactor con `moved` + `removed` en módulos reales; aquí usamos recursos didácticos para que el foco esté en los bloques, no en el provider.

---

## 11. Convenciones de equipo (opinionadas)

- **Siempre** `prevent_destroy = true` para: bases de datos de producción, KMS keys, buckets con datos no reconstruibles, DNS zones.
- **Siempre** `create_before_destroy = true` + nombre derivado para: launch templates, load balancers, listeners.
- **Nunca** `ignore_changes = all`. Si lo necesitas, es síntoma de que el recurso vive en otro sistema; considerá `removed`.
- **Nunca** `provisioner "remote-exec"` como camino principal. Si no hay módulo del provider, Packer y cloud-init suelen alcanzar.
- Los bloques `moved` / `import` / `removed` se **borran** después de propagar — no se dejan de adorno. Un repositorio con cien `moved` ancianos es ruido.
- `terraform taint` **no se usa**. Si aparece en un runbook, el runbook está desactualizado.

---

## 12. Preguntas de evaluación (sin consultar)

1. Un `terraform plan` muestra `-/+ destroy and then create replacement` sobre un `aws_db_instance` que no debería tocarse. ¿Cuál es el proceso mental para decidir si usar `moved`, `prevent_destroy`, `ignore_changes` o revertir el cambio en HCL?
2. Explicá por qué `create_before_destroy = true` requiere pensar la unicidad del nombre del recurso. Dá un ejemplo donde falla.
3. Diferencia operacional exacta entre `terraform state mv` y un bloque `moved {}`. ¿En qué repositorio queda constancia en cada caso?
4. ¿Qué hace exactamente `ignore_changes = [tags]`? ¿Dónde queda el valor real? ¿Dónde no aparece el diff?
5. ¿Por qué `prevent_destroy = true` no es una protección completa? Enumerá al menos tres caminos por los cuales el recurso puede terminar borrado igual.
6. ¿Cuál es la diferencia entre `import {}` block y el comando `terraform import`? ¿Cuál dejarías en un repo con 20 ingenieros?
7. ¿En qué escenario introducirías un `removed { lifecycle { destroy = false } }`? Da un caso concreto que no sea "porque el ejercicio lo pide".
8. ¿Qué garantías ofrece y qué garantías NO ofrece un `provisioner "local-exec"`? ¿Por qué HashiCorp lo documenta como "último recurso"?
