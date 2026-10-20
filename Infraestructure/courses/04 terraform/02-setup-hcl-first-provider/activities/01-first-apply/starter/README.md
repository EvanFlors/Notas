# Starter — `tf-02-01-first-apply`

Esta actividad **no trae HCL de arranque**: el objetivo es que escribas `versions.tf` y `main.tf` desde cero en `/tmp/tf-02-01/`. Si copias de ejemplos, te pierdes el 80% del valor.

## Cómo empezar

```bash
export WORK="/tmp/tf-02-01"
rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"

# Ahora: edita versions.tf, main.tf y notas-lockfile.md
# siguiendo las instrucciones del README.md de la actividad.
```

## Cheatsheet mínima (sin regalar la solución)

- `terraform { required_version = "..." required_providers { ... } }` va en `versions.tf`.
- Cada provider dentro de `required_providers` necesita `source` y `version`.
- Los `source` para los didácticos son: `hashicorp/null`, `hashicorp/random`, `hashicorp/local`.
- Dentro de un `resource "TIPO" "NOMBRE"`, los atributos son `nombre = valor`.
- Para referenciar un recurso en otro: `TIPO.NOMBRE.ATRIBUTO`.
- Interpolación en string: `"foo-${expr}-bar"`.

## Comandos del ciclo

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
```

## Si no tienes Terraform instalado

- macOS (Homebrew):   `brew install terraform`
- `tfenv`:            `tfenv install latest && tfenv use latest`
- `asdf`:             `asdf plugin add terraform && asdf install terraform latest`
- Binario:            https://developer.hashicorp.com/terraform/install

Verifica con:

```bash
terraform version
```

Requerido: `>= 1.5`.
