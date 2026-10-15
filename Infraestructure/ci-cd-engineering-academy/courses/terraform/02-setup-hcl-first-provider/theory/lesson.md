# tf-02 — Lección: Instalación, HCL y primer provider

> 12 secciones. Lee entera antes de hacer las actividades. El código es intencionalmente mínimo: la densidad está en explicar **por qué** cada pieza existe.

---

## 1. Dónde encaja este módulo

En `tf-01` establecimos el modelo mental: Terraform es declarativo, mantiene un *state* de lo real conocido, construye un *plan* comparando estado deseado contra state, y lo aplica llamando a *providers*. Hasta aquí todo fue pizarra. Este módulo baja al terminal.

El objetivo es doble:

1. **Instalar** Terraform y verificar que funciona.
2. **Correr el ciclo** `init → fmt → validate → plan → apply → destroy` sobre un stack mínimo, usando **providers didácticos** que no cuestan dinero ni requieren credenciales.

Los providers que usaremos son los que la comunidad llama "seguros" o "didácticos":

- `hashicorp/null` — recurso `null_resource`, no hace nada por sí mismo, útil para enseñar.
- `hashicorp/random` — genera strings, enteros, UUIDs, nombres de mascota aleatorios.
- `hashicorp/local` — lee y escribe archivos del sistema de archivos local.
- `hashicorp/http` — hace peticiones HTTP GET como `data source`.

Ninguno de los cuatro habla con cloud ni requiere `AWS_PROFILE`, `GOOGLE_CREDENTIALS`, etc. Son el *playground* ideal para el ciclo.

---

## 2. Instalación

### 2.1 Opciones

Hay tres caminos razonables. Elige uno y sé consistente.

**Opción A — Binario oficial.** Descomprimes un zip y pones `terraform` en el `PATH`. Simple, sin dependencias.

- Linux: `wget https://releases.hashicorp.com/terraform/<version>/terraform_<version>_linux_amd64.zip && unzip ... && sudo mv terraform /usr/local/bin/`.
- macOS Homebrew: `brew install terraform` (desde el tap `hashicorp/tap` tras el cambio de licencia BUSL; `brew` lo gestiona por ti).
- Windows: `choco install terraform` o descargar el zip y poner el binario en una carpeta del `PATH`.

**Opción B — `tfenv`** (recomendado si vas a trabajar con varios proyectos).

```
brew install tfenv            # macOS
# o: git clone https://github.com/tfutils/tfenv ~/.tfenv  &&  export PATH="$HOME/.tfenv/bin:$PATH"

tfenv install latest
tfenv use latest
tfenv list
```

Con `tfenv` cada proyecto puede fijar su versión escribiendo un archivo `.terraform-version` con el número exacto. Al entrar al directorio, `tfenv` selecciona esa versión automáticamente.

**Opción C — `asdf`** (si ya usas `asdf` para `node`, `python`, etc.).

```
asdf plugin add terraform
asdf install terraform latest
asdf global terraform latest
```

Igual que `tfenv`, lee `.tool-versions` por proyecto.

### 2.2 Verificación

```
$ terraform version
Terraform v1.9.5
on darwin_arm64
```

Necesitamos **≥ 1.5** para que todo el curso funcione (varias features modernas: `import` blocks, `removed` blocks, etc.).

Nota de licencia: desde agosto 2023 las releases de HashiCorp están bajo **BUSL**. Para uso no competitivo (lo tuyo, lo nuestro) es equivalente a Apache 2.0 en la práctica. En `tf-13` compararemos con **OpenTofu**, el fork comunitario Apache 2.0.

---

## 3. Estructura mínima de un proyecto

Un *root module* en Terraform es, operativamente, **un directorio**. Terraform concatena *todos* los archivos `*.tf` del directorio y los parsea como una unidad. El nombre del archivo es puramente organizativo.

La convención del ecosistema es:

