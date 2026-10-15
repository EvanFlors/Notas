# Ejemplo 01 — Dockerfile cache-friendly para Python

Demuestra el **orden canonico** de instrucciones y mide el impacto en el rebuild caliente.

## Requisitos

- Docker Engine ≥ 20.10 (BuildKit habilitado).
- `bash`, `date`.

Si no tienes Docker, el ejemplo se salta con un mensaje claro.

## Que hay

```
.
├── Dockerfile          # orden canonico: lockfile antes del codigo
├── app.py              # app Flask minima (una ruta /health)
├── requirements.txt    # lockfile
├── .dockerignore
└── measure.sh          # cronometra build frio vs caliente
```

## Correr

```bash
cd examples/01-cache-friendly-python
./measure.sh
```

Salida esperada (orden de magnitud en una laptop decente):

```
== Cold build (sin cache) ==
real    0m18.42s
== Warm rebuild tras tocar app.py (debe reusar pip install) ==
real    0m0.84s
```

Lo clave: el segundo build **no vuelve a correr `pip install`**. Lo verificas con:

```bash
docker build --progress=plain -t cache-demo:latest . 2>&1 | grep -E "pip install|CACHED"
```

Deberias ver `CACHED` al lado del step de `pip install`.

## Lo que esta ensenando

1. `COPY requirements.txt ./` esta **antes** de `COPY . .`.
2. El `RUN pip install` depende solo del hash del lockfile.
3. Cambiar `app.py` solo invalida los steps posteriores a `COPY . .`.

## Limpieza

```bash
docker rmi cache-demo:latest 2>/dev/null || true
```
