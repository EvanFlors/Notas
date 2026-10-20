# Ejemplo 02 — Bind mount para iterar código en vivo

## Concepto que demuestra

Un **bind mount** del código fuente permite editar en el host y que el contenedor vea los cambios de inmediato, sin reconstruir la imagen. Es el patrón de desarrollo local más común.

Vas a:

1. Crear un pequeño script Python en el host.
2. Correr un contenedor `python:3.12-slim` que ejecute ese script con bind del directorio.
3. Editar el script en el host, re-ejecutar y ver la nueva salida sin tocar la imagen.

## Prerrequisitos

- Docker instalado.
- Un directorio escribible (`/tmp/dkr04-bind` por default).

## Ejecución

```bash
# 0. Preparar directorio limpio en el host
rm -rf /tmp/dkr04-bind
mkdir -p /tmp/dkr04-bind
cd /tmp/dkr04-bind

# 1. Crear app.py
cat > app.py <<'EOF'
import os, sys, time
print(f"hola desde {sys.version.split()[0]} @ {time.strftime('%H:%M:%S')}  mensaje=v1")
EOF

# 2. Correr con bind mount read-only (el contenedor NO debe modificar el código)
docker run --rm \
  --mount type=bind,source=/tmp/dkr04-bind,target=/app,readonly \
  -w /app \
  python:3.12-slim python app.py

# 3. Editar en el host sin rebuild
sed -i.bak 's/v1/v2 (editado en el host)/' app.py && rm -f app.py.bak

# 4. Re-ejecutar: la MISMA imagen ve el código nuevo
docker run --rm \
  --mount type=bind,source=/tmp/dkr04-bind,target=/app,readonly \
  -w /app \
  python:3.12-slim python app.py
```

## Limpieza

```bash
rm -rf /tmp/dkr04-bind
```

## Qué debiste observar

- El segundo `python app.py` imprime `v2 (editado en el host)` sin que hayas hecho `docker build` ni `docker pull`.
- El contenedor ve `/app/app.py` como si fuera parte de su filesystem. En realidad es `/tmp/dkr04-bind/app.py` del host, "pegado".
- Con `:readonly`, si la app intenta escribir sobre `/app/*` obtiene `Read-only file system`. Esto es un escudo contra escrituras accidentales en tu repo.

## Notas de rendimiento

- En **Linux nativo**, el bind mount es tan rápido como el filesystem subyacente.
- En **Docker Desktop (macOS / Windows)**, el bind cruza una capa de FS compartido con la VM (gRPC-FUSE / virtiofs). Para proyectos con muchos archivos pequeños (`node_modules`, repos Rails) notarás latencia; mitigaciones: usar **volumen** para el directorio cacheable (p. ej. `node_modules`) o activar `VirtioFS` en la config de Docker Desktop.

## Para profundizar

- Añade un segundo bind read-write de un `output/` donde la app sí pueda escribir, y verifica que ves los archivos aparecer en el host.
- Prueba `docker run --rm -v "$(pwd)":/app -w /app python:3.12-slim python app.py` con la sintaxis corta y nota qué pasa si borras el directorio del host mientras el contenedor corre.
