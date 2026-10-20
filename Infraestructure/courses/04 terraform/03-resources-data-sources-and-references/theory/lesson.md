# Lección: Resources, data sources y referencias

> **ID:** `tf-03-resources-data-sources-and-references` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `tf-02-setup-hcl-first-provider`.

---

## 1. Introducción intuitiva

En `tf-02` corriste tu primer `init → plan → apply` contra providers "seguros" (`null`, `random`, `local`). El código era casi un juguete: declarabas un `random_pet` y Terraform te devolvía "clever-moth". Divertido, pero no deja ver el **mecanismo central** del lenguaje.

Ese mecanismo es simple de enunciar y profundo en consecuencias: **cuando un recurso referencia un atributo de otro, Terraform aprende que uno depende del otro**. No hay listas de "primero esto, después aquello"; no hay un `main()` que orquesta nada. Hay un conjunto de bloques declarativos y, entre ellos, unas pocas referencias que forman un **grafo**. Ese grafo es el programa.

En este módulo vas a construir stacks con varios recursos, mirarás el grafo, lo leerás en el state, y aprenderás a diferenciar la pieza que Terraform **posee** (un `resource`) de la pieza que Terraform **consulta** (un `data` source). Terminarás sabiendo cuándo escribir `depends_on` — y, más importante, por qué casi nunca deberías hacerlo.

---

## 2. Fundamentos

### 2.1 `resource` — Terraform es dueño del objeto

Un bloque `resource "<tipo>" "<nombre>" { ... }` declara: "este objeto es mío, llévalo al estado que describo aquí". Terraform asume CRUD completo:

- Si no existe → lo **crea** en `apply`.
- Si existe pero divergen los argumentos → lo **actualiza** (in-place o recreándolo, según el provider).
- Si lo quitas del HCL → lo **destruye** en el siguiente `apply`.
- Si lo borras tú por fuera → aparece como "needs to be created again" en el próximo `plan` (drift).

El par `<tipo>.<nombre>` es la **dirección** del recurso. `aws_instance.web`, `tls_private_key.deploy`, `docker_container.app` son direcciones. El `<nombre>` es libre y vive solo en tu HCL — no viaja a la nube. Lo usas para referenciarlo desde otros bloques.

### 2.2 `data` — Terraform solo lee

Un bloque `data "<tipo>" "<nombre>" { ... }` declara: "léeme este objeto del mundo real, no lo gestiono yo". Terraform:

- Lo **consulta** en la fase refresh de cada `plan` (una llamada a la API del provider).
- **Nunca** lo crea, actualiza ni destruye.
- Expone sus atributos como si fueran los de un recurso.

La dirección cambia: `data.<tipo>.<nombre>` (nota el prefijo `data.`). Un `data "aws_ami" "ubuntu"` lee la AMI más reciente de Ubuntu; tú luego referencias `data.aws_ami.ubuntu.id` desde una `aws_instance`.

**¿Cuándo cuál?** Regla práctica: si el objeto lo creas tú con Terraform, es `resource`. Si existe por fuera (lo creó otra herramienta, otro equipo, otra cuenta, o es un dato público como una AMI), es `data`.

### 2.3 Atributos: argumentos vs computados

Dentro de un bloque hay dos clases de atributos:

- **Argumentos** — los que **tú escribes**. Son la entrada al recurso: `name`, `description`, `image`, `visibility`.
- **Computados** — los que **el provider rellena** después de interactuar con la API. Son la salida: `id`, `arn`, `ssh_url`, `created_at`, `fingerprint`, `ip_address`.

Esta distinción no es cosmética: es lo que hace posible el modelo de referencias. Cuando escribes `github_repository.repo.ssh_url`, estás diciendo "quiero el `ssh_url` que GitHub asignará a mi repo después de crearlo". Terraform lo marca en el plan como `(known after apply)` y lo resuelve en el momento correcto durante el walk del grafo.

Un atributo puede ser argumento **y** computado a la vez: por ejemplo, `name` de un recurso puede dejarse en blanco y hacer que el provider lo genere, o escribirlo explícitamente. Los providers documentan esto como "Optional / Computed".

