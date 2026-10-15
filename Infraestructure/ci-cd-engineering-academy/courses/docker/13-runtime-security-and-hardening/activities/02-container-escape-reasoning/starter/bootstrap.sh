#!/usr/bin/env bash
# Bootstrap for dkr-13-02-container-escape-reasoning.
# Creates /tmp/.../work/ANALYSIS.md with a skeleton the student must fill in.
set -euo pipefail

BASE="${1:-/tmp/dkr13-02}"

if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi

mkdir -p "$BASE/work"

cat > "$BASE/work/ANALYSIS.md" <<'EOF'
# Analisis de vectores de escape de contenedor

> Rellena al menos cuatro de los seis vectores. Por cada vector completa las
> cuatro subsecciones con prosa tecnica concreta. ELIMINA todas las lineas
> marcadas `TODO:` del documento final.

## Vectores analizados

### V1 — Docker socket montado

**Mecanismo**: TODO: explica aqui por que montar /var/run/docker.sock dentro del contenedor permite escapar.

**Deteccion**: TODO: como lo reconoces en `docker inspect` o en el `docker run` original.

**Impacto**: TODO: hasta donde escala el atacante.

**Mitigacion**: TODO: que cambio o alternativa concreta aplicas.


### V2 — --privileged

**Mecanismo**: TODO:

**Deteccion**: TODO:

**Impacto**: TODO:

**Mitigacion**: TODO:


### V3 — CAP_SYS_ADMIN (sin --privileged)

**Mecanismo**: TODO:

**Deteccion**: TODO:

**Impacto**: TODO:

**Mitigacion**: TODO:


### V4 — Montar / del host (o /etc, /root)

**Mecanismo**: TODO:

**Deteccion**: TODO:

**Impacto**: TODO:

**Mitigacion**: TODO:


### V5 — --network host

**Mecanismo**: TODO:

**Deteccion**: TODO:

**Impacto**: TODO:

**Mitigacion**: TODO:


### V6 — Seccomp unconfined / syscall explotable

**Mecanismo**: TODO:

**Deteccion**: TODO:

**Impacto**: TODO:

**Mitigacion**: TODO:


## Conclusion

TODO: resume en 5-10 lineas que patrones encontraste comunes a varios vectores.
EOF

echo "== Bootstrap OK =="
echo "Edita: $BASE/work/ANALYSIS.md"
echo "Rellena al menos CUATRO vectores (quita el 'TODO:' y escribe en espanol)."
echo "Valida con: bash .../tests/validate.sh $BASE"
