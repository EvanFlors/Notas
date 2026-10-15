# Lección: State basics

> **ID:** `tf-05-state-basics` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `tf-02` (ciclo `init/plan/apply/destroy` corriendo contra providers didácticos).

---

## 1. Introducción intuitiva

Imagina que escribes en un cuaderno la frase "quiero una silla roja en la esquina del salón". Esa frase es tu **estado deseado**. Un día te asomas al salón y ves efectivamente una silla roja en la esquina — ese es el **estado real**. Pero tú, desde la cocina, para saber si todo está en orden sin tener que mirar cada vez, llevas una **libreta** en la que anotaste "al 2 de octubre había una silla roja marca Ikea modelo *Henriksdal* en la esquina sureste del salón, con 4 patas, tapicería textil, serie A-442". Esa libreta es tu **estado real conocido**: tu última foto del mundo.

El **state file** de Terraform es exactamente esa libreta. No es la silla, no es el deseo — es la foto última que Terraform tiene de la realidad, lo bastante detallada para poder *comparar* con el deseo (el HCL) y decidir qué hacer. Si la libreta dice "silla marca Ikea A-442" y tu HCL dice "quiero silla roja", Terraform mira: la silla ya existe, es roja, no hay nada que hacer → *plan vacío*. Si cambias el HCL a "silla azul", Terraform compara: diferente color → *plan: cambiar tapicería*. Si tú **mueves manualmente la silla** y Terraform al refrescar su libreta nota que ya no está en la esquina sureste → *drift*.

Este módulo trata de esa libreta: cómo está escrita, cómo se lee, cómo se corrige con cuidado, dónde se guarda, y por qué **cualquiera que lea tu libreta sabe la marca y la serie de tu silla** — también de las que son secretas.

---

## 2. Fundamentos

### 2.1 El state es el *estado real conocido*

Terraform maneja tres cosas distintas que es fundamental no confundir:

| Nombre | Dónde vive | Quién lo escribe |
|--------|------------|-------------------|
| **Estado deseado** | Archivos `.tf` (HCL) | Tú, en Git |
| **Estado real conocido** | `terraform.tfstate` (JSON) | Terraform, al leer de los providers |
| **Estado real** | El cloud / la API | El mundo (incluidas acciones manuales) |

El **state** es el intermediario: una serialización local del "estado real" tal como Terraform lo vio por última vez. Al correr `terraform plan`, Terraform:

1. Lee el **state** (lo que creía que era real).
2. **Refresca** consultando a los providers (actualiza el state con lo que *ahora* dicen las APIs).
3. Compara **estado deseado** (HCL) vs. **estado real conocido** (state refrescado).
4. Emite el diff: `+ crear`, `- destruir`, `~ actualizar en sitio`, `+/-` recrear (destruir y crear).

**Sin state no hay forma barata de hacer el diff.** La alternativa sería que Terraform listara *todo* lo que hay en tu cuenta cloud, infiriera cuál de esos recursos corresponde a cuál bloque de tu HCL, y recalculara en cada `plan`. Esto es (a) lentísimo y (b) ambiguo (dos buckets de nombre parecido, ¿cuál es cuál?). El state resuelve ambos: cachea atributos y guarda un **mapeo HCL ↔ recurso real** por **address** (`aws_instance.web`, `random_pet.greeting[0]`).

### 2.2 ¿Por qué guarda **valores en claro**?

El state almacena el *resultado real conocido* de cada recurso, incluidos atributos **computados** por el provider (los que no escribes tú en el HCL, pero que el provider devuelve tras crear el recurso):

- IDs y ARNs.
- Direcciones IP asignadas.
- Fingerprints y keypairs.
- Contraseñas aleatorias generadas (`random_password.result`).
- Contenido de certificados (`tls_private_key.private_key_pem`).
- Outputs marcados `sensitive`.

Todo eso vive **en claro** en el JSON. Marcar un atributo o un output como `sensitive = true` **oculta el valor en la salida de la CLI** (en `terraform plan`, `apply`, `output`), pero **no cambia nada en el state**. Puedes abrir el `.tfstate` con `cat` y leerlo. Esto es una decisión de diseño consciente: Terraform necesita el valor para los diffs futuros; cifrarlo transparentemente movería el problema sin resolverlo.

