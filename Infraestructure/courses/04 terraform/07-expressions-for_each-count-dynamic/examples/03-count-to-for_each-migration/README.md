# Ejemplo 03 — Migración `count` → `for_each`

Dos stacks equivalentes con la **misma intención** pero distinto meta-argument. El punto no es que `for_each` sea "más bonito" — es que `count` **cambia la identidad de los recursos** cuando reorganizas la lista, y `for_each` no.

Vas a reproducir con `local_file` el fallo clásico: borrar el elemento del medio hace cascada.

## Estructura

```
├── before-count/        # usa count, se rompe al reordenar
│   ├── main.tf
│   └── variables.tf
└── after-for_each/      # usa for_each con toset()
    ├── main.tf
    └── variables.tf
```

## Parte A — Reproducir el fallo con `count`

```bash
cd before-count
terraform init
terraform apply -auto-approve
ls out/        # 0-alice.txt 1-bob.txt 2-carol.txt
```

Edita `variables.tf` y quita `"bob"` del default:

```hcl
default = ["alice", "carol"]
```

Corre:

```bash
terraform plan
```

Verás algo así:

```
# local_file.user[1] must be replaced
-/+ resource "local_file" "user" {
    ~ content  = "name=bob\n"   -> "name=carol\n"  # forces replacement
    ...
}
# local_file.user[2] will be destroyed
```

**Nota qué pasa**: `carol` se destruye y recrea aunque conceptualmente no cambió nada para ella. Esa es la trampa del reindex de `count`.

```bash
terraform apply -auto-approve
ls out/        # 0-alice.txt 1-carol.txt  (0 archivos duplicados o residuales dependiendo del flujo)
```

Deshaz el cambio en `variables.tf` y limpia:

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out/
```

## Parte B — Arreglarlo con `for_each`

```bash
cd ../after-for_each
terraform init
terraform apply -auto-approve
ls out/        # alice.txt bob.txt carol.txt (sin índice entero en el nombre)
```

Edita `variables.tf` y quita `"bob"` del default:

```hcl
default = ["alice", "carol"]
```

Corre:

```bash
terraform plan
```

Verás:

```
# local_file.user["bob"] will be destroyed
```

**Solo eso**. `alice` y `carol` no se tocan. La identidad del recurso es la clave (`"bob"`), no la posición.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out/
```

## Resumen

| Operación | `count` planea... | `for_each` planea... |
|-----------|-------------------|----------------------|
| Añadir "dave" al final | Create `[3]` | Create `["dave"]` |
| Quitar "bob" del medio | Replace `[1]` + destroy `[2]` | Destroy `["bob"]` |
| Reordenar la lista | Replace masivo | No changes |

El refactor retro-compatible usa `moved` blocks (se ve en `tf-09`), pero el patrón idiomático **nuevo** debería usar `for_each` desde el día uno.
