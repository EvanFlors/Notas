# dkr-06-02 — Cuando usar `ADD` y cuando usar `COPY`

## 1. Identificacion

- **ID:** `dkr-06-02-add-vs-copy`
- **Tecnologia:** docker
- **Modulo:** 06-dockerfile-idiomatic-and-caching
- **Dificultad:** intermediate
- **Duracion estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

La guia oficial dice *"prefer COPY over ADD"*, pero no da ejemplos concretos de los casos en los que `ADD` sigue siendo correcto. En esta actividad vas a construir tres escenarios reales y, en cada uno, decidir cual es la instruccion correcta y por que.

Los tres escenarios:

1. Copiar codigo de la app (`src/`) a la imagen.
2. Extraer un rootfs tar local (ej. un `app-dist.tar.gz`).
3. Descargar un artefacto remoto por URL.

## 3. Objetivos

- Identificar los tres comportamientos de `ADD` (copia simple, tar auto-extract, URL fetch).
- Justificar en cada escenario por que usas `COPY` o `ADD`.
- Reconocer por que `ADD <url>` es inferior a `RUN curl + checksum` para artefactos remotos.
- Escribir un Dockerfile final funcional con la decision correcta en cada caso.

## 4. Prerrequisitos

- `dkr-03-images-dockerfile-basics`.
- Haber leido `theory/lesson.md` seccion 4.
- Docker Engine ≥ 20.10, `bash`, `tar`, `gzip`, `sha256sum` (o `shasum -a 256`).
- **Costos:** ninguno (los artefactos se generan localmente).

## 5. Instrucciones

### Paso 0 — Bootstrap

```bash
cd courses/docker/06-dockerfile-idiomatic-and-caching/activities/02-add-vs-copy
bash starter/bootstrap.sh
cd /tmp/dkr-06-02
ls
```

Veras:

```
Dockerfile          # vacio — tu lo construyes
src/                # codigo de la app (3 archivos)
dist/app-dist.tar.gz   # tar con assets prebuilt
assets/
  remote-sample.txt    # "artefacto remoto" servido localmente (file:// no funciona, usamos COPY)
  checksum.txt         # sha256 esperado
```

### Paso 1 — Escenario A: copiar `src/`

Escribe la primera instruccion del Dockerfile para copiar `src/` a `/app/`. Debes elegir entre `COPY` y `ADD`. Argumenta en un comentario (`#`) por que elegiste esa.

### Paso 2 — Escenario B: extraer `dist/app-dist.tar.gz`

Debes dejar el contenido de ese tar extraido en `/opt/assets/`. Dos opciones:

- `ADD dist/app-dist.tar.gz /opt/assets/` (auto-extract).
- `COPY dist/app-dist.tar.gz /tmp/ && RUN tar -xzf /tmp/app-dist.tar.gz -C /opt/assets/ && rm /tmp/app-dist.tar.gz`.

Elige una y justifica en comentario. (La respuesta esperada: `ADD` es legitima aqui porque la auto-extraccion es exactamente su caso de uso.)

### Paso 3 — Escenario C: descargar un artefacto remoto con verificacion

Simula el caso real: necesitas un binario de internet con un `sha256` conocido.

Opciones:

- `ADD <url> /opt/bin/tool` — **mal**: no verifica checksum, no cachea bien.
- `ADD --checksum=sha256:... <url> /opt/bin/tool` — mejor, pero sigue sin ejecucion arbitraria.
- `RUN curl -fsSL <url> -o /opt/bin/tool && echo "<sha>  /opt/bin/tool" | sha256sum -c -` — explicito y seguro.

Para esta actividad **no vamos a tocar la red**. Simulamos el patron usando el archivo local `assets/remote-sample.txt` y su checksum en `assets/checksum.txt`. Debes escribir una instruccion `RUN` que:

1. Copie (via `COPY`) el archivo a `/opt/payload`.
2. Verifique el `sha256` contra el valor en `assets/checksum.txt`.

### Paso 4 — Dockerfile final

Tu Dockerfile final debe:

- Partir de `FROM alpine:3.20`.
- Tener los tres bloques (A, B, C) con sus comentarios de justificacion.
- Dejar el contenedor saliendo con exit code 0 tras un `cat` de `/opt/payload` (sanity).

### Paso 5 — Validar

```bash
cd -   # vuelve al directorio de la actividad
bash tests/validate.sh
```

## 6. Resultado esperado

- Imagen `addcopy-lab:latest` construida.
- Contiene `/app/main.py` (copiado con `COPY`).
- Contiene `/opt/assets/README.txt` (extraido del tar).
- Contiene `/opt/payload` con el contenido verificado por sha256.
- El validador imprime `RESULT: 4/4 checks OK`.

## 7. Criterios de aceptacion

- `COPY` usado para codigo plano (escenario A).
- `ADD` usado solo cuando aporta algo (escenario B: auto-extract de tar local).
- Para el "remoto" (escenario C) se usa `RUN` con verificacion de checksum.
- Los comentarios en el Dockerfile explican la decision en cada caso.

## 8. Validacion

```bash
bash tests/validate.sh
```

El validador:

1. Verifica que la imagen builda.
2. Chequea que `/app/main.py` existe.
3. Chequea que `/opt/assets/README.txt` existe (prueba que el tar se extrajo).
4. Chequea que `/opt/payload` existe y su checksum coincide con el esperado.

Si Docker no esta instalado, imprime `SKIP` y sale 0.

## 9. Preguntas de reflexion

- Por que `ADD <url>` no es un buen patron de descarga?
- Si en el escenario B usas `COPY + RUN tar`, cuantas capas tendras vs usando `ADD`? Cambia el tamano final?
- Que diferencia hay entre `ADD --checksum=sha256:...` y verificar en un `RUN`?
- En que caso usarias `ADD` para extraer un tar remoto en lugar de local?

## 10. Extensiones

- Modifica el Dockerfile para que el `COPY` del escenario A use `--chown=1001:1001` y verifica con `docker run --rm addcopy-lab:latest ls -la /app`.
- Reemplaza el tar `.tar.gz` por `.tar.xz` y verifica si `ADD` lo sigue extrayendo (si: tambien soporta bzip2 y xz).
- Reescribe el escenario C usando `ADD --checksum=sha256:...` con una URL real de GitHub Releases (requiere red; opcional).

## 11. Limpieza

```bash
docker rmi addcopy-lab:latest 2>/dev/null || true
rm -rf /tmp/dkr-06-02
```