**Consecuencias**:

- `terraform.tfstate` **nunca va a Git**. Nunca. Ni siquiera "temporalmente".
- Los `.tfvars` con secretos tampoco.
- Si tienes verdaderos secretos (contraseñas de prod, claves API, tokens), **viven en un sistema de secretos** (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager, etc.) y se consumen con un `data` source. No viajan como `variable` ni como atributo literal.
- Cualquiera con acceso al backend remoto que guarda el state tiene acceso efectivo a esos atributos. La **superficie de seguridad del state es la seguridad del backend**.

### 2.3 ¿Qué garantiza que una ejecución no pise a otra? → *locking*

Si dos ingenieros corren `terraform apply` al mismo tiempo contra el **mismo** state, pueden pisarse: lecturas desactualizadas, writes concurrentes, state corrupto. La defensa es el **lock** — un cerrojo que el backend adquiere antes de leer/escribir el state. Los backends locales usan un lock por archivo (fcntl); los remotos usan mecanismos propios (DynamoDB item, lock nativo S3, lock row en HCP…). Si el lock queda colgado (p. ej. porque la máquina murió a mitad de `apply`), hay que liberarlo con criterio (`terraform force-unlock <lock-id>`). Esto se profundiza en **`tf-11`**; por ahora, basta saber que **el locking es responsabilidad del backend**, no del binario de Terraform.

---

## 3. Contexto histórico

- **2014** — Terraform 0.1. State en JSON, backend local únicamente. La "libreta" era literalmente un archivo al lado de tus `.tf`.
- **2015** — Aparecen los primeros **remote backends** (Consul, S3). Problema evidente: equipos de más de una persona no pueden compartir un state local.
- **2016–2018** — Era de los `.tf.backup` y los conflictos de merge brutales en el state cuando por error alguien lo subía a Git. Nace la cultura "**el state nunca va a Git**" con fuerza.
- **2017** — `terraform state` CLI consolidado (`list`, `show`, `mv`, `rm`, `pull`, `push`).
- **2019** — Terraform 0.12: cambios profundos en HCL; migración forzada del formato de state (`terraform 0.12upgrade`). Lección operacional: el **versionado** del state (campo `version`) es serio.
- **2020–2022** — `moved` blocks (1.1): alternativa declarativa a `terraform state mv` dentro del HCL. Reduce la fricción del refactor.
- **2023–2024** — `import` blocks declarativos (alternativa a `terraform import` CLI); `removed` blocks (alternativa declarativa a `terraform state rm`). HashiCorp cambia a BUSL; **OpenTofu** nace. En paralelo, OpenTofu introduce **state encryption nativa** (una pieza largamente pedida).
- **2024+** — S3 backend soporta locking nativo (fin de la dependencia histórica de DynamoDB como lock table).

El state nunca ha cambiado conceptualmente — ha cambiado la forma de operarlo. La trayectoria es clara: menos CLI imperativa (`state mv`, `state rm`, `import`), más declarativo (`moved`, `removed`, `import` blocks).

---

## 4. Funcionamiento interno

### 4.1 Formato del archivo

El state es un **JSON versionado**. Un `terraform.tfstate` recién creado se ve así (abreviado):

```json
{
  "version": 4,
  "terraform_version": "1.9.0",
  "serial": 3,
  "lineage": "5d8b2f06-...-c3a7e8d9",
  "outputs": {
    "pet_name": {
      "value": "funny-rabbit",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "random_pet",
      "name": "greeting",
      "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "id": "funny-rabbit",
            "keepers": null,
            "length": 2,
            "prefix": null,
            "separator": "-"
          },
          "sensitive_attributes": []
        }
      ]
    }
  ],
  "check_results": null
}
```

Campos clave:

