#!/usr/bin/env bash
# Validate tf-03-01-dependency-graph-exercise.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `terraform state show ... | grep -q ...`; if grep matches
# early it can trigger SIGPIPE (exit 141) on the upstream, and pipefail would
# promote that to a false failure.

WORK="${WORK_DIR:-/tmp/tf-03-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: terraform ---
if ! command -v terraform >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'terraform' no está instalado. Instala desde:
  https://developer.hashicorp.com/terraform/install
Luego verifica: terraform version   (requiere >= 1.5)
EOF
  exit 0
fi

tf_ver="$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"
if [ -z "$tf_ver" ]; then
  tf_ver="$(terraform version 2>/dev/null | head -1 | awk '{print $2}' | tr -d 'v')"
fi
if [ -z "$tf_ver" ]; then
  bad "no pude parsear terraform version"
else
  ok "terraform $tf_ver detectado"
fi

# --- Preflight: docker ---
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: 'docker' no está instalado. Esta actividad requiere el daemon de Docker."
  echo "       Instala: https://docs.docker.com/engine/install/"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde (docker info falla)."
  echo "       Arranca Docker Desktop / colima / 'sudo systemctl start docker'."
  exit 0
fi
ok "docker daemon disponible"

# --- Setup workspace ---
HERE="$(cd "$(dirname "$0")/.." && pwd)"
STARTER="$HERE/starter"
if [ ! -d "$WORK" ] || [ ! -f "$WORK/main.tf" ]; then
  echo "== Preparando workspace en $WORK (desde starter) =="
  mkdir -p "$WORK"
  cp -R "$STARTER/." "$WORK/"
  echo "   Nota: el starter trae TODOs; para validar completo rellénalos primero."
fi

cd "$WORK" || { echo "ERROR: no pude cd a $WORK"; exit 2; }

# --- Chequeo 1: no hay depends_on en main.tf ---
if grep -q 'depends_on' main.tf; then
  bad "main.tf contiene 'depends_on' (el objetivo es que TODO sea implícito)"
else
  ok "main.tf no usa depends_on"
fi

# --- Chequeo 2: image y env referencian otros recursos ---
if grep -qE 'image\s*=\s*docker_image\.nginx\.image_id' main.tf; then
  ok "image referencia docker_image.nginx.image_id"
else
  bad "image no referencia docker_image.nginx.image_id (revisa TODO paso 1)"
fi

if grep -qE 'tls_private_key\.deploy\.public_key_fingerprint_md5' main.tf; then
  ok "env interpola tls_private_key.deploy.public_key_fingerprint_md5"
else
  bad "env no interpola public_key_fingerprint_md5 (revisa TODO paso 2)"
fi

# --- Chequeo 3: init ---
if terraform init -no-color -input=false >/tmp/tf-03-01.init.log 2>&1; then
  ok "terraform init"
else
  bad "terraform init falló (ver /tmp/tf-03-01.init.log)"
  echo -e "$report"
  echo "RESUMEN: $passed OK, $failed FAIL"
  exit 1
fi

# --- Chequeo 4: apply ---
if terraform apply -auto-approve -no-color -input=false >/tmp/tf-03-01.apply.log 2>&1; then
  ok "terraform apply"
else
  bad "terraform apply falló (ver /tmp/tf-03-01.apply.log)"
  echo -e "$report"
  echo "RESUMEN: $passed OK, $failed FAIL"
  exit 1
fi

# --- Chequeo 5: state list contiene los 3 recursos ---
state_list="$(terraform state list 2>/dev/null)"
for addr in tls_private_key.deploy docker_image.nginx docker_container.web; do
  if echo "$state_list" | grep -qx "$addr"; then
    ok "state contiene $addr"
  else
    bad "state NO contiene $addr"
  fi
done

# --- Chequeo 6: contenedor arriba ---
if docker ps --format '{{.Names}}' | grep -qx tf-03-01-web; then
  ok "contenedor tf-03-01-web corriendo"
else
  bad "contenedor tf-03-01-web no corre"
fi

# --- Chequeo 7: nginx responde en 18081 ---
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:18081 || true)"
if [ "$code" = "200" ]; then
  ok "HTTP 200 en localhost:18081"
else
  bad "respuesta HTTP = '$code' (esperado 200) en localhost:18081"
fi

# --- Chequeo 8: env KEY_FINGERPRINT interpolada en el contenedor ---
env_vals="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' tf-03-01-web 2>/dev/null)"
fp_line="$(echo "$env_vals" | grep '^KEY_FINGERPRINT=' || true)"
if [ -z "$fp_line" ]; then
  bad "KEY_FINGERPRINT no está en el env del contenedor"
elif echo "$fp_line" | grep -q '\${'; then
  bad "KEY_FINGERPRINT quedó sin interpolar: $fp_line"
elif [ "$fp_line" = "KEY_FINGERPRINT=" ]; then
  bad "KEY_FINGERPRINT está vacío"
else
  ok "KEY_FINGERPRINT presente e interpolado ($fp_line)"
fi

# --- Chequeo 9: terraform graph produce DOT con los 3 nodos ---
if terraform graph 2>/dev/null | grep -q 'docker_container.web' \
   && terraform graph 2>/dev/null | grep -q 'tls_private_key.deploy'; then
  ok "terraform graph menciona los recursos esperados"
else
  bad "terraform graph no menciona los recursos esperados"
fi

# --- Teardown ---
echo "== Destruyendo stack para dejar el entorno limpio =="
terraform destroy -auto-approve -no-color -input=false >/tmp/tf-03-01.destroy.log 2>&1 \
  && ok "terraform destroy" \
  || bad "terraform destroy falló (ver /tmp/tf-03-01.destroy.log)"

docker rm -f tf-03-01-web >/dev/null 2>&1 || true

echo ""
echo "== Reporte =="
echo -e "$report"
echo "RESUMEN: $passed OK, $failed FAIL"
[ "$failed" -eq 0 ]
