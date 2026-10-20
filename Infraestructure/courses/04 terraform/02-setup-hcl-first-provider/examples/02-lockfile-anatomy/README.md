# Ejemplo 02 — Anatomía del `.terraform.lock.hcl`

Mientras `tf-01` fue teoría pura y el ejemplo `01` corrió el ciclo, este ejemplo es un **close reading** del lockfile. Si entendiste el ejemplo 01, ya tienes un lockfile real en `/tmp/tf-02-ex01/.terraform.lock.hcl`. Si no, abajo te damos uno de muestra.

## Qué aprenderás

- Qué significa cada bloque y cada atributo del lockfile.
- Qué cambia (y qué no) al correr `init` vs `init -upgrade`.
- Qué significan los hashes `h1:` vs `zh:`.
- Qué cambia al correr `terraform providers lock -platform=...`.

## Un lockfile de muestra, completo

```hcl
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/local" {
  version     = "2.5.1"
  constraints = "~> 2.5"
  hashes = [
    "h1:Zy6XilCg8MWBpYZksxoAwIjlNoVgR3Oq12q7bxlEnEM=",
    "zh:0af710e528e21b930899f0ac295b0ceef8ad7b623dd8f38e92c8ec4bc7af0321",
    "zh:1fb9aca1f068b4b99c6c3b08b2b3b1a3fd60ca45c6a0b3a7c094db37c7d6b7a1",
    "zh:3c7a79b4ba29aa9c20b67e5a37d8f6e84820a4b5f7a1a3b6fb8e2a92e1a6b0ff",
    "zh:48ac3f41afbf1b4f16a9eac0f6a2a8b5c9c17e2e2a2e8d7f8e3f3a1b0c0d1e2f",
    "zh:5e2d1a0b3f7e2f1a9d8e7f6b5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b",
    "zh:6f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a",
    "zh:71a5e7a8f2e1c3d4b5a6e9f8d7c6b5a4e3d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8",
    "zh:823e4d1c6b5a9f8e7d6c5b4a3e2d1c0b9f8e7d6c5b4a3e2d1c0b9f8e7d6c5b4a",
    "zh:9b3c6d7e8f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c",
    "zh:a4e9d8c7b6a5f4e3d2c1b0a9f8e7d6c5b4a3e2d1c0b9f8e7d6c5b4a3e2d1c0b9",
    "zh:b5f0e1d2c3b4a5e6f7d8c9b0a1f2e3d4c5b6a7e8f9d0c1b2a3f4e5d6c7b8a9f0",
    "zh:c6d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1",
    "zh:d7a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2",
    "zh:e8b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3",
  ]
}

provider "registry.terraform.io/hashicorp/random" {
  version     = "3.6.3"
  constraints = "~> 3.6"
  hashes = [
    "h1:zG9uFP8l9u+yGZZvi5Te7PV62j50azpgwPunq2vTm1E=",
    "zh:04ceb65210251339f07cd4611885d242cd4d0c7306e86dda9785396887e27d2f",
    "zh:...",
  ]
}
```

## Diseccion

### 1. El header

```hcl
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.
```

No lo edites a mano. Si necesitas regenerarlo, usa `terraform init -upgrade` o `terraform providers lock`.

### 2. El bloque `provider`

Un bloque por **source address** completo. El formato es:

```
<REGISTRY>/<NAMESPACE>/<NAME>
```

- `registry.terraform.io` → el registry público oficial.
- `hashicorp` → el namespace (publisher).
- `local`, `random`, etc. → el nombre del provider.

Si usaras providers de otros registries (ej. `registry.opentofu.org`, un mirror interno, etc.), verías otro valor a la izquierda.

### 3. `version`

La **versión exacta** resuelta la última vez que `init` corrió. En este archivo, Terraform usará exactamente `2.5.1` y `3.6.3`, aunque tus `constraints` permitirían más altas.

### 4. `constraints`

Las constraints que escribiste en `required_providers`. Es informativo — Terraform ya resolvió a `version`.

Si cambias las constraints en `required_providers` y haces `init` sin `-upgrade`, puede fallar si la `version` del lockfile ya no cumple las nuevas constraints.

### 5. `hashes` — `h1:` vs `zh:`

Dos formatos:

- **`h1:<base64>`** — hash SHA256 del zip del provider, en el formato nuevo (desde Terraform 0.14). Es un **hash único por plataforma del binario**. Si tu lockfile solo tiene `h1:` para `darwin_arm64`, inicializar desde `linux_amd64` fallará con `checksum mismatch`.
- **`zh:<hex>`** — hash SHA256 "legacy", generado por el registry. Son varios porque hay uno por plataforma, pero el *formato* es diferente.

Resultado práctico: **si tu equipo mezcla sistemas operativos y arquitecturas**, debes incluir `h1:` para todas las plataformas. Para eso:

```bash
terraform providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64
```

Esto rellena los `h1:` para cada plataforma listada y evita que un desarrollador en Mac M1 rompa el lockfile para el runner Linux de CI.

### 6. Qué pasa cuando corres `terraform init -upgrade`

- Reconsulta el registry.
- Resuelve la **última versión que cumpla tus constraints** (ignora la `version` del lockfile).
- Reescribe el lockfile con la nueva `version` y nuevos `hashes`.

Sin `-upgrade`, `init` respeta el lockfile aunque haya nuevas minor/patch disponibles. Esto es lo que te da reproducibilidad.

## Comparación: `required_version` vs `required_providers` vs lockfile

| Fija... | Dónde | Formato |
|---|---|---|
| Versión del binario `terraform` core | `terraform { required_version = ... }` | Constraint (p. ej. `>= 1.5.0`) |
| Rango aceptable de un provider | `terraform { required_providers { X = { version = ... } } }` | Constraint (p. ej. `~> 3.6`) |
| Versión exacta y hashes del provider | `.terraform.lock.hcl` | Resolución concreta de las constraints |

**Caso real**: alguien en el equipo instala Terraform 1.8.5 y mete `-upgrade` a tu lockfile; tu `required_version = ">= 1.5.0"` lo permite. El lockfile ahora fija provider `random@3.6.3`. En tu máquina con Terraform 1.5.7 el próximo `init` funciona sin problema **porque el lockfile fija el provider pero el core lo da `required_version`**.

## Experimento práctico

Con el directorio del ejemplo 01 todavía inicializado:

```bash
cd /tmp/tf-02-ex01   # (si lo borraste, repite los pasos 1–4 del ej 01)

# 1. Mira el lockfile actual
cat .terraform.lock.hcl

# 2. Bájale la constraint y re-init sin -upgrade
#    edita versions.tf:  version = "~> 3.5"  (ej random)
#    (si tu lockfile tiene 3.6.x ya NO cumple → debería fallar)
terraform init

# 3. Permite upgrade y relaja hacia abajo
terraform init -upgrade

# 4. Ve que la version del lockfile cambió a algo < 3.6
cat .terraform.lock.hcl
```

## Preguntas de reflexión

1. Si borras **solo** `.terraform.lock.hcl` (dejas `.terraform/` intacto) y haces `init`, ¿qué pasa?
2. Si borras **solo** `.terraform/` (dejas el lockfile intacto) y haces `init`, ¿qué pasa?
3. Si corres `terraform init` en un sistema cuyo `h1:` no está en el lockfile, ¿cuál es el error exacto y cómo lo resuelves correctamente (sin borrar el lockfile)?
4. ¿Por qué `constraints` dentro del lockfile es redundante con lo que ya está en `required_providers`?
5. ¿Qué pasaría si el lockfile se commiteara pero `.terraform/` también, en una repo que usan Linux y Mac?
