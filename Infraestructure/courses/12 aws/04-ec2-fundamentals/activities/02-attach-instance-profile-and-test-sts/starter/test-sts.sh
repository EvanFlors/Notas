# TODO: anade shebang `#!/usr/bin/env bash` como primera linea
# TODO: anade `set -eu` (aqui NO queremos pipefail porque usamos `| grep -q`)
# TODO: anade un comentario explicando el patron SIGPIPE / sin pipefail
#       (ver courses/git-and-github/.../validate.sh como referencia)

# Script de verificacion que se correria DENTRO de la EC2
# (via `aws ssm start-session` → bash test-sts.sh).

PARAM_ALLOWED="${PARAM_ALLOWED:-/aws-04/demo/foo}"
PARAM_FORBIDDEN="${PARAM_FORBIDDEN:-/aws-04/other/bar}"

echo "== test-sts =="

# -----------------------------------------------------------------------------
# TODO A — verificar identidad asumida
#
# `aws sts get-caller-identity --query Arn --output text` debe contener
# `assumed-role/`. Si no, significa que las credenciales no vienen del
# instance profile.
# -----------------------------------------------------------------------------
echo "-- A. sts get-caller-identity --"
# TODO: haz la llamada y compara con 'assumed-role/'

# -----------------------------------------------------------------------------
# TODO B — verificar IMDSv2 enforced
#
# Paso 1: GET sin token → debe devolver HTTP 401.
#   code=$(curl -o /dev/null -s -w "%{http_code}" http://169.254.169.254/latest/meta-data/)
#   test "$code" = "401" || { echo "FAIL: IMDSv1 abierto"; exit 1; }
#
# Paso 2: PUT para obtener token, luego GET con token → debe devolver 200.
# -----------------------------------------------------------------------------
echo "-- B. IMDSv2 enforced --"
# TODO

# -----------------------------------------------------------------------------
# TODO C — verificar permiso minimo
#
# Paso 1: aws ssm get-parameter --name "$PARAM_ALLOWED" debe funcionar.
# Paso 2: aws ssm get-parameter --name "$PARAM_FORBIDDEN" debe FALLAR con AccessDenied.
#         (Captura stderr; busca "AccessDenied" o "not authorized".)
# -----------------------------------------------------------------------------
echo "-- C. permiso minimo --"
# TODO

echo
echo "OK: todas las verificaciones pasaron."