```
mi-stack/
├── versions.tf        # terraform { required_version, required_providers }
├── providers.tf       # provider "x" { ... } (configuración)
├── main.tf            # resource "..." "..." { ... }
├── variables.tf       # variable "..." { ... }      (lo veremos en tf-04)
├── outputs.tf         # output "..." { value = ... } (lo veremos en tf-04)
├── terraform.tfvars   # NO va a Git
├── .terraform.lock.hcl  # SÍ va a Git
├── .terraform/        # NO va a Git (generado por init)
└── terraform.tfstate  # NO va a Git (generado por apply)
```

Un archivo mínimo viable es literalmente:

```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "name" {
  length = 2
}
```

Un solo archivo, un bloque `terraform`, un bloque `resource`. Todo lo demás es opcional en esta etapa.

---

## 4. `required_providers` y el lockfile

### 4.1 `required_providers`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
```

- **`required_version`** → restringe la versión del binario `terraform` (del *core*).
- **`required_providers`** → declara el *source address* y las restricciones de versión de cada provider. El nombre a la izquierda (`random`, `local`) es el **local name**: así te referirás al provider en el resto del código.
- **Operadores de versión** más usados:
  - `= 3.6.0` exacta.
  - `>= 3.6.0` al menos.
  - `~> 3.6` cualquier `3.x` donde `x >= 6` (pessimistic: fija el major, permite minor+patch).
  - `~> 3.6.0` cualquier `3.6.x` (fija minor, permite solo patch).

### 4.2 El lockfile

Tras `terraform init`, Terraform crea `.terraform.lock.hcl`. Un fragmento real:

```hcl
provider "registry.terraform.io/hashicorp/random" {
  version     = "3.6.3"
  constraints = "~> 3.6"
  hashes = [
    "h1:zG9uFP8l9u+yGZZvi5Te7PV62j50azpgwPunq2vTm1E=",
    "zh:04ceb65210251339f07cd4611885d242cd4d0c7306e86dda9785396887e27d2f",
    ...
  ]
}
```

Qué significa cada campo:

- **`version`** — la **versión exacta** resuelta a partir de tus `version` constraints en el momento del `init`. En el ejemplo: `~> 3.6` resolvió a `3.6.3`.
- **`constraints`** — las restricciones que escribiste en `required_providers`. Es informativo.
- **`hashes`** — SHA256s del zip del provider. El `h1:` es el hash "oficial" nuevo; los `zh:` son hashes por plataforma (`linux_amd64`, `darwin_arm64`, etc.) heredados del formato antiguo.

### 4.3 Qué fija el lockfile y qué no

**Fija**:

- La **versión exacta** del provider que se usará en próximos `init` (si existe esa versión en el registry).
- Los **hashes** que esa versión debe tener; si el zip descargado no coincide, `init` falla. Esto detecta corrupción y potencial MITM.

**No fija**:

- La versión de Terraform core (eso lo hace `required_version`).
- Nada del state.
- Las versiones de binarios externos invocados por `provisioner "local-exec"`.
- La versión de los módulos (eso lo fija el `version` dentro de `module "x" {}`).

Si cambias un `version` en `required_providers`, `init -upgrade` reescribe el lockfile. Si no haces `-upgrade`, `init` respeta el lockfile aunque las constraints permitieran una versión más nueva.

**El lockfile se commitea.** `.terraform/` no.

---

## 5. El ciclo: `init → fmt → validate → plan → apply → destroy`

### 5.1 `terraform init`

Prepara el directorio. Hace:

1. Lee `terraform { required_providers { ... } }`.
2. Resuelve versiones usando tus constraints y, si existe, el lockfile.
3. Descarga cada provider a `.terraform/providers/<registry>/<ns>/<name>/<version>/<platform>/`.
4. Escribe/actualiza `.terraform.lock.hcl`.
5. Inicializa el backend (local por default; lo veremos a fondo en `tf-11`).
6. Descarga módulos (`tf-06`).

Idempotente: puedes correrlo varias veces. Con `-upgrade` recalcula versiones y reescribe hashes.

### 5.2 `terraform fmt`

Canonicaliza indentación y espaciado. Es un formatter, no un linter: no cambia semántica.

```
terraform fmt           # formatea el directorio actual (modifica archivos)
terraform fmt -check    # exit 1 si hay archivos sin formatear (ideal para CI)
terraform fmt -recursive
```

### 5.3 `terraform validate`

Chequeo **offline**: sintaxis HCL + que todas las referencias cierren + que los tipos de atributos sean razonables según el schema del provider.

- **No habla con providers.**
- **No lee el state.**
- **No refresca nada.**

Es extremadamente rápido. Falla con mensajes como "unknown resource type", "argument X is required", "reference to undeclared resource".

### 5.4 `terraform plan`

El corazón del ciclo:

1. **Refresh**: consulta a los providers para re-leer atributos reales de los recursos que están en el state.
2. **Build graph**: construye el DAG a partir de las referencias.
3. **Diff**: compara estado deseado (tu HCL + variables) contra state (ya refrescado).
4. **Emite el plan**: operaciones `+` (create), `-` (destroy), `~` (update in-place), `-/+` (replace: destroy + create).

Con `-out=plan.tfplan` serializa el plan a un archivo que `apply` puede ejecutar tal cual, sin recalcular (importante para CI: evita TOCTOU — Time Of Check vs Time Of Use — entre plan y apply).

### 5.5 `terraform apply`

Ejecuta el plan. Dos modos:

- `terraform apply` — recalcula el plan, lo muestra y pide confirmación interactiva.
- `terraform apply plan.tfplan` — ejecuta un plan previamente guardado, sin preguntar.
- `terraform apply -auto-approve` — ejecuta sin confirmar. **No lo uses en prod sin un gate externo** (una pipeline con approval, por ejemplo).

Durante el apply, Terraform:

1. Camina el grafo en orden topológico (operaciones independientes van en paralelo; default `--parallelism=10`).
2. Para cada operación: llama al método correspondiente del provider (`Create`, `Update`, `Delete`).
3. Actualiza el state después de cada operación (si el apply muere a la mitad, el state refleja lo que sí se aplicó).

### 5.6 `terraform destroy`

Es equivalente a `terraform apply -destroy`: calcula un plan donde todos los recursos son `-` y lo aplica. En el laboratorio **siempre** cerramos con `destroy` para no dejar basura.

---

## 6. Sintaxis HCL — lo mínimo imprescindible

### 6.1 Bloques

Forma general:

```
TIPO "LABEL1" "LABEL2" {
  atributo = valor
  bloque_anidado {
    ...
  }
}
```

Ejemplos:

```hcl
terraform { ... }                       # 0 labels
provider "random" { ... }               # 1 label
resource "random_pet" "name" { ... }    # 2 labels
module "vpc" { ... }                    # 1 label
output "pet" { ... }                    # 1 label
```

### 6.2 Atributos y tipos

```hcl
# string
greeting = "hola"