- **`version`** — formato del state (incrementa cuando Terraform cambia su esquema; migración implícita).
- **`terraform_version`** — binario que *escribió* este state. Un binario más viejo que el que lo escribió se niega a tocarlo.
- **`serial`** — número que incrementa en cada escritura. Permite detectar escrituras concurrentes.
- **`lineage`** — UUID generado al crear el state. **Dos estados del "mismo stack" deben compartir lineage**. Si no coinciden, Terraform asume que son stacks diferentes y rehúsa fusionarlos (defensa contra apuntar al backend equivocado).
- **`resources[]`** — por recurso: `mode` (`managed` vs `data`), `type`, `name`, `provider`, y uno o varios `instances` (uno por default; varios cuando usas `count`/`for_each`).
- **`instances[].attributes`** — lo computado y lo declarado, serializado como JSON. **Aquí viven los valores en claro.**
- **`sensitive_attributes`** — array con las *rutas* de los atributos marcados sensibles. No es cifrado — es señalización.

El state **no se edita a mano**. Para toda operación hay un comando (`terraform state ...`) o un bloque HCL (`moved`, `removed`, `import`).

### 4.2 La fase de *refresh*

Cuando corres `terraform plan`, Terraform hace tres cosas en orden:

1. **Lee el state local** (o lo descarga del backend remoto si lo hay).
2. **Refresca** — para cada recurso del state, llama al provider para re-leer sus atributos. Esto actualiza el state en memoria (y lo persiste si el plan termina en apply). Esta fase es la que detecta **drift**: si la cloud ya no coincide con lo que el state recordaba, Terraform marca el cambio.
3. **Diffea** — compara el state refrescado contra el HCL. Produce el plan.

Antes se podía ejecutar `terraform refresh` como comando separado; en versiones modernas está **implícito en `plan`** (y `apply`) y como comando aislado está **deprecated**. Puedes desactivarlo con `terraform plan -refresh=false` para ganar velocidad (recomendable en apply guardado tras un plan reciente), pero **ocultas drift**: estás diciendo "confía en el state, no preguntes al cloud". Para operar grandes stacks hay un modo intermedio: `terraform plan -refresh-only` (solo refresca y muestra las diferencias detectadas; no propone cambios al HCL) — se cubre en `tf-10`.

### 4.3 El mapeo *address → recurso*

Cada recurso del state tiene una **address** única construida a partir del HCL:

```
module.<mod>.random_pet.greeting
module.<mod>.random_pet.greeting[0]        # con count
module.<mod>.random_pet.greeting["prod"]   # con for_each
```

Esa address es la **identidad lógica** del recurso para Terraform. Si en el HCL renombras `random_pet.greeting` a `random_pet.welcome` **sin tocar el state**, Terraform ve dos cambios simultáneos:

- Address `random_pet.greeting` ya no está en el HCL → **destroy**.
- Address `random_pet.welcome` está en el HCL pero no en el state → **create**.

Resultado: *destroy + create*, aunque el recurso real sea exactamente el mismo. En un `random_pet` eso es inocuo; en una instancia EC2 o una base de datos de prod es un incidente. La solución quirúrgica es **`terraform state mv`**:

```bash
terraform state mv random_pet.greeting random_pet.welcome
```

Esto cambia la address dentro del state sin tocar el recurso real. Luego `terraform plan` → *no changes*. (En versiones modernas se prefiere un bloque `moved {}` en el HCL, declarativo y versionable; cubierto en `tf-09`.)

### 4.4 El state es un conjunto, no un historial

El state representa **la última foto**, no un log. Para historia hay que:

- Usar un backend con **versioning** habilitado (S3 bucket versioned, GCS versioned, etc.).
- O usar un remote backend que lo haga por ti (HCP Terraform/OpenTofu Cloud guarda cada versión).

Si pierdes el state y no tienes versiones, **la única recuperación es `terraform import` recurso por recurso**: Terraform no puede re-inferir el mapeo desde cero. Por eso versioning + locking + encryption + least-privilege son el conjunto mínimo para un backend remoto productivo.

### 4.5 `terraform import` conceptual

Si un recurso **existe en la cloud** pero **no está en el state**, Terraform no lo gestiona. `import` es el puente: le dices "este recurso real corresponde a este bloque HCL" y Terraform lee sus atributos del cloud y los mete en el state. Hay dos formas:

