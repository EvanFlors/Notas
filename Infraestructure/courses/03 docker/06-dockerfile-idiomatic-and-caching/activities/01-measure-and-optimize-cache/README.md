# dkr-06-01 — Medir y optimizar la cache de un Dockerfile

## 1. Identificacion

- **ID:** `dkr-06-01-measure-and-optimize-cache`
- **Tecnologia:** docker
- **Modulo:** 06-dockerfile-idiomatic-and-caching
- **Dificultad:** intermediate
- **Duracion estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

Heredas un Dockerfile de una app Python. El rebuild tarda ~30s cada vez que alguien cambia una linea de codigo. El equipo corre el pipeline docenas de veces al dia. Tu trabajo: diagnosticar el problema de cache, reordenar las instrucciones y demostrar que el rebuild caliente baja de minutos a segundos sin cambiar nada de la funcionalidad.

## 3. Objetivos

- Medir el tiempo de un build **frio** y un build **caliente** sobre el Dockerfile original.
- Identificar las instrucciones que invalidan la cache del `pip install`.
- Reescribir el Dockerfile aplicando el orden canonico de `theory/lesson.md` (seccion 3).
- Verificar con el validador que `pip install` queda **cacheado** en el rebuild caliente.
- Lograr rebuild caliente en menos de 5 segundos.

## 4. Prerrequisitos

- Haber completado `dkr-03-images-dockerfile-basics`.
- Haber leido `theory/lesson.md` secciones 1–5 y 11.
- Docker Engine ≥ 20.10 con BuildKit habilitado.
- `bash`, `date`, `python3` (para el bootstrap).
- Red para descargar `python:3.12-slim` y `pip install flask` la primera vez.
- Permisos: tu usuario debe pertenecer al grupo `docker` o usar `sudo`.
- Infraestructura: workspace temporal en `/tmp/dkr-06-01/`.
- **Costos:** ninguno (local).

## 5. Instrucciones

### Paso 0 — Bootstrap

Genera el workspace temporal con el Dockerfile roto y la app:

```bash
cd courses/docker/06-dockerfile-idiomatic-and-caching/activities/01-measure-and-optimize-cache
bash starter/bootstrap.sh
cd /tmp/dkr-06-01
ls
```

Deberias ver `Dockerfile`, `app.py`, `requirements.txt` y `.dockerignore`.

### Paso 1 — Medir el estado inicial

Mide el build frio (sin cache) y luego un rebuild despues de tocar `app.py`:

```bash
docker rmi cache-lab:latest 2>/dev/null || true
time docker build --no-cache -t cache-lab:latest .

# Toca el codigo (simula una edicion)
printf '\n' >> app.py
time docker build -t cache-lab:latest .
```

Anota ambos tiempos. En el rebuild deberias ver que `pip install` **vuelve a correr**. Esa es la patologia.

Usa `--progress=plain` para ver que esta cacheado:

```bash
docker build --progress=plain -t cache-lab:latest . 2>&1 | tail -30
```

### Paso 2 — Diagnosticar

Lee el `Dockerfile` original. Pregunta clave: **que instruccion fuerza que `pip install` corra siempre?** Pista: la respuesta esta en la ubicacion de `COPY . .` relativa a `COPY requirements.txt`.

### Paso 3 — Reescribir el Dockerfile

Reescribe `Dockerfile` siguiendo el orden canonico de la leccion:

1. `FROM python:3.12-slim`
2. `ENV` estables (`PYTHONUNBUFFERED`, etc.)
3. `WORKDIR /app`
4. `COPY requirements.txt ./`
5. `RUN pip install -r requirements.txt`
6. `COPY . .`
7. Usuario no-root, `EXPOSE`, `HEALTHCHECK`, `CMD`.

Mantiene la misma funcionalidad: la app sigue sirviendo en 8000 y responde a `/health`.

### Paso 4 — Verificar

Vuelve a medir:

```bash
docker rmi cache-lab:latest 2>/dev/null || true
time docker build --no-cache -t cache-lab:latest .
printf '\n' >> app.py
time docker build -t cache-lab:latest .
```

El segundo build debe tardar menos de 5 segundos y el output de `--progress=plain` debe mostrar `CACHED` al lado del step de `pip install`.

Corre el validador:

```bash
cd -   # vuelve al directorio de la actividad
bash tests/validate.sh
```

## 6. Resultado esperado

- Rebuild caliente en menos de 5 segundos.
- `docker build --progress=plain` muestra `CACHED` en `RUN pip install`.
- La app sigue respondiendo a `GET /health` con 200.
- El validador imprime `RESULT: 3/3 checks OK`.

## 7. Criterios de aceptacion

- **Funcionalidad:** la imagen sigue arrancando y respondiendo a `/health`.
- **Performance:** rebuild caliente < 5 s (en una laptop razonable).
- **Cache:** `pip install` servido desde cache en el segundo build.
- **Mantenibilidad:** Dockerfile legible, sin lineas muertas, sin `apt-get` sin limpiar.

## 8. Validacion

```bash
bash tests/validate.sh
```

El validador comprueba, en `/tmp/dkr-06-01/`:

1. Que el build frio produce la imagen.
2. Que tras tocar `app.py` y re-buildear, `docker history` muestra el step `pip install` como cacheado (sin size delta nuevo).
3. Que el rebuild caliente tarda menos de 5 segundos.

Si Docker no esta instalado o el daemon no responde, el validador imprime `SKIP` y sale 0.

## 9. Preguntas de reflexion

- Que entra exactamente en el hash de cache de `COPY requirements.txt ./`?
- Por que `COPY . .` arriba de `pip install` invalida la cache incluso si no tocaste `requirements.txt`?
- Si agregas un `README.md` nuevo al repo, deberia invalidar `pip install`? Que ajuste de `.dockerignore` evita que lo haga?
- Como cambia el analisis si usas `--mount=type=cache,target=/root/.cache/pip`?

## 10. Extensiones

- Agrega `--mount=type=cache,target=/root/.cache/pip` al `RUN pip install` y compara el **cold build** con y sin esa linea tras un `docker builder prune`.
- Agrega los 10 OCI labels del ejemplo 02 parametrizados por `--build-arg`.
- Agrega un segundo paquete pesado (ej. `pandas`) a `requirements.txt` y mide la diferencia que hace el cache mount.

## 11. Limpieza

```bash
docker rmi cache-lab:latest 2>/dev/null || true
rm -rf /tmp/dkr-06-01
```
