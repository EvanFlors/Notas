#!/usr/bin/env bash
# Solución de referencia para tf-06-02-adopt-and-evaluate-a-registry-module.
# Clona terraform-aws-s3-bucket y escribe una EVALUATION.md ejemplo
# (veredicto: adopt). El estudiante puede elegir otro módulo y otro veredicto.
#
# Nota: NO usamos `set -o pipefail`: pasos posteriores podrían usar
# `... | grep -q`, donde un match temprano causa SIGPIPE (exit 141) y pipefail
# lo convertiría en falso negativo.
set -eu

WORK="/tmp/tf-06-02"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git no instalado." >&2
  exit 1
fi

git clone --depth 50 https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git module-src

cat > "$WORK/EVALUATION.md" <<'MD'
# Evaluación: terraform-aws-modules/s3-bucket/aws

## Módulo evaluado

- Nombre: `terraform-aws-modules/s3-bucket/aws`
- URL: <https://github.com/terraform-aws-modules/terraform-aws-s3-bucket>
- Versión evaluada: última release en main al momento del clone (ver `git log -1`).

## Mantenimiento

El repo tiene commits recientes (ver `git log --oneline | head`), releases con tags
semver cada pocas semanas y un maintainer activo (Anton Babenko) con respuesta
visible en issues. El CI de GitHub Actions (`.github/workflows/`) corre
pre-commit y `terraform validate` en PRs. Señal de salud alta.

## Pin de providers

En `versions.tf` del root se declara `required_providers { aws = { source =
"hashicorp/aws", version = ">= 5.27" } }` (verificar número actual). Es un
pin **de piso**: aceptaría cualquier 5.x o 6.x. Suficiente para evitar roturas
viejas; para pin a major, el consumidor debe fijar `~> 5.x` en su propio root.

## Safe defaults

Por default el módulo **no** crea un bucket público: hay un `aws_s3_bucket_public_access_block`
con los cuatro flags en `true` y hay que ser explícito para abrirlo. También
expone `server_side_encryption_configuration` y `versioning` como inputs,
pero no fuerza encryption por default — hay que pasarlo. Es una concesión a
flexibilidad; aceptable con policy as code encima (checkov/OPA).

## Tests

Tiene carpeta `examples/` con casos listos para `terraform init + plan`, y
tests nativos `*.tftest.hcl` para flujos clave. No usa Terratest. Suficiente
para confiar en que `plan` no revienta en los casos documentados.

## Documentación

`README.md` extenso con tabla de Inputs/Outputs generada por `terraform-docs`,
sección "Usage", y enlaces a los ejemplos. Documentación por encima del
promedio del Registry.

## SemVer y breaking changes

Los breaking changes se consignan en CHANGELOG y van a releases major (p. ej.
split histórico `aws_s3_bucket_*` cuando el provider AWS lo exigió fue
señalado con bump de major). Confío en el patrón.

## Superficie (tamaño de API)

Superficie **grande**: ~70+ inputs. Es un trade-off: cubre casos muy variados
(logging, replication, lifecycle, inventory, object lock, intelligent tiering,
etc.) a costo de una curva de aprendizaje y de código HCL largo. Para un
bucket "simple" quizá sea sobre-ingeniería; para una plataforma, encaja.

## Riesgos

- Pin de provider es "de piso", no de techo: el consumidor debe forzar
  `~> 5.0` en su root para evitar sorpresas al mover de major el provider AWS.
- Encryption no es default; sin policy as code encima podría quedar un
  bucket sin SSE si el consumidor se olvida.
- Superficie grande: curva de aprendizaje y riesgo de pasar inputs
  incoherentes entre sí.

## Veredicto

**adopt** con las siguientes condiciones: pin `version = "~> 5.0"` en el
consumer root; policy as code (Conftest/OPA + Checkov) sobre `terraform show
-json` para enforcer encryption y block-public-access; code review obligatorio
en PRs que lo consuman la primera vez. Si estos controles no están, el
veredicto baja a `adopt-con-cambios` (añadir los controles primero).
MD

echo "SETUP OK en $WORK"
echo "Siguiente paso: bash tests/validate.sh"
