# Ejemplo 03 — Refactor con `moved {}` y `removed {}`

Renombrar un recurso y sacar otro del state sin recrear nada, usando bloques declarativos auditables en PR.

## Qué muestra

- `moved {}` para renombrar `local_file.old_name` → `local_file.new_name` sin destroy+create.
- `removed {}` con `lifecycle { destroy = false }` para "handoff": sacar un recurso del state sin tocarlo en disco (porque pasará a ser gestionado por otro stack).
- Por qué estos bloques son idempotentes y pueden quedar permanentemente en el código.

## Estructura

```
examples/03-moved-and-removed-refactor/
├── README.md
├── setup.sh         # bootstrap de un stack con 2 recursos
├── cleanup.sh
├── step1/           # estado inicial: old_name + handoff_candidate
│   ├── main.tf
│   └── versions.tf
└── step2/           # tras refactor: rename + removed
    ├── main.tf
    └── versions.tf
```

## Prerrequisitos

- Terraform ≥ 1.5 (`moved` desde 1.1, `removed` desde 1.7).

## Pasos

### 1. Estado inicial (step1)

```bash
cd examples/03-moved-and-removed-refactor
bash setup.sh
cd /tmp/tf14-ex03/step1
terraform init && terraform apply -auto-approve
terraform state list
# local_file.handoff_candidate
# local_file.old_name
```

### 2. Refactor (step2)

Copia el state al nuevo directorio y aplica step2:

```bash
cp /tmp/tf14-ex03/step1/terraform.tfstate /tmp/tf14-ex03/step2/
cd /tmp/tf14-ex03/step2
terraform init
terraform plan
```

El plan debería reportar algo como:

```
# local_file.new_name has moved to local_file.new_name   (from local_file.old_name)
# local_file.handoff_candidate will no longer be managed by Terraform
#   (lifecycle.destroy = false; file on disk is preserved)
```

Nota clave: **ningún recurso será creado ni destruido en disco**. El archivo del handoff sigue existiendo tras `apply`.

```bash
terraform apply -auto-approve
terraform state list
# local_file.new_name
ls /tmp/tf14-ex03/data/
# both files still on disk; handoff_candidate just no longer in state
```

### 3. Limpieza

```bash
cd -   # back to example dir
bash cleanup.sh
```

## Decisiones de diseño

- **Dos directorios (step1, step2)** con el mismo state copiado: muestra que el refactor es una **evolución del HCL** sobre un state existente, no un bootstrap nuevo.
- **`removed { destroy = false }`** sobre un archivo que persiste en disco: hace visible el caso "pasar la gestión a otro stack sin downtime".
- **`moved {}` puede quedar permanentemente en el código**: en runs futuros donde la rename ya está aplicada, es no-op. Esto permite que consumers de un módulo que incorpora el `moved` hagan upgrade sin intervención.

## Qué llevarte

`moved` y `removed` son la contrapartida declarativa de `terraform state mv/rm`. Mueven las operaciones de riesgo del state **al código**, con review y audit. En una org con muchos stacks, esto es la diferencia entre refactors seguros y refactors que generan incidentes.
