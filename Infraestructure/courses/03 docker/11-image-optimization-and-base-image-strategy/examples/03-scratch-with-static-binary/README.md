# Example 03 — `scratch` + static Go binary

Demostrar el caso límite: una imagen que arranca con un filesystem **vacío** (`FROM scratch`) y corre un binario Go estático. Tamaño final: ~2 MB.

## Qué hay aquí

- `main.go` — hello-world Go.
- `Dockerfile` — multi-stage: `golang:1.22-alpine` como builder, `scratch` como runtime.
- `build.sh` — construye, mide, corre, limpia.

No necesitas Go instalado en el host: el builder stage lo trae.

## Correr

```
bash build.sh
```

## Salida esperada

```
building app:scratch ...
built.

TAG                  SIZE
app:scratch          ~2 MB

runtime check:
hello from a scratch image (no shell, no libc, nothing but my binary)

cleanup: docker rmi app:scratch
```

## Qué NO viene con `scratch`

Si tu binario necesitara TLS, timezone data, o `getpwuid` resuelto, tendrías que `COPY` esos archivos a mano desde una imagen con libc (patrón `COPY --from=alpine /etc/ssl/certs/... /etc/ssl/certs/`). En este ejemplo no es necesario — sólo imprime a stdout.

## Por qué no para Python

`FROM scratch` requiere un binario estático. CPython, Node, OpenJDK, etc., son dinámicos y requieren libc, libssl, libz, etc. Para esos lenguajes la respuesta es **distroless**, no `scratch`.

## Limpieza

```
docker rmi app:scratch 2>/dev/null || true
```