- **CLI** (`terraform import <address> <id>`): imperativo, antiguo, aún útil para one-offs.
- **`import` block** (`import { to = ...; id = ... }`): declarativo, moderno, versionable. Permite generar HCL con `-generate-config-out`.

En este módulo lo tratamos **conceptualmente**. La operación completa — adopción masiva de infra existente — es tema de `tf-14`.

---

## 5. Ejemplo mínimo

Dos ejemplos acompañan esta lección (ver `examples/`). El esqueleto conceptual, ejecutable en 2 minutos:

```bash
mkdir -p /tmp/tf-05-demo && cd /tmp/tf-05-demo

cat > versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}
EOF

cat > main.tf <<'EOF'
resource "random_pet" "greeting" {
  length    = 2
  separator = "-"
}

resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "hola ${random_pet.greeting.id}\n"
}
EOF

terraform init
terraform apply -auto-approve

# Inspeccionar
terraform state list
# random_pet.greeting
# local_file.hello

terraform state show random_pet.greeting
# # random_pet.greeting:
# resource "random_pet" "greeting" {
#     id        = "funny-rabbit"
#     length    = 2
#     separator = "-"
# }

cat terraform.tfstate | head -40
# JSON crudo: version, serial, lineage, resources[]

terraform destroy -auto-approve
rm -rf /tmp/tf-05-demo
```

Lo importante: ver que `state list` lista **addresses**, `state show` imprime el recurso **tal como vive en el state** (no tal como está en el HCL — en ejemplos sencillos coinciden; en recursos con atributos computados, el `show` tiene más campos).

---

## 6. Implementación progresiva

Añadamos complejidad en tres pasos.

### Paso 1 — Renombre en HCL **sin** `state mv` (lo que NO debes hacer)

```hcl
# Antes:
resource "random_pet" "greeting" { length = 2 }

# Después:
resource "random_pet" "welcome"  { length = 2 }
```

```bash
terraform plan
# Plan: 1 to add, 1 to destroy.
#   - random_pet.greeting will be destroyed
#   + random_pet.welcome will be created
```

Si aplicas: pierdes el valor aleatorio original y se genera uno nuevo. En un recurso trivial es *inocuo*. En una base de datos de producción sería un incidente. **Nunca aplicas ciegamente un plan con `-/+`.**

### Paso 2 — Renombre con `terraform state mv`

```bash
# 1) Edita el HCL (greeting → welcome).
# 2) Mueve en el state ANTES del plan:
terraform state mv random_pet.greeting random_pet.welcome
# Move "random_pet.greeting" to "random_pet.welcome"
# Successfully moved 1 object(s).

# 3) Verifica:
terraform plan
# No changes. Your infrastructure matches the configuration.
```

Address cambia, atributos preservados, recurso real intacto.

### Paso 3 — Sacar un recurso del state con `state rm` (dejarlo "en el aire")

```bash
terraform state rm random_pet.welcome
# Removed random_pet.welcome
# Successfully removed 1 resource instance(s).

terraform state list
# (ya no aparece)

# El recurso REAL sigue existiendo (si lo hubiera creado un provider con backend real).
# Para re-adoptarlo: terraform import random_pet.welcome <id>
```

`state rm` es útil cuando: (a) un recurso debe pasar a estar gestionado por **otro** stack (lo quitas del state A y lo importas en el state B), o (b) quieres que Terraform "olvide" un recurso sin destruirlo. En providers reales es la vía para refactorizar la pertenencia sin tocar producción.

---

## 7. Aplicación profesional

En entornos reales, el state es la **superficie operacional crítica** del equipo:

