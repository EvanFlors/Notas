# dkr-07-02 — Quitar un secreto filtrado en `docker history` (forense)

## 1. Identificacion

- **ID:** `dkr-07-02-remove-leaked-secret-from-image`
- **Tecnologia:** docker
- **Modulo:** 07-multistage-buildkit-and-secrets
- **Dificultad:** intermediate
- **Duracion estimada:** 60 min
- **Tipo:** independent (forensic)

## 2. Contexto

El equipo descubrio que una imagen productiva contiene un **token** en `docker history`. Investigando, encuentran que el autor del Dockerfile paso el token con `ARG` y luego "lo borro" con `rm` en un `RUN` posterior. La imagen fue publicada; el token esta comprometido.

En esta actividad eres el ingeniero de seguridad. Tienes que:

1. **Reproducir el leak** (verlo con tus ojos).
2. **Entender por que** el `rm` posterior NO lo borra.
3. **Migrar la receta** al patron correcto: `--mount=type=secret`.
4. **Demostrar con el validador** que la nueva imagen ya no filtra.

Es un ejercicio **independiente**. La solucion de referencia esta en `solution/` pero no la mires hasta terminar.

## 3. Objetivos

- Diagnosticar el leak con `docker history --no-trunc | grep <token>`.
- Explicar por que el `rm` del valor no funciona (capas aditivas).
- Reescribir el Dockerfile para usar `--mount=type=secret,id=github_token`.
- Verificar con el validador que el token no aparece en ninguna capa.
- Dejar una nota en `/tmp/dkr-07-02/FORENSIC.md` explicando el fix (lo chequea el validador).

## 4. Prerrequisitos

- Haber completado `dkr-07-01-rewrite-to-multistage`.
- Haber leido `theory/lesson.md` secciones 5-6.
- Docker Engine ≥ 20.10 con BuildKit (default en ≥ 23) o `DOCKER_BUILDKIT=1`.
- `bash`.
- Infraestructura: workspace en `/tmp/dkr-07-02/`.
- **Costos:** ninguno (local).

## 5. Instrucciones

### Paso 0 — Bootstrap

```bash
cd courses/docker/07-multistage-buildkit-and-secrets/activities/02-remove-leaked-secret-from-image
bash starter/bootstrap.sh
cd /tmp/dkr-07-02
ls
cat Dockerfile
```

El bootstrap deja un `Dockerfile` **con el bug** y una variable `FAKE_TOKEN_abcdef0123456789` que debes usar como "el secreto" durante toda la actividad (es dummy, no vale nada).

### Paso 1 — Reproducir el leak

Construye la imagen pasando el token como `--build-arg`:

```bash
cd /tmp/dkr-07-02
TOKEN="FAKE_TOKEN_abcdef0123456789"
docker build --build-arg API_TOKEN="$TOKEN" -t leaky:bad .
```

Audita `docker history`:

```bash
docker history --no-trunc leaky:bad | grep "FAKE_TOKEN"
```

Debes ver el token en al menos una linea. **Ese es el bug.**

### Paso 2 — Entender por que

El Dockerfile tiene algo asi:

```dockerfile
ARG API_TOKEN
RUN echo "$API_TOKEN" > /app/.secret && do-something < /app/.secret && rm /app/.secret
```

Preguntas que debes poder responder (escribelas en `FORENSIC.md`):

- ¿Por que `rm /app/.secret` no quita el token de la imagen?
- ¿Que capa contiene el token exactamente? (Pista: el `RUN` entero crea una sola capa).
- ¿Por que `ARG API_TOKEN` sin un `--build-arg` tambien podria filtrar? (Si el valor default esta en el Dockerfile).

Respuesta corta: `docker history` lee el **config JSON** de la imagen, donde quedan los `created_by` de cada capa, incluidos los `ARG` sustituidos. Y el filesystem de la capa (hay un `.secret` por un instante) tambien se preserva en el tar de la capa — un `rm` posterior solo agrega una capa que *tapa* el archivo, pero el blob del anterior sigue siendo distribuible.

### Paso 3 — Fix

Reescribe `/tmp/dkr-07-02/Dockerfile` para:

- Agregar `# syntax=docker/dockerfile:1` al tope.
- Eliminar el `ARG API_TOKEN`.
- Usar `RUN --mount=type=secret,id=github_token` para leer el token desde `/run/secrets/github_token`.
- Dentro del `RUN`, leer el token a una variable local (`TOKEN="$(cat /run/secrets/github_token)"`) y usarlo. Nunca lo escribas al filesystem de la imagen.