# number
length = 3

# bool
enabled = true

# list / tuple
tags = ["dev", "team-a"]

# map / object
labels = {
  env  = "dev"
  team = "a"
}

# null
owner = null
```

### 6.3 Strings con interpolación

```hcl
# "${expr}" inyecta el valor de una expresión HCL
filename = "/tmp/${random_pet.name.id}.txt"

# también funcionan funciones:
greeting = "Hola, ${upper(var.name)}!"
```

Cuando una expresión es toda la cadena, suele preferirse omitir las comillas y el `${}`:

```hcl
# verboso
name = "${random_pet.name.id}"

# idiomático
name = random_pet.name.id
```

### 6.4 Heredocs

Para strings multilínea:

```hcl
content = <<EOT
primera línea
segunda línea
EOT

# versión indented: elimina la indentación común
content = <<-EOT
    primera línea
    segunda línea
  EOT
```

El marcador (`EOT`, `EOF`, etc.) es arbitrario; solo debe no aparecer en el contenido.

### 6.5 Comentarios

```hcl
# comentario de línea (preferido)
// también de línea
/* bloque
   multilínea */
```

### 6.6 Referencias

- A un recurso: `TIPO.NOMBRE.ATRIBUTO` → `random_pet.name.id`.
- A una variable: `var.NOMBRE`.
- A un local: `local.NOMBRE`.
- A un data source: `data.TIPO.NOMBRE.ATRIBUTO`.
- A un módulo: `module.NOMBRE.OUTPUT`.

Las referencias **crean dependencias implícitas** en el grafo. Esto es central: lo veremos en `tf-03`.

---

## 7. Los cuatro providers didácticos

### 7.1 `hashicorp/null`

```hcl
resource "null_resource" "boot" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'hola desde Terraform'"
  }
}
```

- No crea nada real. Útil para enseñar `triggers`, `provisioner`, y para orquestar comandos como *último recurso*.
- Advertencia: los `provisioner` son considerados anti-patrón en TF moderno; se usan como escape hatch, no como herramienta primaria.

### 7.2 `hashicorp/random`

```hcl
resource "random_pet" "name" {
  length    = 2
  separator = "-"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_id" "nonce" {
  byte_length = 4
}
```

- Genera valores *determinísticos* respecto a su `keeper` (si cambia un keeper, se recalcula). Sin keepers, se calculan una vez al crear y se preservan en el state.
- No usa red; es puramente local.

### 7.3 `hashicorp/local`

```hcl
resource "local_file" "greeting" {
  filename        = "${path.module}/hello.txt"
  content         = "hola ${random_pet.name.id}\n"
  file_permission = "0644"
}

