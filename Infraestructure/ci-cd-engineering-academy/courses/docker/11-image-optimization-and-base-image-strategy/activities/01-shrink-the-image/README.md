# dkr-11-01 — Shrink the image

## 1. Identificación

- **ID:** `dkr-11-01-shrink-the-image`
- **Tecnología:** docker
- **Módulo:** `11-image-optimization-and-base-image-strategy`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

Heredaste un servicio Python mínimo (`starter/app.py` + `starter/requirements.txt`) y un `starter/Dockerfile` ingenuo que produce una imagen de ~1 GB. Tu equipo despliega en K8s con autoscaling agresivo y los Pods tardan >15 s en estar `Ready` por el pull. Debes bajar la imagen por debajo de **100 MB** sin perder funcionalidad.

## 3. Objetivos

- Reescribir el Dockerfile a multi-stage con **runtime distroless**.
- Imagen final `app:slim` que:
  - **pesa < 100 MB** (`docker images` tamaño descomprimido),
  - **ejecuta la app**: `docker run --rm app:slim` imprime `ok` y sale 0.
- Mantener la dependencia (`cryptography`) funcionando: no es un simple hello-world.

## 4. Prerrequisitos

- Docker Engine >= 24 con BuildKit (habilitado por default).
- ~1 GB de disco libre para el build.
- No se requieren secretos ni credenciales externas.
- Red para `docker pull` de bases Debian y distroless (`gcr.io`).
- **Costo:** $0 (todo local).

Si no tienes `docker`, el validador reportará SKIP y saldrá OK.

## 5. Instrucciones

1. Copia `starter/` a `/tmp/dkr-11-shrink/` para no ensuciar el repo:

   ```
   mkdir -p /tmp/dkr-11-shrink
   cp -R starter/* /tmp/dkr-11-shrink/
   cd /tmp/dkr-11-shrink
   ```

2. Construye el Dockerfile tal cual viene y mide:

   ```
   docker build -t app:fat .
   docker images app:fat
   ```

   Deberías ver algo cerca de 1 GB. Es el *baseline* que vas a demoler.

3. Edita `Dockerfile` aplicando el patrón:

   - Primer stage: `FROM python:3.12-slim AS builder`, instalar con `pip install --prefix=/install --no-cache-dir -r requirements.txt`.
   - Segundo stage: `FROM gcr.io/distroless/python3-debian12:nonroot`.
   - `COPY --from=builder /install /usr/local`.
   - `COPY app.py /app/app.py`, `WORKDIR /app`.
   - `USER nonroot`.
   - `CMD ["/app/app.py"]` (la base distroless python ya tiene `ENTRYPOINT ["python3"]`).

4. Reconstruye con un tag nuevo:

   ```
   docker build -t app:slim .
   docker images app:slim
   docker run --rm app:slim
   ```

   Debe imprimir `ok` y salir 0, y `docker images` debe mostrar < 100 MB.

5. Compara capas:

   ```
   docker history app:fat
   docker history app:slim
   ```

## 6. Resultado esperado

```
$ docker images | grep '^app '
app          slim    <hash>   30 seconds ago   ~85 MB
app          fat     <hash>   2 minutes ago    ~1.0 GB

$ docker run --rm app:slim
ok
```

## 7. Criterios de aceptación

- Imagen `app:slim` existe.
- `docker image inspect app:slim --format '{{.Size}}'` < **100 * 1024 * 1024** bytes (100 MB).
- `docker run --rm app:slim` imprime una línea que termina en `ok` y sale 0.
- El Dockerfile usa multi-stage (al menos dos `FROM`) y el runtime es una base distroless (o chainguard).
- No hay `pip` ni `apt` en la imagen final (no debe quedar toolchain).

## 8. Validación

```
BASE_DIR=/tmp/dkr-11-shrink bash tests/validate.sh
```

El script asume que trabajaste en `/tmp/dkr-11-shrink/` y que construiste la imagen con tag `app:slim`. Puedes pasar otro directorio con `BASE_DIR=...`.

## 9. Preguntas de reflexión

1. ¿Por qué `--prefix=/install` y no `--target=/install`? ¿Qué diferencia hay?
2. ¿Qué pasa si olvidas `--no-cache-dir`? Mide el tamaño del stage builder antes y después.
3. ¿Por qué `COPY --from=builder /install /usr/local` no trae `pip` ni el toolchain al runtime?
4. ¿Cómo abrirías una shell en `app:slim` para debuggear? (Pista: no puedes. ¿Qué harías en K8s?)
5. ¿Qué cambia si la base runtime es `chainguard/python` en vez de distroless?

## 10. Extensiones

- Agrega una dependencia pesada (`numpy`, `pandas`) y vuelve a medir. ¿Sigue por debajo de 100 MB?
- Reemplaza `pip install` por `uv pip install` en el builder; mide el tiempo de build.
- Construye la misma app sobre `cgr.dev/chainguard/python:latest` y compara con distroless.
- Corre `trivy image app:slim` vs `trivy image app:fat` y cuenta CVEs Critical/High.

## 11. Limpieza

```
docker rmi app:slim app:fat 2>/dev/null || true
rm -rf /tmp/dkr-11-shrink
```