Construye con `--secret`:

```bash
printf '%s' "FAKE_TOKEN_abcdef0123456789" > /tmp/dkr-07-02-secret
DOCKER_BUILDKIT=1 docker build \
  --secret id=github_token,src=/tmp/dkr-07-02-secret \
  -t leaky:fixed .
rm -f /tmp/dkr-07-02-secret
```

Audita:

```bash
docker history --no-trunc leaky:fixed | grep "FAKE_TOKEN" || echo "no leak"
```

Debe decir `no leak`.

### Paso 4 — Nota forense

Escribe `/tmp/dkr-07-02/FORENSIC.md` con las siguientes secciones (minimas, 3-10 lineas por seccion):

- `## Reproduccion` — comando y output que demuestra el leak.
- `## Causa` — por que `ARG` + `rm` no cierra el hueco.
- `## Fix` — por que `--mount=type=secret` si lo cierra.
- `## Verificacion` — comando final que confirma el fix.

El validador comprueba que el archivo exista y contenga las 4 secciones.

### Paso 5 — Validar

```bash
bash courses/docker/07-multistage-buildkit-and-secrets/activities/02-remove-leaked-secret-from-image/tests/validate.sh
```

## 6. Resultado esperado

- `/tmp/dkr-07-02/Dockerfile` reescrito con `# syntax=docker/dockerfile:1` y `--mount=type=secret`.
- `/tmp/dkr-07-02/FORENSIC.md` presente con las 4 secciones.
- Imagen `leaky:fixed` construida; `docker history --no-trunc leaky:fixed` no contiene `FAKE_TOKEN`.
- Validador imprime `RESULT: X/X checks OK`.

## 7. Criterios de aceptacion

- [ ] `Dockerfile` ya no contiene `ARG` para el token.
- [ ] `Dockerfile` tiene `# syntax=docker/dockerfile:1`.
- [ ] `Dockerfile` usa `--mount=type=secret,id=github_token`.
- [ ] La imagen `leaky:fixed` builda limpiamente.
- [ ] `docker history --no-trunc leaky:fixed` NO menciona `FAKE_TOKEN`.
- [ ] `FORENSIC.md` existe y tiene las 4 secciones esperadas.

## 8. Validacion

```bash
bash courses/docker/07-multistage-buildkit-and-secrets/activities/02-remove-leaked-secret-from-image/tests/validate.sh
```

El validador comprueba:

1. `Dockerfile` tiene `# syntax=docker/dockerfile:1`.
2. `Dockerfile` no contiene `ARG API_TOKEN` ni `ARG GITHUB_TOKEN` ni similares.
3. `Dockerfile` contiene `--mount=type=secret`.
4. Construye `leaky:fixed` con `--secret id=github_token,src=/tmp/dkr-07-02-secret` y revisa `docker history --no-trunc`.
5. El token `FAKE_TOKEN_abcdef0123456789` NO aparece en `docker history`.
6. `FORENSIC.md` existe y menciona `Reproduccion`, `Causa`, `Fix` y `Verificacion`.

Si Docker no esta instalado o el daemon no responde, el validador imprime `SKIP` y sale 0.

## 9. Preguntas de reflexion

- Si el autor hubiera puesto `ENV API_TOKEN=$API_TOKEN` en vez de usarlo en `RUN`, ¿cambiaria algo? ¿Donde se veria el token en ese caso?
- ¿Por que la respuesta "borra el token con `docker image prune`" NO es un fix para el leak en una imagen ya publicada?
- Si publicaste `leaky:bad` a GHCR y ahora quieres "limpiarlo", ¿que pasos reales tomas (ademas de rotar el token)?
- ¿Como se automatiza en CI que un secreto nunca llegue a la imagen? (Pista: policies en el registry, trivy/grype rules, pre-push hooks).

## 10. Extensiones

- **E1** — Construye una tercera version `leaky:env` que use `ENV` en vez de `ARG`. Audita y compara donde aparece el token en cada caso.
- **E2** — Investiga `--secret env=TOKEN_VAR` (secret desde variable de entorno del cliente docker) y adapta tu solucion.
- **E3** — Agrega un step en un workflow de GHA (ver `gha-05`) que use `--secret id=github_token,env=GITHUB_TOKEN` directamente desde `${{ secrets.GITHUB_TOKEN }}`.

## 11. Limpieza

```bash
docker rmi leaky:bad leaky:fixed leaky:env 2>/dev/null || true
rm -f /tmp/dkr-07-02-secret
rm -rf /tmp/dkr-07-02
```
