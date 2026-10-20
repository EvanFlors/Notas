# tf-07-02 — Arreglar la cascada de reindex de `count`

## 1. Identificación

- **ID:** `tf-07-02-fix-count-reindex-drift`
- **Tecnología:** terraform
- **Módulo:** `07-expressions-for_each-count-dynamic`
- **Dificultad:** intermediate
- **Duración estimada:** 55 min
- **Tipo:** independent

## 2. Contexto

Heredaste un stack escrito con `count = length(var.items)` sobre un `local_file` (en producción sería un `aws_iam_user` o `aws_s3_bucket`). Negocio te pide **eliminar el segundo elemento del map**. Pruebas, y Terraform te planea destruir y recrear casi todo. Esto es la trampa clásica de `count` sobre colecciones con identidad.

Tu trabajo:

1. **Reproducir el síntoma** — hacer `apply` del starter, eliminar el elemento del medio, correr `terraform plan` y guardar la salida: debería mostrar cascade (replace + destroy).
2. **Refactorizar** — pasar a `for_each` con `toset()` keyed por nombre.
3. **Demostrar que el fix funciona** — aplicar el refactor, repetir el ejercicio y comprobar que el plan equivalente ahora solo destruye el elemento removido.

## 3. Objetivos

- Diagnosticar un plan ruidoso causado por `count` sobre colecciones con identidad.
- Refactorizar a `for_each` con `toset()`.
- Justificar, con un plan de Terraform en mano, por qué `for_each` casi siempre gana.

## 4. Prerrequisitos

- Terraform ≥ 1.3.
- Haber leído la lección y los 3 ejemplos del módulo.
- Software: `bash`, `grep`.
- Costos: 0 (local).

## 5. Instrucciones

> **Independiente**: no se da la solución textual. Pistas sin código:
> - La clave estable natural aquí es el `name` del item.
> - `for_each` sobre una lista no funciona directamente; úsalo con `toset()` o construye un map.
> - Si prefieres mantener la estructura de datos de entrada (lista de objetos con atributos), construye el map con una `for` expression: `{ for i in var.items : i.name => i }`.

Trabaja en `/tmp/tf-07-02/`:

```bash
mkdir -p /tmp/tf-07-02
cp -r starter/* /tmp/tf-07-02/
cd /tmp/tf-07-02
```

### Fase A — Reproducir el problema

1. `terraform init && terraform apply -auto-approve`.
2. Edita `terraform.tfvars` y **elimina `beta`** del medio. Deja `alpha` y `gamma`.
3. `terraform plan` — guarda la salida como `plan-count-cascade.txt`.
4. Observa en el plan: debería mencionar al menos un `must be replaced` y un `will be destroyed`. Idealmente dos operaciones donde esperabas una.
5. **Revierte** `terraform.tfvars` a los 3 items originales y `terraform apply -auto-approve` para dejar el stack sano antes del refactor.

### Fase B — Refactorizar a `for_each`

1. Reescribe `main.tf` para usar `for_each` en vez de `count`. El filename ya no debe tener índice entero: usa `each.key`.
2. **Importante**: tras cambiar `count` → `for_each`, Terraform verá los recursos existentes (`local_file.item[0..2]`) como "a destruir" y los nuevos (`local_file.item["alpha"]`, etc.) como "a crear". Para la actividad, acepta esto como parte del refactor y haz `apply`. (En un stack real usarías `moved` blocks de `tf-09`.)
3. Repite el experimento: elimina `beta` del `.tfvars` y corre `terraform plan`. Guarda como `plan-for_each-clean.txt`. Debe mencionar **solo** la destrucción de `local_file.item["beta"]`.
4. Revierte `terraform.tfvars` a los 3 items originales y verifica que `terraform plan` reporta `No changes`.

### Fase C — Validación

```bash
bash tests/validate.sh /tmp/tf-07-02
```

El validador verifica:
- `main.tf` usa `for_each` y **no** `count`.
- Los 3 archivos `alpha.txt`, `beta.txt`, `gamma.txt` existen (nombres sin prefijo numérico).
- `plan-count-cascade.txt` existe y menciona `must be replaced` o similar (evidencia de la Fase A).
- `plan-for_each-clean.txt` existe y menciona `local_file.item["beta"]` **sin** `must be replaced` sobre `alpha` o `gamma`.

## 6. Resultado esperado

- `main.tf` final usa `for_each` con claves estables.
- Dos archivos de evidencia (`plan-count-cascade.txt`, `plan-for_each-clean.txt`) muestran el antes y el después.
- `terraform plan` final (sobre los 3 items originales) es idempotente.

## 7. Criterios de aceptación

- Fase A documentada (archivo de evidencia).
- Fase B aplicada (código correcto).
- Fase C pasa (`validate.sh` exit 0).

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-07-02
```

## 9. Preguntas de reflexión

1. ¿Por qué el refactor `count` → `for_each` provoca un plan "feo" (destroy + create) sin ayuda extra? ¿Qué herramienta de Terraform mitigaría ese impacto sin perder el estado real? (Pista: `moved` blocks, módulo `tf-09`.)
2. ¿Habría funcionado `for_each = var.items` sin `toset()`? ¿Por qué?
3. Si `name` pudiera repetirse en la lista, ¿qué ocurriría con el map construido por `for`? ¿Cómo lo defenderías?

## 10. Extensiones

- **E1**: añade `moved { from = local_file.item[0], to = local_file.item["alpha"] }` y repite. Observa cómo el plan ya no destruye+crea.
- **E2**: pasa de `list(object)` a `map(object)` en `variables.tf` para evitar la transformación con `for`. Analiza trade-offs de UX.
- **E3**: añade un `validation` block en `variables.tf` que rechace nombres duplicados usando `length(distinct(...))`.

## 11. Limpieza

```bash
cd /tmp/tf-07-02
terraform destroy -auto-approve
cd /
rm -rf /tmp/tf-07-02
```
