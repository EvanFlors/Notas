# Ejemplo 03 — Impacto de `.dockerignore` en contexto y caché

## Concepto que demuestra

El build context se transfiere entero al daemon/BuildKit **antes** de que empiece
el build. Sin `.dockerignore`, cosas como `.git/`, `node_modules/`, `.venv/`,
caches de tests, archivos binarios enormes y — peor — `.env` con secretos viajan
al daemon y potencialmente a la imagen vía un `COPY .`.

Este ejemplo mide la diferencia en bytes y segundos entre un build con y sin
`.dockerignore`, y demuestra cómo cambios en archivos ignorados **no invalidan**
la caché de `COPY`.

## Contexto

Es un error silencioso: el build "funciona" sin `.dockerignore`, pero cada
segundo que pierde el equipo se multiplica por cada CI run, por cada rebuild
local, y por cada desarrollador.

## Objetivo

Al terminar podrás:
- Explicar qué es el build context y dónde empieza/termina.
- Medir el tamaño del contexto con y sin `.dockerignore`.
- Mostrar que un cambio en `.git/` ya no re-ejecuta `COPY .` si está ignorado.

## Prerrequisitos

- Docker 24+.
- `du`, `dd`.

## Archivos del ejemplo

Están en `files/`:

```
files/
├── Dockerfile
├── .dockerignore.good     ← el bueno
├── requirements.txt
├── app.py
└── seed.sh                ← genera "basura" para hacer la diferencia visible
```

### `files/Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

### `files/.dockerignore.good`

```
.git/
__pycache__/
*.pyc
.pytest_cache/
.venv/
venv/
node_modules/
.env
.env.*
*.log
dist/
build/
```

### `files/seed.sh`

Genera un repo con "basura" realista: un `.git/` con historial, un `.venv/`
con binarios ficticios, un `node_modules/` ficticio y logs grandes.

## Ejecución

```bash
# Scratch area
cd /tmp
rm -rf dkr-03-ex-03 && mkdir dkr-03-ex-03 && cd dkr-03-ex-03
cp -r /path/to/examples/03-dockerignore-impact/files/. .

# Pobla con "basura" (git history + node_modules + .venv + logs ~ 50 MB)
bash seed.sh

echo "== Tamano del arbol total =="
du -sh .

# -------- Build 1: SIN .dockerignore --------
# (nos aseguramos de que no exista)
rm -f .dockerignore
echo
echo "== BUILD 1 (sin .dockerignore) =="
time docker build --no-cache -t ignore-demo:no-ignore . 2>&1 | head -3
docker image ls ignore-demo:no-ignore --format 'size: {{.Size}}'

# -------- Build 2: CON .dockerignore --------
cp .dockerignore.good .dockerignore
echo
echo "== BUILD 2 (con .dockerignore) =="
time docker build --no-cache -t ignore-demo:ignored . 2>&1 | head -3
docker image ls ignore-demo:ignored --format 'size: {{.Size}}'

# -------- Caché de COPY: cambio en .git/ --------
echo
echo "== Test de cache: cambio en .git/ =="
# Primera invocacion ya construye con cache
docker build -t ignore-demo:cache-test . >/dev/null
# Cambia algo en .git/ (ignorado)
date > .git/noise.txt
# Rebuild: COPY . . debe seguir en cache
docker build -t ignore-demo:cache-test . 2>&1 | grep -E '(CACHED|COPY \. \.)'
```

## Resultado esperado

Con un árbol de ejemplo de ~55 MB (`seed.sh`), típicamente verás:

| Métrica | Sin `.dockerignore` | Con `.dockerignore` |
|---------|---------------------|---------------------|
| Context transfer | ~55 MB | ~50 KB |
| Tiempo de build | ~15–30 s | ~5–8 s (fresh), < 1 s si todo cacheado |
| Tamaño de imagen final | ~190 MB | ~140 MB |
| `COPY . .` tras cambio en `.git/` | invalida la caché | **sigue en caché** |

El output del build con `.dockerignore` muestra `=> CACHED [4/5] COPY . .` cuando
el archivo cambiado está en la ignorelist. Sin él, muestra `=> [4/5] COPY . .`
(sin CACHED) y la capa se recomputa.

## Interpretación

- **El contexto es lo que viaja al daemon.** Si tu repo pesa 55 MB y tu Dockerfile
  solo usa `requirements.txt` + `app.py`, enviar 55 MB en cada build es puro
  overhead.
- **`.dockerignore` reduce la clave de caché** de `COPY . .`. BuildKit calcula
  el hash de los archivos *incluidos*; si `.git/` está ignorado, cambios en
  `.git/` no cambian el hash → se reusa la capa.
- **Los secretos** merecen el mismo cuidado: un `.env` sin ignorar + `COPY . .`
  = `.env` dentro de la imagen → `docker history --no-trunc` lo delata y
  cualquiera que haga `docker pull` lo tiene.

## Errores frecuentes

- **`.dockerignore` en el subdirectorio equivocado**: debe estar en la raíz del
  **build context** (el `.` de `docker build .`). No sirve ponerlo dentro de un
  subdir.
- **Patrones demasiado agresivos**: `*` por sí solo ignora todo. Combinar
  negaciones (`!app/`) es útil pero frágil; preferir listas explícitas.
- **Olvidar `.env*`**: `.env` sí, pero `.env.local`, `.env.production` también.
  Usar `.env*` o enumerar.
- **Pensar que `.gitignore` sustituye `.dockerignore`**: son archivos separados;
  Docker no mira `.gitignore`.

## Relación con escenarios reales

- CI corriendo en runners con cold caché: un contexto de 500 MB (`.git/` masivo)
  tarda minutos en subir al daemon antes de que empiece el build.
- Equipos que descubren secretos en imágenes publicadas: casi siempre viene de
  un `COPY . .` sin `.dockerignore` adecuado + un `.env` en el repo. Rotar el
  secreto; usar `--mount=type=secret` (`dkr-07`) para builds que necesiten
  tokens.

## Limpieza

```bash
docker rmi ignore-demo:no-ignore ignore-demo:ignored ignore-demo:cache-test 2>/dev/null || true
rm -rf /tmp/dkr-03-ex-03
```
