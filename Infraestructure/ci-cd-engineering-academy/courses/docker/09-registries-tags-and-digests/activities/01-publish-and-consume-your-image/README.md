# Actividad 01 — Publicar y consumir tu imagen (dual-mode)

## 1. Identificación

- **ID:** `dkr-09-01-publish-and-consume-your-image`
- **Tecnología:** `docker`
- **Módulo:** `dkr-09-registries-tags-and-digests`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

El ciclo real de un desarrollador que publica una imagen y luego la consume en otro contexto. Como un `docker push` a GHCR requiere una cuenta de GitHub y queremos que esto corra en cualquier laptop (y en CI), la actividad es **dual-mode**:

- **`MODE=local`** (default): levanta un registry OCI propio con `registry:2` en `localhost:5000`. Todo el ciclo (login no-necesario, tag, push, pin-by-digest, pull) ocurre contra ese registry efímero. Es la ruta por default y la que valida el `tests/validate.sh`.
- **`MODE=live`**: publica contra `ghcr.io/<owner>/dkr-09-publish-demo`. Requiere `gh auth status` OK y scope `write:packages`.

Ambos modos ejercitan los mismos cuatro verbos: `tag`, `push`, `inspect` (para resolver el digest) y `pull @sha256:...`. La diferencia es contra qué registry hablas y si hace falta `docker login`.

## 3. Objetivos

Al terminar:

- Construyes una imagen pequeña a partir de un `Dockerfile` dado.
- La taggeas con **cuatro tags**: `v1.0.0`, `v1.0`, `v1`, `sha-<primeros7>` (del commit git del repo scratch).
- La **pusheas** al registry (local o GHCR según MODE).
- Resuelves el **digest canónico** con `docker inspect` y lo guardas en un archivo (`DIGEST`).
- **Consumes** la imagen pulleando por `@sha256:...` y verificando que corre.
- Escribes una nota corta (`tag-policy.md`) explicando qué tag usarías en producción y por qué.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` secciones 2, 4, 6 y 7.
- Haber reproducido `examples/01-push-to-ghcr/` y `examples/02-pin-by-digest/` en `MODE=local`.
- Docker Engine corriendo.
- Puerto `5000` libre en el host (o `REGISTRY_PORT=5001`).
- Git ≥ 2.30.
- Python 3 (ya en el entorno del curso).
- **Modo `live` (opcional)**: `gh` autenticado con scope `write:packages`. Costo: $0 en repos personales.

**Costos potenciales**: $0. Local registry corre efímero (`--rm`). GHCR es gratis para paquetes personales.

## 5. Instrucciones

### 5.1 Preparar

```bash
# Modo local (default; recomendado la primera vez)
bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/starter/bootstrap.sh /tmp/dkr-09-publish

# Modo live (opcional, requiere gh auth)
MODE=live bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/starter/bootstrap.sh /tmp/dkr-09-publish
```

El bootstrap crea `/tmp/dkr-09-publish/`:

```
repo/
  ├─ Dockerfile        # imagen alpine trivial con un payload identificable
  ├─ app.sh            # script que imprime variables de identificacion
  └─ .git/             # repo con 1 commit base (para que haya un SHA)
publish/
  (vacio — aqui pondras DIGEST y tag-policy.md)
```

En `MODE=local` además levanta `registry:2` en `localhost:${REGISTRY_PORT:-5000}` (si no corre ya).

### 5.2 Construir y taggear

Desde `/tmp/dkr-09-publish/repo/`:

```bash
cd /tmp/dkr-09-publish/repo
docker build -t publish-demo:dev .
```

Elige la base del registry (en local, `localhost:5000/evan/publish-demo`; en live, `ghcr.io/<owner>/dkr-09-publish-demo`). Taggea con **cuatro** tags:

```bash
REG=localhost:5000/evan/publish-demo      # ajusta en MODE=live
GIT_SHA=$(git rev-parse --short=7 HEAD)   # 7 chars

docker tag publish-demo:dev "$REG:v1.0.0"
docker tag publish-demo:dev "$REG:v1.0"
docker tag publish-demo:dev "$REG:v1"
docker tag publish-demo:dev "$REG:sha-$GIT_SHA"
```

### 5.3 Push

En `MODE=live` haz `docker login ghcr.io` primero:

```bash
# MODE=live solamente:
gh auth token | docker login ghcr.io -u "$(gh api user -q .login)" --password-stdin
```

Luego:

```bash
docker push "$REG:v1.0.0"
docker push "$REG:v1.0"
docker push "$REG:v1"
docker push "$REG:sha-$GIT_SHA"
```

(También puedes `docker push "$REG" --all-tags` si prefieres.)

### 5.4 Resolver el digest y persistirlo

```bash
mkdir -p /tmp/dkr-09-publish/publish

docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$REG:v1.0.0" \
  | grep "^$REG@" | head -n1 > /tmp/dkr-09-publish/publish/DIGEST

