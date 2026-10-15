#!/usr/bin/env bash
# Validate k8s-05-02-why-base64-is-not-encryption.
#
# Analiza el ANALYSIS.md que produjo el alumno en /tmp/k8s-05-02/ANALYSIS.md
# (ruta configurable con ANALYSIS_FILE).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Varios checks usan
# `cmd | grep -qi ...`; `grep -q*` cierra el pipe al primer match y provoca
# SIGPIPE (exit 141) en el upstream — pipefail lo convertiría en falso fallo.

ANALYSIS_FILE="${ANALYSIS_FILE:-/tmp/k8s-05-02/ANALYSIS.md}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---------------------------------------------------------------
if [ ! -f "$ANALYSIS_FILE" ]; then
  cat <<EOF
SKIP: no existe $ANALYSIS_FILE.
Crea el archivo siguiendo README.md de la actividad y vuelve a correr este
validador. Si lo pusiste en otra ruta, exporta ANALYSIS_FILE=/ruta/a/ANALYSIS.md.
EOF
  exit 0
fi
ok "ANALYSIS.md encontrado en $ANALYSIS_FILE"

content="$(cat "$ANALYSIS_FILE")"

# --- 1. Secciones mínimas ----------------------------------------------------
for sec in "Setup" "Secret" "base64" "etcd" "Recomendaci"; do
  if echo "$content" | grep -qi "$sec"; then
    ok "menciona sección/tema '$sec'"
  else
    bad "no menciona '$sec'"
  fi
done

# --- 2. Comando kubectl + base64 -d (one-liner de descifrado) ---------------
if echo "$content" | grep -qE "kubectl .*get +secret.*jsonpath.*data" && \
   echo "$content" | grep -q "base64 -d"; then
  ok "incluye el one-liner 'kubectl get secret ... jsonpath=.data... | base64 -d'"
else
  bad "no incluye el one-liner de descifrado (kubectl get secret -o jsonpath + base64 -d)"
fi

# --- 3. Prueba del cleartext: el valor dummy aparece decodificado -----------
# Aceptamos cualquiera de los dummies canónicos (XYZ789 o ABC123) o
# cualquier otro con el prefijo "dummy-canary-".
if echo "$content" | grep -qE "dummy-canary-[A-Za-z0-9]+"; then
  ok "incluye el string cleartext dummy canario decodificado"
else
  bad "no se detecta un dummy canario cleartext (esperado 'dummy-canary-...')"
fi

# --- 4. Grep demonstration: el base64 correspondiente ----------------------
# Caso canónico: ZHVtbXktY2FuYXJ5LVhZWjc4OQ== (base64 de 'dummy-canary-XYZ789')
# Si el alumno usó otro dummy, al menos exigimos un bloque base64 >=16 chars
# junto a su decodificación.
if echo "$content" | grep -qE "ZHVtbXktY2FuYXJ5"; then
  ok "incluye el base64 del dummy canario XYZ789"
elif echo "$content" | grep -qE "[A-Za-z0-9+/]{16,}={0,2}"; then
  ok "incluye un bloque base64 extenso (presuntamente el del Secret)"
else
  bad "no se detecta un bloque base64 (grep demonstration)"
fi

# --- 5. Afirmaciones específicas --------------------------------------------
# "base64 es un encoding, no un cifrado" (o equivalente con esas palabras clave).
if echo "$content" | grep -qiE "base64.*(encoding|codific)" && \
   echo "$content" | grep -qiE "(no es (un )?cifrado|not( an)? encryption|no.*encryp)"; then
  ok "afirma explícitamente 'base64 es encoding, no cifrado'"
else
  bad "no afirma explícitamente que base64 sea encoding y no cifrado"
fi

# EncryptionConfiguration mencionada.
if echo "$content" | grep -q "EncryptionConfiguration"; then
  ok "menciona EncryptionConfiguration"
else
  bad "no menciona EncryptionConfiguration (requerido)"
fi

# etcd + cleartext/base64/sin cifrar.
if echo "$content" | grep -qi "etcd" && \
   echo "$content" | grep -qiE "(cleartext|sin cifrar|en claro|no.*cifrad)"; then
  ok "aclara que en etcd los Secrets están sin cifrar por default"
else
  bad "no aclara explícitamente el estado cleartext en etcd"
fi

# --- 6. Recomendación de External Secrets Operator --------------------------
if echo "$content" | grep -qiE "(External Secrets Operator|\bESO\b)"; then
  ok "recomienda External Secrets Operator (ESO)"
else
  bad "no recomienda External Secrets Operator (ESO)"
fi

# Al menos 3 bullets/razones en la recomendación.
# Heurística: cuentan líneas que empiezan con "- " o un digit "." después del
# marcador "Recomendaci".
rec_block="$(echo "$content" | awk '/[Rr]ecomendaci/{flag=1;next} flag')"
reasons="$(echo "$rec_block" | grep -cE '^[[:space:]]*([-*]|[0-9]+\.)' )"
if [ "$reasons" -ge 3 ]; then
  ok "recomendación tiene $reasons razones (≥3)"
else
  bad "recomendación tiene $reasons razones (<3)"
fi

# --- 7. No pega secretos reales --------------------------------------------
# Heurística muy laxa: si aparecen secretos obvios de proveedores, falla.
if echo "$content" | grep -qE "(AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,})"; then
  bad "ANALYSIS.md contiene lo que parece una credencial real — reemplaza por dummy"
else
  ok "no se detectan credenciales reales en ANALYSIS.md"
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