### 2.4 Referencias y el grafo implícito

La magia está aquí. Considera:

```hcl
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "github_repository_deploy_key" "deploy" {
  repository = github_repository.repo.name
  title      = "ci-key"
  key        = tls_private_key.deploy.public_key_openssh
}

resource "github_repository" "repo" {
  name       = "demo"
  visibility = "private"
}
```

Terraform parsea el HCL y detecta tres referencias:

- `github_repository_deploy_key.deploy` → `github_repository.repo.name`
- `github_repository_deploy_key.deploy` → `tls_private_key.deploy.public_key_openssh`

Con eso construye el DAG:

```
       tls_private_key.deploy       github_repository.repo
                   \                       /
                    \                     /
                     v                   v
                  github_repository_deploy_key.deploy
```

Y ejecuta en orden topológico: los dos padres se crean **en paralelo** (son independientes entre sí), luego el hijo. Nadie escribió el orden; emergió de las referencias.

Nota crítica: el orden del HCL **no importa**. Puedes declarar los bloques en cualquier secuencia y Terraform construirá el mismo grafo. Eso suele desconcertar a quien viene de lenguajes imperativos.

### 2.5 `depends_on` — el último recurso, no el primero

A veces hay dependencias que **no** se pueden expresar como referencia porque no hay un atributo que viaje entre los dos recursos. Ejemplos:

- Debes crear una política IAM **antes** de crear un bucket que la asume, pero el bucket no referencia la política directamente — un rol intermedio lo hace.
- Debes esperar a que un paquete esté instalado en un contenedor **antes** de arrancar otro recurso que lo usa a través de la red.
- Dos recursos gestionados por providers distintos tienen una dependencia operacional que no viaja por HCL.

Para esos casos existe `depends_on`:

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "my-logs"
  depends_on = [aws_iam_policy_attachment.logs_writer]
}
```

Añade una arista al grafo: "no crees este recurso hasta que el otro esté completo". **No espera "hasta que esté listo"** en el sentido fuerte (eso lo decide el provider al reportar éxito del create); solo ordena.

Reglas prácticas:

1. **Primero intenta expresarlo por referencia.** Si puedes meter un `aws_iam_policy_attachment.logs_writer.id` en algún atributo del bucket (aunque sea en un tag), ya tienes la dependencia implícita y `depends_on` sobra.
2. **Si de verdad no hay atributo que referenciar**, usa `depends_on` y añade un comentario explicando qué dependencia operacional estás codificando. Sin el comentario, dentro de 6 meses nadie sabrá por qué está ahí.
3. **Si lo usas mucho**, revisa tu diseño. Posiblemente estás ocultando referencias que podrían ser explícitas, o estás acoplando cosas que deberían vivir en módulos distintos.

### 2.6 El state como "lo que Terraform cree que existe"

Cada `apply` graba en el state file (`terraform.tfstate`) los atributos **conocidos** de cada recurso: argumentos escritos y computados devueltos por el provider. En este módulo lo leeremos con:

```bash
terraform state list                  # direcciones de todos los recursos
terraform state show <addr>           # todos los atributos de un recurso
```

El state file es JSON y vive en local por defecto. Es sensible (contiene valores reales — incluyendo, en algunos casos, llaves privadas en claro). En `tf-05` lo tratamos a fondo; aquí basta con saber que es la fuente de verdad operacional de Terraform.

---

## 3. Modelo mental: HCL → DAG → operaciones

```
   .tf files           DAG implícito             operaciones
   ─────────           ─────────────             ──────────
   resource "A" {              A                 create A \
     name = "x"                |                 create B  → parallel
   }                           |                 create C /
                               v                 create D  → espera a A y B
   resource "B" {              B
     name = "y"                |
   }                           |
                               v
   resource "C" {              C
     name = "z"                |
   }                           |
                               v
   resource "D" {              D
     a_id = A.id               /
     b_id = B.id              /
   }
