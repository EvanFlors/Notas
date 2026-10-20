# Ejemplo 02 — Import blocks para adopción de infra legada

Adoptar al estado de Terraform recursos ya existentes **sin recrearlos** y **con un PR auditable**, usando `import {}` + `terraform plan -generate-config-out`.

## Qué muestra

- Cómo declarar bloques `import {}` por lotes (bulk).
- Cómo generar HCL inicial a partir del estado real con `-generate-config-out`.
- Qué partes del HCL generado hay que limpiar antes de que el plan sea `No changes`.
- Por qué este flujo es preferible al `terraform import` CLI en una org con PRs obligatorios.

## Estructura

```
examples/02-import-blocks-for-legacy-adoption/
├── README.md
├── setup.sh        # crea 3 archivos "legacy" en /tmp/tf14-ex02-legacy/
├── cleanup.sh
├── imports.tf      # bloques import {} que apuntan a los 3 archivos
└── versions.tf
```

## Prerrequisitos

- Terraform ≥ 1.5

## Pasos

### 1. Crear infra "legacy" (fuera de TF)

```bash
cd examples/02-import-blocks-for-legacy-adoption
bash setup.sh
ls /tmp/tf14-ex02-legacy/
# alpha.conf  beta.conf  gamma.conf
```

Los 3 archivos simulan recursos existentes en producción que nunca entraron a Terraform.

### 2. Mirar el stack mínimo

`imports.tf` contiene **solo** los 3 bloques `import` y nada de `resource {}`:

```hcl
import {
  to = local_file.alpha
  id = "/tmp/tf14-ex02-legacy/alpha.conf"
}
# ... beta, gamma análogos
```

### 3. Generar HCL inicial

```bash
cd examples/02-import-blocks-for-legacy-adoption
terraform init
terraform plan -generate-config-out=generated.tf
```

Terraform crea `generated.tf` con 3 `resource "local_file"` poblados con los valores reales leídos del disco. El plan dirá: *3 to import*.

### 4. Limpiar `generated.tf`

El HCL generado incluye atributos redundantes o `null`. Edita `generated.tf` para dejar solo los atributos realmente deseados (típicamente `filename`, `content`, `file_permission`). Mueve esos recursos a un archivo con nombre significativo (`adopted.tf`), borra `generated.tf`.

### 5. Aplicar la adopción

```bash
terraform apply -auto-approve
terraform plan   # debe decir: No changes
```

El state ahora contiene los 3 recursos; **los archivos originales no se tocaron**. Verifica:

```bash
terraform state list
# local_file.alpha
# local_file.beta
# local_file.gamma
```

### 6. Limpieza

```bash
bash cleanup.sh
```

## Decisiones de diseño

- **Recursos `local_file`**: sin red, sin coste, pedagógicos. El patrón es idéntico con `aws_instance`, `aws_s3_bucket`, etc.
- **3 recursos** (no 1): para ilustrar que `import {}` escala a bulk — se declaran todos los bloques y se corre `-generate-config-out` una vez.
- **El HCL generado no es final**: muestra deliberadamente que la fase de *limpieza* es parte del flujo, no un paso opcional.

## Qué llevarte

`import {}` convierte "adoptar legacy" en un **cambio en PR**: review, diff, aprobación, auditoría. Los equipos de plataforma pueden habilitar la adopción masiva (p. ej. una cuenta AWS entera) escribiendo cientos de bloques import y confiando en `-generate-config-out` para el bootstrap.
