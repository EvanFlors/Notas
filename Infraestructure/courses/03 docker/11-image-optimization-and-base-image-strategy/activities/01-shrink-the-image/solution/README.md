# Solution

Reconstruir desde `starter/` con este `Dockerfile`:

```
cp solution/Dockerfile /tmp/dkr-11-shrink/Dockerfile
cd /tmp/dkr-11-shrink
docker build -t app:slim .
docker images app:slim          # debe mostrar < 100 MB
docker run --rm app:slim        # debe imprimir 'ok'
```

Observa en `docker history app:slim`:

- Capas de `python:3.12-slim` → no están, no es el runtime.
- `COPY --from=builder /install /usr/local` → una sola capa con las deps.
- No hay `pip`, no hay `apt`, no hay shell.

El tamaño típico queda en ~85 MB (puede variar unos MB por versión de distroless y de cryptography).
