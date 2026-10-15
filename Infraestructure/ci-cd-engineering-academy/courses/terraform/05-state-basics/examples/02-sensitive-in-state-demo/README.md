# Ejemplo 02 — `sensitive = true` **no** cifra el state

## Concepto que demuestra

Que marcar un valor como `sensitive = true` (variable u output) **lo oculta en la CLI** pero **lo deja en claro dentro de `terraform.tfstate`**. Lo mismo aplica a los atributos sensibles que un provider devuelve (p. ej. `random_password.result`).

## Contexto

Un error común entre principiantes es asumir que `sensitive` es una forma de cifrado o de protección real. No lo es. Es una señalización que `terraform plan`/`apply`/`output` respetan al imprimir, pero el **state** sigue siendo texto plano. Entenderlo es la frontera entre tratar el state como "un archivo más" y tratarlo como un **artefacto que vive bajo controles de secretos**.

## Objetivo

Al terminar sabrás:

- Reproducir en 2 minutos la diferencia entre lo que la CLI oculta y lo que el state expone.
- Explicar por qué `terraform.tfstate` **nunca va a Git**.
- Argumentar cuándo un `sensitive = true` es útil (señalización) y cuándo es una ilusión (protección).

## Prerrequisitos

- Terraform ≥ 1.5.
- `jq` (opcional, para explorar el JSON más cómodamente).
- `/tmp/` escribible. Sin cloud, sin coste.

## Archivos de este ejemplo

En `files/`:

- `versions.tf` — pin de providers (`random`, `local`).
- `main.tf` — genera una contraseña aleatoria con `random_password`, un output marcado `sensitive`, y la escribe en un `local_file` para evidenciar que el valor circula en claro por el state.

## Ejecución

```bash
# Preparar
WORK=/tmp/tf-05-ex02
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R files/. "$WORK/"
cd "$WORK"

# 1) Ciclo
terraform init
terraform apply -auto-approve

# 2) La CLI oculta
terraform output
# db_password = <sensitive>

terraform output db_password
# <sensitive>

# 3) El state NO oculta
grep -c '"result"' terraform.tfstate      # al menos 1
# Imprime el valor sensible leyendo el state:
grep -o '"result": *"[^"]*"' terraform.tfstate | head -1

# 4) Con jq (más limpio)
command -v jq >/dev/null && jq '.resources[]
  | select(.type=="random_password")
  | .instances[0].attributes.result' terraform.tfstate

# 5) 'terraform output -json' tampoco "cifra" — solo marca sensitive=true
terraform output -json | head -20

# 6) Y encima, el password viaja a un local_file:
cat passwords.txt
# db_password=<el mismo valor sensible>
```

## Resultado esperado

- `terraform output db_password` imprime literalmente `<sensitive>`.
- `grep '"result"' terraform.tfstate` imprime la contraseña **en claro**.
- `cat passwords.txt` imprime la contraseña **en claro** (porque la escribimos nosotros vía `local_file`).

## Interpretación

- La CLI respeta `sensitive`. El state no "respeta" nada: guarda lo que necesita para los diffs.
- Esto no es un bug; es consecuencia directa de que el state necesita el valor conocido para comparar en el siguiente plan.
- Por eso **el state nunca va a Git** y **el backend remoto donde vive el state es un almacén de secretos de facto**: debe tener cifrado at-rest, acceso least-privilege, versioning y auditoría.
- Si el valor es realmente delicado y rotable con dolor, no debería existir en el state. Si existe (porque un provider lo devuelve), minimízalo: rotación corta, scope de IAM mínimo al backend.

## Errores frecuentes

- **"terraform output no muestra el valor"**: correcto, por `sensitive = true`. Para ver el valor en claro desde el state: `terraform output -json` da la estructura; `terraform.tfstate` lo da directo (`jq` ayuda).
- **"he puesto `sensitive = true` entonces es seguro commitearlo"**: no. Nunca commitees `.tfstate`.
- **"OpenTofu lo cifra, ¿Terraform también?"**: OpenTofu 1.7+ tiene state encryption nativa; Terraform (HashiCorp) a 2026 no la tiene como feature general. Detalle en `tf-13`.

## Relación con escenarios reales

- Rotar un `random_password` lleva a un `plan: ~` que destruye y re-crea el consumidor (si no está hecho con `keepers`); de ahí que estos valores vivan preferentemente en un gestor de secretos externo y Terraform solo guarde la *referencia* (p. ej. ARN del secreto).
- Un leak de `terraform.tfstate` a Git público = incidente de seguridad; se trata como filtración de credenciales (rotar todo lo expuesto, no "borrar el archivo y seguir").

## Limpieza

```bash
cd "$WORK"
terraform destroy -auto-approve
cd /
rm -rf "$WORK"
```