```

Esto es toda la historia. Lo demás (plan, apply, destroy) es Terraform recorriendo este grafo en orden correcto y llamando al provider para cada nodo.

---

## 4. Práctica: una cadena de 3 recursos con `tls`, `github` y una arista implícita

Supongamos que queremos un repo privado en GitHub con una deploy key. La deploy key es la mitad pública de un par RSA que generamos nosotros. Toda la cadena, sin un solo `depends_on`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls    = { source = "hashicorp/tls",     version = "~> 4.0" }
    github = { source = "integrations/github", version = "~> 6.0" }
  }
}

provider "github" {}  # usa GITHUB_TOKEN del entorno

resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "github_repository" "demo" {
  name        = "tf-03-demo"
  description = "Demo repo for tf-03"
  visibility  = "private"
  auto_init   = true
}

resource "github_repository_deploy_key" "demo" {
  title      = "ci-key"
  repository = github_repository.demo.name              # arista implícita
  key        = tls_private_key.deploy.public_key_openssh # arista implícita
  read_only  = true
}
```

Grafo que Terraform construye:

```
    tls_private_key.deploy          github_repository.demo
               \                            /
                v                          v
             github_repository_deploy_key.demo
```

Fíjate: el provider `tls` **no toca la red**. Es puro cálculo en el proceso Terraform. El provider `github` sí llama a `api.github.com`. Ambos participan del mismo DAG; a Terraform le da igual.

### Qué se vería en el state

```
$ terraform state list
github_repository.demo
github_repository_deploy_key.demo
tls_private_key.deploy

$ terraform state show tls_private_key.deploy
# tls_private_key.deploy:
resource "tls_private_key" "deploy" {
    algorithm                     = "RSA"
    ecdsa_curve                   = "P224"
    id                            = "<hash>"
    private_key_openssh           = (sensitive value)
    private_key_pem               = (sensitive value)
    private_key_pem_pkcs8         = (sensitive value)
    public_key_fingerprint_md5    = "aa:bb:..."
    public_key_openssh            = <<-EOT
        ssh-rsa AAAAB3Nz...
    EOT
    public_key_pem                = <<-EOT
        -----BEGIN PUBLIC KEY-----
        ...
    EOT
    rsa_bits                      = 4096
}
```

Observa: `algorithm` y `rsa_bits` son **argumentos** (los escribiste). `id`, `public_key_openssh`, `public_key_pem` son **computados** (los rellenó el provider al "crear" el recurso, aunque en este caso "crear" significa generar la llave en memoria).

---

## 5. Práctica: `docker_image` → `docker_container`

El provider `docker` (kreuzwerker/docker) habla con el daemon local vía el socket Unix. Ejemplo mínimo:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "web" {
  name  = "tf-03-web"
  image = docker_image.nginx.image_id  # arista implícita
  ports {
    internal = 80
    external = 18080
  }
}
```

Grafo:

```
    docker_image.nginx
            |
            v
    docker_container.web
```

Al aplicar:

- `docker_image.nginx` → el provider llama a `dockerd` → pull de la imagen → devuelve el `image_id` (sha256).
- `docker_container.web` → el provider espera a que exista el `image_id` (porque el DAG dice que depende) → create → start.

Al destruir, el orden se **invierte**: primero el contenedor, después la imagen (si `keep_locally = false`). Terraform recorre el DAG al revés.

---

## 6. Un ejemplo donde `depends_on` sí es necesario

Imagina en AWS este escenario simplificado:

```hcl
resource "aws_iam_role" "lambda" {
  name = "lambda-role"
  # ... assume role policy ...
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "app" {
  function_name = "app"
  role          = aws_iam_role.lambda.arn   # arista implícita al rol
  # ... pero NO al attachment ...

  depends_on = [aws_iam_role_policy_attachment.logs]  # <-- necesario
}
```

El `aws_lambda_function` depende del **rol** por referencia (`.arn`), así que Terraform crea el rol antes. Pero **no** referencia el `aws_iam_role_policy_attachment` — no hay ningún atributo del attachment que viaje al lambda. Y sin embargo, si el lambda arranca antes de que el attachment esté creado, el primer invocation falla al intentar escribir a CloudWatch Logs porque el rol todavía no tiene esa política.

Esto es exactamente lo que `depends_on` resuelve: añade la arista `attachment → lambda` al grafo sin tener que inventar un atributo artificial. Y lo documentamos con comentario:

```hcl
# depends_on necesario: el rol se crea OK sin el attachment, pero el lambda
# requiere la policy adjunta la primera vez que escribe logs. Sin esta arista
# el apply tiene race: el attachment puede terminar DESPUÉS del lambda.
depends_on = [aws_iam_role_policy_attachment.logs]
```

Este es el patrón: *dependencia operacional lateral que no viaja como atributo*.

---

## 7. Un `depends_on` redundante (el *code smell*)

Compara con esto:

```hcl
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
}

