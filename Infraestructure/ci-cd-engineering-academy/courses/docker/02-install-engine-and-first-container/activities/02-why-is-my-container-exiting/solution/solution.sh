#!/usr/bin/env bash
# Solución de referencia para dkr-02-02-why-is-my-container-exiting.
# NO usamos `set -o pipefail` para evitar falsos negativos con `... | grep -q`
# (SIGPIPE devuelve 141 en el upstream cuando grep encuentra pronto).

set -eu

WORK="/tmp/dkr-02-02"
mkdir -p "$WORK"
cd "$WORK"

docker rm -f case-1 case-2 case-3 fix-1 fix-2 fix-3 >/dev/null 2>&1 || true

# --- Reproducir los casos rotos ---
docker run --name case-1 alpine echo "hola mundo" >/dev/null
docker run --name case-2 alpine sh -c "exit 2"    >/dev/null 2>&1 || true
docker run --name case-3 alpine sh                >/dev/null 2>&1 || true

# --- Arreglos ---

# fix-1: el comando terminaba (exit 0). Arreglo: comando de larga vida.
docker run -d --name fix-1 alpine sleep 3600 >/dev/null

# fix-2: exit != 0 explícito. Arreglo: comando que termine con 0.
docker run --name fix-2 alpine true >/dev/null

# fix-3: shell sin TTY/stdin. Arreglo: -it + -d (o un comando no-interactivo
# de larga vida). Elegimos el camino canónico de "quiero una shell dentro":
docker run -dit --name fix-3 alpine sh >/dev/null

# --- Entregable escrito ---
cat > diagnostico.md <<'EOF'
# Diagnóstico

## case-1
- Causa: el comando `echo "hola mundo"` terminó bien (exit 0). El contenedor
  no "no arrancó": arrancó, hizo lo suyo y salió. Un contenedor vive mientras
  viva su PID 1.
- Evidencia: `docker inspect --format '{{.State.ExitCode}}' case-1` → 0;
  `docker logs case-1` imprime "hola mundo".
- Arreglo aplicado en fix-1: comando de larga vida (`sleep 300`) para que PID
  1 no termine por sí solo.

## case-2
- Causa: el proceso terminó con exit code 2 (lo pedimos explícitamente con
  `sh -c "exit 2"`). ExitCode != 0 significa "fallo" en la convención Unix.
- Evidencia: `docker inspect --format '{{.State.ExitCode}}' case-2` → 2;
  `docker logs case-2` vacío (no imprime nada).
- Arreglo aplicado en fix-2: comando que termina con 0 (`true`).

## case-3
- Causa: `sh` sin `-t` y sin `-i` no tiene TTY ni stdin conectado. Como shell
  interactiva, al no recibir input, cierra inmediatamente con EOF. ExitCode 0,
  pero el contenedor "se va" al instante.
- Evidencia: `docker inspect --format '{{.State.ExitCode}}' case-3` → 0;
  `docker logs case-3` vacío.
- Arreglo aplicado en fix-3: `-dit` (detached + interactive + tty), para que
  `sh` tenga una pseudo-TTY y no cierre por EOF.
EOF

echo "SETUP OK; corre tests/validate.sh ahora."
