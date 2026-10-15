# Ejemplo 02 — `--mount=type=cache` para `pip`

Demuestra como un cache mount de BuildKit **persiste wheels descargados entre builds** sin dejarlos en la imagen final.

## Requisitos

- Docker Engine con BuildKit (default en ≥ 23). Si estas en version vieja: `export DOCKER_BUILDKIT=1`.
- `bash`.

Si no tienes Docker, `build.sh` imprime `SKIP` y sale 0.

## Que hay

```
.
├── Dockerfile          # usa --mount=type=cache,target=/root/.cache/pip
├── app.py
├── requirements.txt    # flask + requests (dos paquetes para que la diferencia sea visible)
├── .dockerignore
└── build.sh            # 2 builds consecutivos; segundo reutiliza el mount
```

## Correr

```bash
cd examples/02-buildkit-cache-mount
./build.sh
```

Deberias observar:

- **Primer build (`--no-cache`):** descarga `flask`, `requests` y todas sus deps de PyPI. 15–40 s dependiendo de red.
- **Segundo build (`--no-cache`):** cache de capas destruido, PERO el mount sigue con los wheels. `pip install` reusa el mount — install termina en 2–5 s.
- **Verificacion:** `docker run --rm cache-mount-demo ls /root/.cache/pip` falla porque el mount no esta en la imagen. 

## Lo que esta ensenando

1. **Cache mounts != layer cache.** Son dos cosas distintas; el mount sobrevive a `--no-cache`.
2. El mount **no se hornea en una capa.** Verifcable con `docker history --no-trunc` + `docker run ls`.
3. En CI, un cache mount compartido entre jobs es la diferencia entre 60s y 5s de install.

## Depurar

Si quieres ver que esta pasando paso a paso:

```bash
docker build --progress=plain -t cache-mount-demo:debug . 2>&1 | tail -40
```

## Limpieza

```bash
docker rmi cache-mount-demo:latest 2>/dev/null || true
docker builder prune -af --filter type=exec.cachemount >/dev/null 2>&1 || true
```
