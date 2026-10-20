# Ejemplo 01 — tflint + fmt

## Concepto que demuestra

- `terraform fmt` normaliza indentación y alineación.
- `terraform validate` detecta errores sintácticos y de referencias.
- **tflint** detecta reglas de estilo y de provider (p. ej. tipo de instancia inexistente).

## Prerrequisitos

- `terraform` ≥ 1.6 (opcional: el ejemplo degrada con `SKIP`).
- `tflint` ≥ 0.50 (opcional).

## Archivos

- `main.tf` — un módulo intencionalmente mal formateado y con un bug de provider.
- `.tflint.hcl` — configuración de tflint con el plugin de AWS.

## Ejecución

```bash
cd examples/01-tflint-and-fmt

# 1. Formato (ver diff sin aplicar)
terraform fmt -check -diff .

# 2. Validación sintáctica
terraform init -backend=false
terraform validate

# 3. tflint
tflint --init
tflint
```

## Qué debes observar

- `fmt -check` falla y muestra el diff que corregiría.
- `validate` pasa (HCL es sintácticamente válido).
- `tflint` reporta: `instance_type "t99.huge"` no existe (regla `aws_instance_invalid_type`).

## Patrón en CI (fragmento conceptual)

```yaml
# .github/workflows/tf.yml (fragmento ilustrativo)
- run: terraform fmt -check -recursive
- run: terraform init -backend=false
- run: terraform validate
- run: tflint --init && tflint --format compact
```

Pre-commit local equivalente: hook que corre los mismos cuatro comandos antes de permitir el commit.

## Limpieza

```bash
rm -rf .terraform .terraform.lock.hcl
```
