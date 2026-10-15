# Ejemplo 02 — Análisis programático de un `plan.json`

Objetivo: generar un `plan.out`, convertirlo a JSON y atacarlo con `jq` para responder preguntas tipo "qué cambia, por qué, y qué atributo lo disparó".

## Prerrequisitos

- Terraform ≥ 1.5.
- `jq` ≥ 1.6.

## Setup

```bash
mkdir -p /tmp/tf-10-ex02 && cd /tmp/tf-10-ex02

cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "greeting" {
  type    = string
  default = "hola"
}

resource "random_pet" "name" {
  length = 2
}

resource "local_file" "report" {
  filename = "${path.module}/out/report.txt"
  content  = "${var.greeting}, ${random_pet.name.id}\n"
}
EOF

terraform init
```

## Pasos

### 1. Primer plan y análisis

```bash
mkdir -p out
terraform plan -out=plan.out
terraform show -json plan.out > plan.json

# ¿qué va a pasar?
jq '.resource_changes[] | {address, actions: .change.actions}' plan.json

# ¿cuántos recursos en cada acción?
jq '[.resource_changes[].change.actions[]] | group_by(.) | map({action: .[0], n: length})' plan.json
```

Esperado: dos recursos en `["create"]`.

### 2. Aplicar y re-planear (debería ser no-op)

```bash
terraform apply plan.out
terraform plan -out=plan2.out
terraform show -json plan2.out > plan2.json

jq '[.resource_changes[].change.actions]' plan2.json
# -> [["no-op"], ["no-op"]]
```

### 3. Cambiar una variable: ver `update` in-place

```bash
terraform plan -var='greeting=hey' -out=plan3.out
terraform show -json plan3.out > plan3.json

jq '.resource_changes[] | select(.change.actions != ["no-op"])
   | {address, actions: .change.actions,
      before: .change.before.content, after: .change.after.content}' plan3.json
```

`local_file.report` sale como `["update"]` o `["delete","create"]` según cómo el provider marque `content`. Compruébalo con:

```bash
jq '.resource_changes[] | select(.address=="local_file.report")
   | .change.replace_paths' plan3.json
```

Si `replace_paths` está vacío → es `update` real; si lista `["content"]`, el provider lo marcó como `ForceNew` y será replace.

### 4. Simular un ForceNew: cambiar el `filename`

```bash
terraform plan -var='greeting=hola' -out=plan4.out
# ahora cambia el filename:
sed -i.bak 's|out/report.txt|out/report-v2.txt|' main.tf
terraform plan -out=plan5.out
terraform show -json plan5.out > plan5.json

jq '.resource_changes[] | select(.address=="local_file.report")
   | {actions: .change.actions, replace_paths: .change.replace_paths}' plan5.json
```

Esperado: `actions: ["delete","create"]` o `["create","delete"]`, con `replace_paths` incluyendo `["filename"]`.

### 5. Un cambio en `random_pet` sin referenciarlo

```bash
# edita el stack para forzar un replace de random_pet.name
sed -i.bak 's/length = 2/length = 3/' main.tf
terraform plan -out=plan6.out
terraform show -json plan6.out > plan6.json

# ver qué entra en replace y qué queda en known-after-apply
jq '.resource_changes[] | {address, actions: .change.actions,
     after_unknown: .change.after_unknown}' plan6.json
```

`local_file.report` tendrá `content` como `(known after apply)` porque interpola `random_pet.name.id`, que acaba de hacerse unknown por el replace del pet.

## Preguntas

1. ¿Cuándo el campo `change.replace_paths` sale vacío y cuándo no?
2. ¿Por qué cambiar `length` en `random_pet` cascada en el `content` de `local_file`?
3. Si quisieras un dashboard "¿cuántos replace vs updates vs destroy hay semanalmente?", ¿qué query de `jq` sobre `plan.json` lo alimentaría?

## Limpieza

```bash
cd / && rm -rf /tmp/tf-10-ex02
```