resource "github_repository_deploy_key" "demo" {
  repository = "my-repo"
  title      = "ci"
  key        = tls_private_key.deploy.public_key_openssh
  depends_on = [tls_private_key.deploy]  # <-- REDUNDANTE
}
```

El `key = tls_private_key.deploy.public_key_openssh` **ya** crea la arista implícita. Añadir `depends_on` a la misma dependencia no añade nada: el grafo ya la tiene. Es ruido visual que confunde a quien lee el código ("¿por qué está esto aquí? ¿me falta un contexto?").

Regla: `depends_on` **solo** para dependencias que no se pueden expresar por referencia. Si puedes borrar el `depends_on` y nada cambia en el grafo, bórralo.

---

## 8. Visualizar el DAG con `terraform graph`

Terraform expone el grafo como DOT. En un stack ya inicializado:

```bash
terraform graph > graph.dot
# Opción A: renderizar con graphviz si lo tienes.
dot -Tpng graph.dot -o graph.png
# Opción B: pegar el contenido de graph.dot en https://dreampuf.github.io/GraphvizOnline
```

El DOT incluye nodos por recurso, por provider y por fase (`root`, `expand`, etc.). Para enseñar basta con mirar los nodos `*_resource` y sus aristas; lo demás es maquinaria interna del algoritmo.

Un formato ASCII equivalente (lo verás así en las actividades) sería:

```
+-------------------+       +---------------------+
| tls_private_key   |       | github_repository   |
|   .deploy         |       |   .demo             |
+-------------------+       +---------------------+
         \                            /
          \                          /
           v                        v
         +----------------------------+
         | github_repository_         |
         |   deploy_key.demo          |
         +----------------------------+
```

---

## 9. Diferencias finas y errores comunes

### 9.1 "Variable" vs "argumento" vs "atributo"

- **Variable** (`variable "x" {}`): entrada parametrizada al stack entero. Se verá en `tf-04`.
- **Argumento**: campo que escribes dentro de un bloque (`name`, `visibility`).
- **Atributo**: cualquier campo del bloque, incluidos los computados.

En conversación se usan intercambiablemente, pero cuando lees documentación oficial los distinguen: "Arguments" (los que puedes escribir) y "Attributes Reference" (los que puedes leer, incluidos los `Computed`).

### 9.2 `data` dentro de un ciclo lógico

```hcl
resource "github_repository" "demo" {
  name = "x"
}

data "github_repository" "demo_read" {
  name = github_repository.demo.name   # ← ciclo lógico subyacente
}
```

Aquí Terraform **sí** sabe resolverlo (porque el `data` lee después de que el `resource` se haya creado), pero es un anti-patrón: ya tienes el objeto, no necesitas releerlo. Usa directamente los atributos de `github_repository.demo`.

El caso límite patológico es:

```hcl
data "github_repository" "x" {
  name = github_repository.x.name
}
resource "github_repository" "x" {
  name = data.github_repository.x.id   # <-- ciclo real
}
```

Esto da un ciclo en el grafo y Terraform aborta el plan con "Cycle detected".

### 9.3 Un `data` que depende de otro `resource` del stack

```hcl
resource "aws_vpc" "main" { ... }

