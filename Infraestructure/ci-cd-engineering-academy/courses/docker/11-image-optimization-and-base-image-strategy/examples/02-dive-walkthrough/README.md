# Example 02 — `dive` walkthrough

`dive` (https://github.com/wagoodman/dive) es una TUI que te muestra el filesystem **por capa** y resalta ineficiencias. Es la mejor herramienta para diagnosticar "¿por qué pesa mi imagen?".

## Requisitos

- `docker`.
- `dive` instalado (`brew install dive`, o binario de releases). Si no lo tienes, este ejemplo **se salta**; `run.sh` detecta y sale OK con un mensaje SKIP.

## Qué hace

1. Construye `app:bloated` — una app Python con un anti-patrón clásico: `pip install` sin `--no-cache-dir` y `rm -rf` en una capa posterior (whiteout, no reduce tamaño).
2. Si `dive` existe, abre la TUI; si no, imprime una explicación textual del árbol de capas con `docker history`.
3. Limpia con `docker rmi`.

## Correr

```
bash run.sh
```

## Qué verías en `dive`

```
┌──────────────── Layers ────────────────┐  ┌───── Current layer contents ─────┐
│ 75 MB  FROM python:3.12-slim           │  │ /usr                              │
│  2 MB  WORKDIR /app                    │  │ /lib                              │
│  1 MB  COPY requirements.txt .         │  │ ...                               │
│ 95 MB  RUN pip install -r requirements │  │ /root/.cache/pip  <-- bloat       │
│  0 MB  RUN rm -rf /root/.cache/pip     │  │ (whiteout; the previous layer     │
│                                         │  │  still ships the bytes)           │
└────────────────────────────────────────┘  └──────────────────────────────────┘

Image efficiency score:  78%
Wasted space:            95 MB   <-- bytes that will never be read
```

El panel inferior izquierdo marca:

- **Layer size** — bytes añadidos por esa capa.
- **Image efficiency** — qué fracción de los bytes de la imagen son realmente alcanzables.
- **Wasted space** — bytes de capas inferiores que fueron borrados en capas superiores (whiteouts).

## Lecciones

- `rm -rf` en una `RUN` posterior **no** reduce el tamaño: el whiteout cuesta aproximadamente lo mismo que el archivo original.
- La forma correcta es borrar **en la misma `RUN`** que creó el bloat, o nunca crearlo (`--no-cache-dir`).
- Las capas de app (código tuyo) suelen ser pequeñas; el peso vive en deps y toolchain.

## Limpieza

Automática al final de `run.sh`. Manual:
```
docker rmi app:bloated 2>/dev/null || true
```