- **Un state por bounded context, no un state monolítico.** Un stack con 400 recursos tiene (a) locks largos, (b) blast radius enorme al corromper, (c) planes lentos. Dividir por: ambiente (dev/stg/prod), capa (red/compute/datos), equipo, o producto. Detalle en `tf-11`.
- **Backend remoto con**: versioning, encryption at-rest, locking, least-privilege (solo quienes operan ese contexto leen/escriben), audit logs.
- **CI/CD** corre Terraform contra el backend remoto, no un dev desde su laptop con credenciales de prod. Los ingenieros solo tocan el state de prod en incidentes documentados.
- **`terraform state pull`** permite inspeccionar un state remoto sin aplicar nada. Útil para debugging. `push` solo en recuperación muy consciente.
- **Prohibido editar a mano.** Si hace falta mutar el state, es a través de `state mv`/`rm`/`import` o bloques `moved`/`removed`/`import`. Nunca `sed`.
- **El state nunca va a Git.** Ni `.tfstate`, ni `.tfstate.backup`, ni `.terraform/` (contiene plugins descargados pesados, cacheables desde el registry). El `.gitignore` canónico:

  ```
  .terraform/
  *.tfstate
  *.tfstate.*
  *.tfvars
  !example.tfvars
  crash.log
  override.tf
  override.tf.json
  *_override.tf
  *_override.tf.json
  ```

### 7.1 Comandos de inspección imprescindibles

```bash
terraform state list                           # addresses
terraform state list -id=<regex>               # filtrar
terraform state show <address>                 # un recurso
terraform state pull > snapshot.json           # bajar state crudo (remoto)
terraform state mv <from> <to>                 # renombrar address
terraform state rm <address>                   # quitar del state (NO destruye)
terraform state replace-provider <old> <new>   # cambiar provider (p. ej. tras rebrand)
```

### 7.2 Qué controles exigir al backend remoto (mínimos)

| Control | Por qué |
|---------|---------|
| Cifrado at-rest | El state contiene valores en claro — es datos sensibles. |
| Versioning | Única vía realista de recuperar un state corrupto o accidentalmente mutado. |
| Locking | Evita escrituras concurrentes que corrompen. |
| Least-privilege IAM | Solo quien debe operar ese contexto lee/escribe. |
| Audit logs | Trazabilidad: quién pulled/pushed cuándo. |
| Separación por ambiente | Blast radius acotado; prod separado de dev con credenciales separadas. |

---

## 8. Trade-offs

### 8.1 Backend local vs remoto

| Dimensión | Local (`terraform.tfstate` en disco) | Remoto (`s3`, `gcs`, `azurerm`, `remote`...) |
|-----------|--------------------------------------|---------------------------------------------|
| Setup | Cero. | Requiere crear bucket/table/cuenta, IAM, etc. |
| Multi-persona | No viable (merge-conflicts, locks ausentes). | Diseñado para esto. |
| Versioning | A mano, poco fiable. | Nativo (si lo habilitas). |
| Locking | Fcntl local (sirve para un solo usuario). | Nativo del backend. |
| Riesgo de pérdida | Alto (si el laptop muere, muere el state). | Bajo (bucket replicado, backups). |
| Cuándo elegirlo | Experimentos, aprendizaje, actividades de este módulo. | **Cualquier equipo real**. |

En este módulo todo es local. En `tf-11` migramos a remoto.

### 8.2 `terraform state mv` vs bloque `moved`

| Dimensión | `terraform state mv` (CLI) | `moved {}` block (HCL) |
|-----------|-----------------------------|-------------------------|
| Lugar | Imperativo, en la terminal. | Declarativo, en el HCL versionado. |
| Trazabilidad | Nula (operación efímera). | Vive en Git como cualquier otro cambio. |
| Reproducibilidad | Cada ingeniero debe correrlo. | Lo corre `apply` solo. |
| Reversible | Hay que acordarse de revertir. | Se borra del HCL cuando ya no aplica. |
| Cuándo elegirlo | Operaciones one-off, estados corruptos, splits de state. | **Refactor normal en equipo** (preferido). |

Este módulo enseña `state mv` porque es el fundamento y lo verás en cualquier runbook histórico. `moved` se cubre en `tf-09`.

### 8.3 Sensitive vs secretos reales

