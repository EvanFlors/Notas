# Ejemplo 01 — Repo de GitHub con deploy key TLS

## Concepto que demuestra

- Cadena de **3 recursos** con dependencias **todas implícitas** (ninguna necesita `depends_on`).
- Combinación de un provider puro-HCL (`tls`) con un provider SaaS (`github`): mismo grafo, mismo modelo mental.
- Lectura del state para distinguir **argumentos** (lo que escribiste) de **computados** (lo que rellenó el provider).

## Contexto

Queremos crear un repo privado en GitHub y asociarle una **deploy key** (clave pública SSH con acceso de lectura al repo, típicamente para que un runner de CI haga `git clone`). La parte privada se queda en nuestro control. Para generar el par de llaves sin depender de `ssh-keygen` externo, usamos el provider `tls`.

El stack final:

```
    tls_private_key.deploy          github_repository.demo
               \                            /
                v                          v
             github_repository_deploy_key.demo
```

## Objetivo

Al terminar sabrás:

- Escribir una cadena de 3 recursos con dependencias implícitas.
- Entender por qué el provider `tls` **no toca la red** y aun así participa del grafo igual que los demás.
- Interpretar los campos `(known after apply)` en el plan.
- Localizar en el state qué atributos escribiste y cuáles rellenó cada provider.

## Prerrequisitos

- `terraform` >= 1.5.
- Variable de entorno `GITHUB_TOKEN` con un **personal access token** con scope `repo` (sólo si vas a aplicar contra GitHub real; si solo haces `init` + `validate`, no hace falta).
- Sin coste (los repos privados son gratuitos en cuentas personales).

> **Importante:** este ejemplo es para **leer y entender**. Si lo aplicas de verdad, estás creando y luego borrando un repo en tu cuenta de GitHub. No se requiere ejecutarlo para completar el módulo; la actividad 01 usa un stack `tls` + `docker` que no sale a Internet.

## Código

Guarda esto en un directorio limpio como `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# El provider github usa GITHUB_TOKEN del entorno.
provider "github" {}

# --- Recurso 1: par de llaves generado localmente, sin red. ---
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- Recurso 2: repo privado en GitHub. ---
resource "github_repository" "demo" {
  name        = "tf-03-demo"
  description = "Demo repo for tf-03 (safe to delete)"
  visibility  = "private"
  auto_init   = true
}

# --- Recurso 3: deploy key que ata los dos anteriores. ---
resource "github_repository_deploy_key" "demo" {
  title      = "ci-key"
  repository = github_repository.demo.name                # arista implícita
  key        = tls_private_key.deploy.public_key_openssh  # arista implícita
  read_only  = true
}

# Salida para inspección rápida.
output "deploy_key_fingerprint" {
  value = tls_private_key.deploy.public_key_fingerprint_md5
}
```

## Ejecución (lectura dirigida)

Aunque no apliques, haz al menos `init` y `plan` para ver el grafo:

```bash
mkdir -p /tmp/tf-03-ex01 && cd /tmp/tf-03-ex01
# ... copia aquí el main.tf de arriba ...

terraform init
#   Descarga los providers tls y github a .terraform/providers/
#   Escribe el lockfile .terraform.lock.hcl con los hashes.

terraform validate
#   Valida sintaxis y referencias. OK => el DAG es construible.

terraform plan
#   Verás algo así (abreviado):
#
#   # github_repository.demo will be created
#     + id       = (known after apply)
#     + name     = "tf-03-demo"
#     + ssh_url  = (known after apply)
#
#   # github_repository_deploy_key.demo will be created
#     + id         = (known after apply)
#     + key        = (known after apply)        # <-- depende de tls_private_key
#     + repository = (known after apply)        # <-- depende de github_repository
#     + title      = "ci-key"
#
#   # tls_private_key.deploy will be created
#     + id                  = (known after apply)
#     + algorithm           = "RSA"
#     + public_key_openssh  = (known after apply)
#     + private_key_pem     = (sensitive value)
#     + rsa_bits            = 4096
#
#   Plan: 3 to add, 0 to change, 0 to destroy.
```

Observa:

- Los **argumentos** aparecen con su valor literal (`"RSA"`, `4096`, `"tf-03-demo"`).
- Los **computados** aparecen como `(known after apply)` o `(sensitive value)`.
- No hay un solo `depends_on` en el código y, aun así, el orden de creación está completamente determinado por las referencias.

### Visualizar el DAG

```bash
terraform graph > graph.dot
# Si tienes graphviz:
dot -Tpng graph.dot -o graph.png
# Si no, pega el contenido de graph.dot en https://dreampuf.github.io/GraphvizOnline
```

Debes ver algo parecido a:

```
    [root]
       |
       v
    [tls_private_key.deploy]   [github_repository.demo]
              \                        /
               v                      v
           [github_repository_deploy_key.demo]
```

### Si aplicas

```bash
export GITHUB_TOKEN="ghp_...."
terraform apply -auto-approve

terraform state list
# github_repository.demo
# github_repository_deploy_key.demo
# tls_private_key.deploy

terraform state show tls_private_key.deploy | head -20
#   Verás algorithm, rsa_bits (los que escribiste) junto a id, public_key_openssh,
#   public_key_fingerprint_md5 (los que rellenó el provider al "crear" el recurso).

terraform destroy -auto-approve
```

## Preguntas de reflexión

1. ¿Por qué `terraform plan` sabe que `github_repository_deploy_key.demo` se crea **después** de los otros dos, si no hay `depends_on`?
2. Si cambias `visibility = "private"` a `"public"`, ¿se re-crea el repo o se actualiza in-place? Pista: busca "ForceNew" en la doc del recurso.
3. ¿Qué pasaría si borras el bloque `tls_private_key.deploy` del HCL pero dejas el bloque `github_repository_deploy_key.demo` que lo referencia? Antes de ejecutar, predice el mensaje de error.
4. ¿Por qué este stack **no funciona** si inviertes `tls_private_key` y `github_repository_deploy_key` en el archivo (el orden físico)? Trampa: funciona igual, el orden del archivo es irrelevante.

## Limpieza

Si aplicaste:

```bash
terraform destroy -auto-approve
rm -rf /tmp/tf-03-ex01
```

Si solo hiciste `init`/`plan`:

```bash
rm -rf /tmp/tf-03-ex01
```