data "local_file" "readme" {
  filename = "${path.module}/README.md"
}
```

- `resource "local_file"` crea un archivo real en disco; `destroy` lo elimina.
- `data "local_file"` lee un archivo existente (sin modificarlo).
- Hay también `local_sensitive_file` para marcar el contenido como sensible (no se muestra en el plan).

### 7.4 `hashicorp/http`

```hcl
data "http" "example" {
  url = "https://checkip.amazonaws.com/"
  request_headers = {
    Accept = "text/plain"
  }
}

output "mi_ip" {
  value = trimspace(data.http.example.response_body)
}
```

- Solo *data source*: hace GET y expone `response_body`, `status_code`, `response_headers`.
- Útil para traer configuración pública, verificar un servicio, obtener IP pública, etc.
- Es la única puerta de red de este módulo.

---

## 8. `.gitignore` y por qué

```
# .gitignore para proyectos Terraform
.terraform/
.terraform.lock.hcl.backup

# State — nunca a Git
*.tfstate
*.tfstate.*
*.tfstate.backup

# Variables sensibles — nunca a Git
*.tfvars
*.tfvars.json
!example.tfvars              # excepto plantillas públicas

# Plans guardados — binario, útil solo para una CI
*.tfplan
crash.log
crash.*.log

# Overrides locales
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

**Lo que SÍ se commitea**:

- `*.tf` (código).
- `.terraform.lock.hcl` (reproducibilidad del provider).
- `example.tfvars` o `terraform.tfvars.example` (plantilla sin secretos).
- `README.md`, docs, diagramas.

**Lo que NUNCA se commitea**:

- `.terraform/` — pesa megas, es específico de plataforma, se regenera con `init`.
- `terraform.tfstate` — contiene valores reales, posibles secretos.
- `*.tfvars` — suele contener secretos en forma de variables.
- `*.tfplan` — binario, válido solo para un instante.

---

## 9. Internals: qué hay en `.terraform/` tras `init`

```
.terraform/
├── providers/
│   └── registry.terraform.io/
│       └── hashicorp/
│           ├── random/
│           │   └── 3.6.3/
│           │       └── darwin_arm64/
│           │           └── terraform-provider-random_v3.6.3_x5
│           └── local/
│               └── 2.5.1/
│                   └── darwin_arm64/
│                       └── terraform-provider-local_v2.5.1_x5
└── environment              # workspace actual (default: "default")
```

