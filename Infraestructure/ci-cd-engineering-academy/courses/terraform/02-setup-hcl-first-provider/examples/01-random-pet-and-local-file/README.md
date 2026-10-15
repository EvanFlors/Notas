# Ejemplo 01 — `random_pet` + `local_file`

Stack mínimo que demuestra el ciclo completo **sin cloud**: Terraform genera un nombre de mascota aleatorio y escribe un archivo en `/tmp/` con ese nombre dentro. Al terminar, `destroy` lo elimina.

## Qué aprenderás

- Cómo se ve un `versions.tf` + `main.tf` reales.
- Cómo se declara una **dependencia implícita** (el `local_file` referencia a `random_pet.name.id`, por eso Terraform crea primero el `random_pet`).
- Qué imprime cada paso del ciclo.

## Prerrequisitos

- `terraform` ≥ 1.5 en `PATH`. Verifica con `terraform version`.
- Sin credenciales, sin cuenta cloud.

## Estructura

```
examples/01-random-pet-and-local-file/
├── README.md         (este archivo — las instrucciones)
└── (los .tf viven en /tmp/tf-02-ex01 cuando sigas los pasos)
```

No commiteamos los `.tf` del ejemplo porque los vas a escribir tú siguiendo el walkthrough. El objetivo es que *teclees el HCL*, no que lo copies de un archivo.

## Walkthrough

### 1. Crear el directorio de trabajo

```bash
mkdir -p /tmp/tf-02-ex01 && cd /tmp/tf-02-ex01
```

### 2. Escribir `versions.tf`

```hcl
# versions.tf
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

### 3. Escribir `main.tf`

```hcl
# main.tf
resource "random_pet" "name" {
  length    = 2
  separator = "-"
}

resource "local_file" "greeting" {
  filename        = "/tmp/tf-02-ex01-out/${random_pet.name.id}.txt"
  content         = "hola desde Terraform, soy ${random_pet.name.id}\n"
  file_permission = "0644"
}

output "pet_name" {
  value = random_pet.name.id
}

output "written_file" {
  value = local_file.greeting.filename
}
```

Nota la referencia `random_pet.name.id` dentro de `local_file`: eso crea la dependencia implícita.

### 4. `terraform init`

```bash
terraform init
```

Salida esperada (abreviada):

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/random versions matching "~> 3.6"...
- Finding hashicorp/local versions matching "~> 2.5"...
- Installing hashicorp/random v3.6.3...
- Installed hashicorp/random v3.6.3 (signed by HashiCorp)
- Installing hashicorp/local v2.5.1...
- Installed hashicorp/local v2.5.1 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above.

Terraform has been successfully initialized!
```

Verifica:

```bash
ls -la .terraform .terraform.lock.hcl
```

Deberías ver el directorio `.terraform/providers/registry.terraform.io/hashicorp/...` y el archivo de lock.

### 5. `terraform fmt` y `terraform validate`

```bash
terraform fmt
terraform validate
```

`validate` debe decir `Success! The configuration is valid.`.

### 6. `terraform plan`

```bash
terraform plan
```

Salida esperada (abreviada):

```
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # local_file.greeting will be created
  + resource "local_file" "greeting" {
      + content         = (known after apply)
      + content_base64sha256 = (known after apply)
      + file_permission = "0644"
      + filename        = (known after apply)
      ...
    }

  # random_pet.name will be created
  + resource "random_pet" "name" {
      + id        = (known after apply)
      + length    = 2
      + separator = "-"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

Observa:

- Dos `+` (crear 2 recursos).
- Varios atributos son `(known after apply)` porque dependen de un cómputo que aún no sucedió.
- El `filename` de `local_file` también es `(known after apply)` porque incluye `random_pet.name.id`.

### 7. `terraform apply`

```bash
terraform apply
# escribe 'yes' cuando pregunte
```

Salida final:

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

pet_name = "wise-marmoset"
written_file = "/tmp/tf-02-ex01-out/wise-marmoset.txt"
```

Verifica:

```bash
cat /tmp/tf-02-ex01-out/wise-marmoset.txt
# → hola desde Terraform, soy wise-marmoset
```

Y mira el state:

```bash
cat terraform.tfstate | head -40
```

Es JSON; ya contiene `random_pet.name.id = "wise-marmoset"` y los atributos de `local_file`.

### 8. `terraform plan` de nuevo (idempotencia)

```bash
terraform plan
# → No changes. Your infrastructure matches the configuration.
```

Esto es la **idempotencia** del modelo declarativo: aplicar dos veces la misma config no hace nada la segunda vez.

### 9. `terraform destroy`

```bash
terraform destroy
# escribe 'yes'
```

Salida:

```
Destroy complete! Resources: 2 destroyed.
```

Verifica:

```bash
ls /tmp/tf-02-ex01-out/     # archivo eliminado
```

### 10. Limpieza

```bash
cd /tmp && rm -rf /tmp/tf-02-ex01 /tmp/tf-02-ex01-out
```

## Qué observar

- **Orden del grafo**: aunque escribiste `local_file` antes que `random_pet` en el `.tf`, Terraform creó primero `random_pet` porque `local_file` lo referencia. El orden físico en el archivo es irrelevante.
- **El state crece con cada apply**: `serial` sube, `resources` contiene los dos elementos.
- **El lockfile cambió**: ábrelo con `cat .terraform.lock.hcl`. Verás los dos providers con `version` exacta y `hashes`.
- **Nada en la nube**: no gastaste un centavo, no hiciste login en ningún lado.

## Variantes para experimentar

- Cambia `length = 2` a `length = 4`. Haz `plan`: ¿qué dice? (debería recrear el pet y por lo tanto también el file, porque el filename depende del id).
- Agrega un segundo `local_file` que no dependa del `random_pet`. Mira el plan: ambos files pueden crearse en paralelo si no hay dependencia.
- Edita el `content` del `local_file`. Haz `plan`: ¿crear + destroy, o solo update?