| Mecanismo | Qué hace | Qué **no** hace |
|-----------|----------|------------------|
| `variable "x" { sensitive = true }` | Oculta en logs CLI. | **No** cifra el state. |
| `output "y" { sensitive = true }` | Oculta en `terraform output`. | **No** cifra el state. |
| `data "aws_secretsmanager_secret_version" ...` | Lee el valor en runtime desde un sistema de secretos. | El valor acaba igualmente en el state cuando se referencia. |
| Vault/Secrets Manager + rotación + ACLs | Protege el valor en su sistema de origen. | No evita que, al referenciarlo, aparezca en el state. |

**Regla operacional**: cualquier dato realmente secreto que entre al state **debe ser rotable sin dolor**. Si no es rotable (p. ej. una clave privada única), **no debería estar en el state** (o el state vive en un bucket con los mismos controles que el secreto original).

### 8.4 State encryption nativa (contexto)

**OpenTofu 1.7+** introduce **state encryption nativa** (configuración en el bloque `terraform { encryption {} }`). Terraform (HashiCorp) a 2026 no la tiene como feature general. Esto no reemplaza los controles del backend — es defensa en profundidad. Detalle en `tf-13`.

---

## 9. Errores frecuentes

### 9.1 Subir `terraform.tfstate` a Git

El error más común y más caro. Expone todos los atributos (ARNs, IPs internas, keypairs, outputs sensibles). Si pasa:

1. **Trata todo lo expuesto como comprometido** (rotar contraseñas, revocar claves).
2. Elimina el archivo del historial de Git (`git filter-repo`, cubierto en `gh-10`).
3. Añade el `.gitignore` canónico.
4. Si el repo es público, asume que el archivo ya está indexado y actúa en consecuencia.

### 9.2 Editar `terraform.tfstate` a mano

Fácil de romper (JSON mal formado) y silencioso de corromper (atributos inconsistentes con el schema). Si se detecta, Terraform puede negarse a leer el state o aplicar un plan destructivo "para corregir". **Usa comandos.**

### 9.3 Renombrar en HCL sin `state mv`

Produce `destroy + create`. En recursos stateful (DBs, EBS, EIPs reservadas) es catastrófico. **Nunca apliques un plan con `-/+` sin haber leído por qué.**

### 9.4 `terraform state rm` cuando querías `destroy`

`state rm` quita el recurso del state **pero no lo destruye**. Queda huérfano en la cloud, generando coste, sin gestión. Si querías destruir el recurso real: `terraform destroy -target=<address>` (y aun así, con cuidado — `-target` es un escape hatch).

### 9.5 `plan -refresh=false` en producción

Acelera el plan a costa de **ocultar drift**. En producción el equipo acaba creyendo que todo está en orden hasta que algo falla inexplicablemente. Usar solo con razón explícita (p. ej. aplicar un `plan` guardado hace minutos).

### 9.6 Dos stacks apuntando al mismo state file

Dos directorios con dos HCL distintos leyendo/escribiendo el mismo `terraform.tfstate` → corrupción garantizada. Cada stack debe tener su propio state (local **o** remoto). El `lineage` protege parcialmente (Terraform grita si los lineages no coinciden), pero no impide todos los escenarios.

### 9.7 Confundir `sensitive` con cifrado

Ver §8.3. Marcar `sensitive = true` es **señalización**, no protección criptográfica. Un junior que vea el output oculto en CLI puede asumir "está protegido"; no lo está.

### 9.8 Correr `terraform init` apuntando al backend equivocado

Terraform migrará (o preguntará por migrar) el state al backend que indiques. Si apuntas sin querer al backend de prod y le dices "sí migrar" desde dev, mezclas lineages. La defensa: `terraform init -backend-config=...` por ambiente, y **leer** lo que Terraform propone antes de confirmar.

---

## 10. Buenas prácticas