data "aws_subnet_ids" "all" {
  vpc_id = aws_vpc.main.id   # ← esperará a que la VPC exista
}
```

Esto **sí** es legítimo (y común en código real): el `data` se refresca después del create de la VPC. Terraform marca el `data` como "known after apply" en el plan y lo lee tras crear el padre.

### 9.4 Olvidar que `data` se refresca en cada `plan`

Si tu `data` llama a una API cara/lenta, cada `plan` paga ese coste. Para datos estables puedes mover la llamada a `locals` tras una lectura explícita, o cachear por fuera. Es raro en `tls`/`docker`/`github`; es común con `aws_ami` cuando buscas la más reciente.

---

## 10. Leer el state tras un `apply`

Tras aplicar el ejemplo de `docker`:

```bash
$ terraform state list
docker_container.web
docker_image.nginx

$ terraform state show docker_container.web | head -20
# docker_container.web:
resource "docker_container" "web" {
    attach            = false
    bridge            = null
    container_logs    = null
    entrypoint        = ["/docker-entrypoint.sh"]
    env               = []
    hostname          = "a7f3d1c2..."
    id                = "a7f3d1c2b4e5..."
    image             = "sha256:..."
    init              = false
    ip_address        = "172.17.0.2"
    log_driver        = "json-file"
    must_run          = true
    name              = "tf-03-web"
    network_data = [{ ... }]
    ...
}
```

Fíjate en lo que **no** escribiste:

- `bridge`, `container_logs`, `entrypoint`, `hostname`, `id`, `image`, `ip_address`, `log_driver`, `network_data`...

Todo eso lo rellenó el provider (parte lo lee del daemon tras el create, parte son defaults). El state es, literalmente, lo que Terraform aprendió del mundo real al crear el recurso.

Pregunta útil para interiorizar: si Terraform **no** guardara `id`, ¿qué pasaría? Respuesta: en el siguiente `apply` no sabría a qué objeto se refiere `docker_container.web`, lo trataría como nuevo y crearía un segundo contenedor. **El state existe fundamentalmente para resolver esa correspondencia.**

---

## 11. Trade-offs y señales de alarma

- **Preferir referencias explícitas** sobre `depends_on`: aristas tipadas que viven en el código, se refactorizan solas, se renombran con `moved` (tf-09).
- **Preferir `resource` sobre `data`** para objetos que creas tú: tener un `data "github_repository" "x"` sobre un repo que creas en el mismo stack es señal de un diseño enredado.
- **Si un bloque tiene 5 `depends_on`**, probablemente modela mal: separa en módulos o reorganiza las aristas.
- **Si un `plan` muestra `(known after apply)` en muchos sitios**, no te asustes: significa que el valor depende de algo que aún no se ha creado. Al apply se resuelven.
- **Si un `plan` muestra `-/+` destroy+create por un cambio trivial**, el atributo que tocaste es "ForceNew" en el provider. Documentado en el provider; lo trataremos en `tf-09` con `create_before_destroy` y `lifecycle`.

---

## 12. Resumen operacional (lo que debes poder hacer mañana)

Al terminar este módulo deberías poder, sin consultar docs:

1. Escribir un bloque `resource` y uno `data` del mismo tipo y explicar la diferencia semántica.
2. Dado un fragmento de HCL de 3 recursos, dibujar el DAG implícito en 30 segundos.
3. Diferenciar un atributo "argumento" de uno "computado" leyendo la documentación de un provider.
4. Justificar la ausencia de `depends_on` ("todas las dependencias son por referencia") o su presencia ("esta dependencia operacional no viaja como atributo porque...").
5. Ejecutar `terraform state list` y `terraform state show` sobre un stack recién aplicado y señalar qué atributos escribiste tú y cuáles rellenó el provider.
6. Diagnosticar un plan donde `(known after apply)` desconcierta a alguien junior: explicar que no es un error, es una promesa.

Si puedes hacer todo lo anterior, estás listo para `tf-04` (variables, outputs, locals) y para pasar después a `tf-05` (state a fondo).