cat /tmp/dkr-09-publish/publish/DIGEST
# → localhost:5000/evan/publish-demo@sha256:<64 hex>
```

Si `RepoDigests` está vacío (puede pasar si no hiciste pull nuevo tras el push), haz `docker pull "$REG:v1.0.0"` y repite.

### 5.5 Consumir por digest

```bash
DIGEST_REF=$(cat /tmp/dkr-09-publish/publish/DIGEST)
docker pull "$DIGEST_REF"
docker run --rm "$DIGEST_REF"
# Debe imprimir algo como:
#   publish-demo | hostname=... | date=...
```

### 5.6 Escribir la nota de política

Crea `/tmp/dkr-09-publish/publish/tag-policy.md` con *al menos* estas tres secciones (una o dos frases cada una):

```markdown
# Politica de tags — publish-demo

## Tags publicados
Enumera los cuatro: `v1.0.0`, `v1.0`, `v1`, `sha-<7>`.

## Cual usa produccion
Indica cual (idealmente: pin por digest `publish-demo@sha256:...`) y por que.

## Cual usan los humanos
Indica cual (por legibilidad en logs y en demos) y asume la mutabilidad.
```

### 5.7 Validar

```bash
bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/tests/validate.sh /tmp/dkr-09-publish
```

El validador (siempre en `MODE=local` por default):

1. Verifica que el `registry:2` esté corriendo en `localhost:${REGISTRY_PORT:-5000}`.
2. Hace `GET /v2/evan/publish-demo/tags/list` y comprueba que estén los **cuatro tags**.
3. Para `v1.0.0`, resuelve su digest desde el registry y lo compara con `publish/DIGEST`.
4. Hace un `docker pull` por digest y corre el contenedor; verifica que imprime la cadena identificadora.
5. Verifica que `publish/tag-policy.md` existe y tiene las tres secciones esperadas.

## 6. Resultado esperado

- `localhost:5000` (o GHCR) tiene **cuatro tags** publicados que apuntan todos al mismo digest.
- `publish/DIGEST` contiene `localhost:5000/evan/publish-demo@sha256:<64 hex>` (o la URL GHCR equivalente).
- `publish/tag-policy.md` existe con las tres secciones.
- `tests/validate.sh` termina con `RESULT: 5/5 checks OK`.

## 7. Criterios de aceptación

- [ ] Imagen construida localmente (`publish-demo:dev` o equivalente).
- [ ] Cuatro tags pusheados (`v1.0.0`, `v1.0`, `v1`, `sha-<7>`) al namespace correcto.
- [ ] `publish/DIGEST` contiene un `name@sha256:<64 hex>` válido.
- [ ] Un `docker pull $(cat DIGEST)` seguido de `docker run --rm` imprime la cadena identificadora.
- [ ] `publish/tag-policy.md` existe con secciones **Tags publicados**, **Cual usa produccion**, **Cual usan los humanos**.
- [ ] (MODE=live) el paquete es visible en `https://github.com/<owner>?tab=packages`.

## 8. Validación

```bash
# modo local (default)
bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/tests/validate.sh /tmp/dkr-09-publish

# modo live (requiere push a GHCR y OWNER/env configurados)
MODE=live OWNER="<tu-usuario>" bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/tests/validate.sh /tmp/dkr-09-publish
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si pusheas una **quinta** versión al tag `v1`? ¿Qué garantiza (y qué no) el digest que ya resolviste en `DIGEST`?
2. ¿Por qué `v1.0.0` es "más inmutable en espíritu" que `v1`, si en el registry *técnicamente* ambos son reescribibles?
3. En `MODE=live`, ¿quién tiene permiso de pushear a `ghcr.io/<tu-usuario>/dkr-09-publish-demo`? ¿Qué pasa si otro colaborador quiere pushear?
4. Si tu cluster de Kubernetes consume `image: ghcr.io/<tu>/dkr-09-publish-demo:v1`, ¿qué puede ir mal en un rollout de 20 réplicas? ¿Cómo lo evitas?
5. ¿Qué cambio mínimo convertiría este flujo en un release automatizado desde GitHub Actions? (Pistas: `docker/login-action`, `docker/metadata-action`, `permissions: packages: write`.)

## 10. Extensiones (opcional)

- **E1** — Activa *immutable tags* en GHCR (en el paquete, "Package settings → Immutable tags"). Intenta re-pushear `v1.0.0`; observa el error.
- **E2** — Añade a tu `Dockerfile` las labels OCI estándar (`org.opencontainers.image.source`, `.revision`, `.created`). Re-publica. Lee las labels en el registry.
- **E3** — Escribe un workflow mínimo `.github/workflows/publish.yml` que replique esto automáticamente al pushear un tag `v*.*.*`.
- **E4** — Pullea una imagen pública conocida (`alpine:3.20`), resuelve su digest, y comparte con un compañero. Que ambos pulllen `alpine@sha256:...` y confirmen que el ID local coincide.

## 11. Limpieza

```bash
# Local
docker stop dkr09-registry 2>/dev/null || true
docker rmi publish-demo:dev 2>/dev/null || true
docker rmi $(docker images 'localhost:5000/evan/publish-demo' -q) 2>/dev/null || true
rm -rf /tmp/dkr-09-publish

# Live (si publicaste a GHCR)
gh api -X DELETE "/user/packages/container/dkr-09-publish-demo" 2>/dev/null || true
```