- **Un state por bounded context.** Dividir temprano cuesta menos que dividir tarde.
- **Backend remoto para cualquier cosa que exista más de una semana.** Local solo para experimentos.
- **`.gitignore` canónico desde el commit 0.** No esperes al día en que subes un `.tfstate` sin querer.
- **`terraform state show <address>`** antes y después de **cualquier** cambio delicado — es gratis y previene incidentes.
- **Nunca editar el state a mano.** Siempre comandos o bloques HCL.
- **`state mv` como ejercicio diario**: refactor sin recrear es parte del oficio.
- **`import` antes de "recrear igual"**: si un recurso existe fuera del state, impórtalo; no lo re-crees con `apply` para que "coincida".
- **Lee `terraform.tfstate` al menos una vez** — para interiorizar que es JSON legible, no magia.
- **Secretos verdaderos viven fuera del state** cuanto puedas; cuando no se puede, trata el state como un secreto más.
- **Documenta tu backend**: cualquier ingeniero de guardia debe saber en 2 minutos dónde vive el state, cómo acceder, cómo liberar un lock colgado.

---

## 11. Ejercicios recomendados

1. **`activities/01-rename-resource-with-state-mv/`** — guided-lab: renombrar un recurso en HCL y usar `terraform state mv` para que el plan quede en no-op. Validador automático.
2. **`activities/02-inspect-state-of-a-provisioned-stack/`** — independent: aprovisionar un stack local, extraer atributos específicos con `terraform state show`, documentarlos en `NOTES.md`. Validador estructural.

Si estas dos están cerradas y entiendes por qué, el módulo está interiorizado.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación oficial. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Marca todo lo que es **verdadero** sobre el state de Terraform:
   - [ ] Guarda, por recurso, los atributos computados por el provider.
   - [ ] Es un formato binario propietario.
   - [ ] Puede ser inspeccionado y editado con `cat`/`vim` sin consecuencias.
   - [ ] Guarda un historial de versiones.
   - [ ] Es necesario porque la API cloud no siempre expone de forma barata y determinista cómo cada recurso real mapea a cada bloque HCL.

**P2.** Explica en 2–3 frases por qué un atributo marcado `sensitive = true` **sigue estando en claro en `terraform.tfstate`**. ¿Qué significa entonces `sensitive`?

**P3.** Tienes un `random_pet` llamado `random_pet.old` en producción. Decides renombrarlo a `random_pet.new`. Describe paso a paso qué haces para que `terraform plan` quede en no-op tras el renombre, y qué pasaría si *solo* editas el HCL y aplicas.

**P4.** Verdadero / falso:
   - [ ] `terraform refresh` es un comando obligatorio antes de cada `plan`.
   - [ ] `terraform plan` refresca el state implícitamente por defecto.
   - [ ] `terraform state rm` destruye el recurso en la cloud.
   - [ ] Dos stacks pueden apuntar sin problemas al mismo archivo `terraform.tfstate` si usan el mismo lineage.

**P5.** Un compañero propone subir `terraform.tfstate` a Git "cifrándolo con GPG antes del commit". Enumera al menos tres razones por las que esto no sustituye a un backend remoto bien configurado.

**P6.** Diseño: para un equipo de 6 ingenieros que operan 3 ambientes (dev, stg, prod), ¿qué configuración mínima pedirías para el/los backend(s)? Enumera los 6 controles críticos y por qué.

**P7.** Enumera 3 situaciones concretas en las que `terraform state rm` es la operación correcta (y qué sigue a continuación).

**P8.** Explica la diferencia entre `terraform import` y `terraform state mv`. ¿Cuándo usarías cada uno?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Terraform docs*, "State" — <https://developer.hashicorp.com/terraform/language/state>
- *Terraform docs*, "Manipulating state" — <https://developer.hashicorp.com/terraform/cli/state>
- *Terraform docs*, "Sensitive values in state" — <https://developer.hashicorp.com/terraform/language/state/sensitive-data>
- *Terraform docs*, "Backends overview" — <https://developer.hashicorp.com/terraform/language/backend>
- *Terraform docs*, "State locking" — <https://developer.hashicorp.com/terraform/language/state/locking>
- *Terraform docs*, "Import" — <https://developer.hashicorp.com/terraform/language/import>
- OpenTofu, "State encryption" — <https://opentofu.org/docs/language/state/encryption/>

Lectura complementaria:

- Chacon-style "mental model": *Pro Terraform* y *Terraform: Up & Running* (Yevgeniy Brikman), capítulos de state.
- HashiCorp blog, "How Terraform state works internally" (buscar la versión vigente).