Es un *cache* de providers. Si lo borras y haces `init`, Terraform lo reconstruye desde el registry — y validará los hashes del lockfile.

Si tienes backend remoto, aparecerá además un `terraform.tfstate` *dentro de `.terraform/`* que es solo el **puntero al backend** (no el state en sí). El state de verdad vive en S3/GCS/etc.

---

## 10. Internals: por qué `tfstate` nunca va a Git

Un state (JSON) real contiene algo así:

```json
{
  "version": 4,
  "terraform_version": "1.9.5",
  "serial": 7,
  "lineage": "a1b2c3...-...",
  "resources": [
    {
      "mode": "managed",
      "type": "random_password",
      "name": "db",
      "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "length": 24,
            "result": "aXG!zz9!...ESTE-ES-EL-PASSWORD-EN-CLARO",
            "special": true
          },
          "sensitive_attributes": [["result"]]
        }
      ]
    }
  ]
}
```

- El password está **en claro** en el state, aunque `sensitive_attributes` lo oculte en la CLI.
- Commitearlo a Git = filtrarlo.
- Además: cualquier merge/conflict/rebase sobre el state rompe la correspondencia entre código y realidad y suele requerir cirugía manual.

**Solución en equipos**: backend remoto (S3, GCS, Azure Blob, HTTP, HCP Terraform) con locking. Lo veremos en `tf-11`.

---

## 11. Troubleshooting rápido

| Síntoma | Causa típica | Qué hacer |
|---|---|---|
| `Error: Could not retrieve the list of available versions for provider ...` | Red / registry caído / typo en `source` | Revisar `source = "hashicorp/random"` exacto; probar `terraform init -upgrade` |
| `Error: Failed to install provider: checksum mismatch` | Alguien manipuló el lockfile o el zip | Borrar `.terraform.lock.hcl` **con cuidado** y re-`init`; investigar por qué cambió |
| `Error: Reference to undeclared resource` | Typo o resource no definido | `terraform validate` suele señalar línea exacta |
| `terraform plan` dice "no changes" pero sabes que cambió algo en la nube | No es drift, es que estás mirando el stack equivocado | Verifica directorio, workspace, backend |
| `apply` quedó colgado y no termina | API lenta o deadlock del provider | `Ctrl-C` manda `SIGINT` → se intenta cancelar limpio; segundo `Ctrl-C` fuerza. Revisar state después |

---

## 12. Preguntas de evaluación

Responde sin consultar la lección. Si fallas una, releer la sección correspondiente.

1. ¿Qué fija exactamente `.terraform.lock.hcl` y qué no fija? Da tres cosas que **no** fija.
2. ¿Qué diferencia hay entre `terraform validate` y `terraform plan` en términos de qué recursos consultan?
3. En un `required_providers` escribes `version = "~> 4.2"`. ¿Qué versiones acepta? ¿Y con `~> 4.2.0`?
4. Describe qué pasa, paso a paso, cuando corres `terraform init` por primera vez en un directorio con un `main.tf` que declara `hashicorp/random`.
5. ¿Qué contiene exactamente `.terraform/` tras `init`? ¿Por qué no se commitea?
6. ¿Por qué `terraform.tfstate` no debe ir a Git? Cita dos razones independientes.
7. ¿Qué significa `-/+` en la salida de `terraform plan`? ¿En qué se diferencia de `~`?
8. ¿Para qué sirve `terraform plan -out=plan.tfplan` en un pipeline de CI? ¿Qué problema evita?
9. ¿Por qué `provisioner "local-exec"` se considera "último recurso" en Terraform moderno?
10. Si borras el directorio `.terraform/` y vuelves a correr `init`, ¿qué se re-descarga y qué se preserva?
