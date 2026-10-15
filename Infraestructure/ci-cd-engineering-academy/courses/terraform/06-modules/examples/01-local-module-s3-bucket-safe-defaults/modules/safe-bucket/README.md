# Módulo `safe-bucket`

> Didáctico. Simula un bucket S3 con safe defaults usando `local_file` y `random`.

## Qué hace

Materializa un "bucket" como un directorio en el host, con marcadores para versioning, encryption y access log. Añade un sufijo random al nombre para evitar colisiones. Habilita versioning, encryption y access log **por default**.

## Uso

```hcl
module "logs" {
  source = "./modules/safe-bucket"

  name = "logs"
  tags = {
    Env   = "dev"
    Owner = "me"
  }
}
```

## Inputs

| Nombre | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| `name` | string | — | Slug kebab-case, 3-30 chars. |
| `base_path` | string | `/tmp/tf-06-ex01` | Dónde se materializa el bucket. |
| `versioning_enabled` | bool | `true` | Safe default. |
| `encryption_enabled` | bool | `true` | Safe default. |
| `access_log_enabled` | bool | `true` | Safe default. |
| `tags` | map(string) | `{}` | Se materializan en `tags.json`. |

## Outputs

| Nombre | Descripción |
|--------|-------------|
| `bucket_name` | Nombre efectivo (incluye sufijo random). |
| `bucket_path` | Ruta en el host. |
| `versioning_enabled` | Estado efectivo. |
| `encryption_enabled` | Estado efectivo. |

## Decisiones de diseño

- **No** configura `provider "..." {}`: eso es tarea del root.
- **Safe defaults** en versioning, encryption y access log: para apagarlos hay que ser **explícito**.
- API pequeña: 6 inputs. Si necesitas 20, probablemente son dos módulos.
