# Actividad 01 — Primer `apply` (null + random + local)

## 1. Identificación

- **ID:** `tf-02-01-first-apply`
- **Tecnología:** terraform
- **Módulo:** `02-setup-hcl-first-provider`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Construirás tu primer stack real de Terraform usando **tres providers didácticos sin coste**: `null`, `random` y `local`. El objetivo es que corras el ciclo completo (`init → fmt → validate → plan → apply → destroy`) en una carpeta en blanco, lo entiendas línea por línea y produzcas evidencia (un archivo escrito a disco con un contenido parametrizado por un valor aleatorio) y un breve `notas-lockfile.md` que demuestra que miraste el lockfile y entiendes qué fija.

## 3. Objetivos

- Instalar Terraform y verificar `terraform version` ≥ 1.5.
- Escribir un `versions.tf` + `main.tf` desde cero sin copiar un ejemplo.
- Correr el ciclo `init → fmt → validate → plan → apply → destroy`.
- Leer el `.terraform.lock.hcl` resultante y explicar qué fija.
- Dejar la carpeta sin recursos vivos (archivo generado eliminado por `destroy`).

## 4. Prerrequisitos

- `terraform` ≥ 1.5 (si no lo tienes, el validador reporta `SKIP` con instrucciones de instalación).
- Shell `bash` o `zsh`.
- Permisos de escritura en `/tmp/`.
- **Costos**: cero. Ningún provider toca cloud.

## 5. Instrucciones

### Paso 0 — Preparar

```bash
export WORK="/tmp/tf-02-01"
rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"
```

### Paso 1 — `versions.tf`

Crea `versions.tf` con:

- `required_version >= 1.5.0`.
- `required_providers` para los **tres** providers: `null (~> 3.2)`, `random (~> 3.6)`, `local (~> 2.5)`.

### Paso 2 — `main.tf`

Crea `main.tf` con exactamente estos recursos y outputs:

1. `random_pet` llamado `codename`, con `length = 3` y `separator = "-"`.
2. `random_string` llamado `suffix`, con `length = 8`, sin especiales ni mayúsculas.
3. `null_resource` llamado `log`, con un `triggers = { pet = random_pet.codename.id }`.
4. `local_file` llamado `badge`, cuyo:
   - `filename` debe ser `"/tmp/tf-02-01-out/${random_pet.codename.id}-${random_string.suffix.result}.txt"`.
   - `content` debe incluir ambos valores (pet y sufijo) de forma legible.
   - `file_permission = "0644"`.
5. `output "badge_path"` con el `filename` del `local_file`.
6. `output "codename"` con el `id` del `random_pet`.

### Paso 3 — Ciclo

Corre, en este orden:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply -auto-approve     # OK aquí: estamos en /tmp y es local
```

Verifica que el archivo exista:

```bash
cat "$(terraform output -raw badge_path)"
```

### Paso 4 — `notas-lockfile.md`

En `$WORK/notas-lockfile.md` escribe:

- La versión exacta a la que resolvió cada uno de los tres providers.
- Qué dirían los campos `h1:` y `zh:` que ves en el lockfile.
- Una línea respondiendo: **¿qué cosa concreta se rompería si borras el lockfile y haces `init -upgrade`?**

El validador buscará que el archivo mencione, al menos: la palabra `h1`, los nombres `random`, `local` y `null`, y las palabras `version` y `hashes`.

### Paso 5 — `destroy` y limpieza

```bash
terraform destroy -auto-approve
ls /tmp/tf-02-01-out 2>/dev/null || echo "(ya no existe el directorio)"
```

El `destroy` debe eliminar el `local_file` (y por lo tanto dejar vacío o eliminado el directorio de salida, dependiendo de cómo lo creó Terraform).

## 6. Resultado esperado

Al terminar, el validador debe encontrar en `/tmp/tf-02-01/`:

- `versions.tf`, `main.tf`, `.terraform.lock.hcl` presentes.
- `terraform.tfstate` presente (es local, está bien).
- `notas-lockfile.md` presente con las menciones esperadas.
- **Sin `local_file` vivo**: después del `destroy`, el archivo bajo `/tmp/tf-02-01-out/` no debe existir. El state debe estar vacío de recursos.

## 7. Criterios de aceptación

- `terraform validate` termina con `Success!`.
- `terraform plan` tras `destroy` dice `No changes` (state vacío, config desplegada).
- El lockfile contiene los tres providers.
- Las notas del lockfile existen y mencionan lo pedido.

## 8. Validación

```bash
bash tests/validate.sh
```

Si no tienes `terraform` instalado, el validador reporta `SKIP` con instrucciones. Si lo tienes, chequea toda la lista anterior.

## 9. Preguntas de reflexión

1. ¿Qué habría pasado si pusieras `random_pet.codename.id` dentro de `null_resource.log.triggers` y luego cambiaras `length` del pet? Haz la prueba y describe el plan.
2. Si quitas `random_string.suffix` del `main.tf` pero no corres `destroy` antes, ¿qué dice el próximo `plan`?
3. ¿Qué ocurre si borras `terraform.tfstate` después del apply y vuelves a correr `plan`? ¿Cómo recuperarías el stack sin recrear todo?

## 10. Extensiones (opcionales)

- Agrega un `data "http"` que consulte `https://checkip.amazonaws.com/` y mete la IP pública dentro del `content` del `local_file`.
- Convierte `length` del pet en una `variable` con `default = 3` y pásala por `-var='length=5'`.
- Agrega un `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` y observa cómo cambia el lockfile.

## 11. Limpieza

```bash
cd /tmp
terraform -chdir=/tmp/tf-02-01 destroy -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-02-01 /tmp/tf-02-01-out
```
