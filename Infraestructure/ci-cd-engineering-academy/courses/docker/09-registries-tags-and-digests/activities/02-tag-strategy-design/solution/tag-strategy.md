# Tag strategy — platform/orders-api (ADR)

## Context

`platform/orders-api` es un servicio HTTP interno en Python/FastAPI versionado
semver. El repositorio vive en GitHub, el pipeline en GitHub Actions, el
registry autoritativo es GHCR (`ghcr.io/acme/orders-api`), y el deploy ocurre
por Argo CD (GitOps) sobre GKE Autopilot con tres entornos (`dev`, `staging`,
`prod`). El frontend consume preview environments por PR. Compliance SOC 2
exige que todo bit en produccion sea trazable a un commit y auditable despues
del hecho.

## Decision: immutable tags

Publicamos como inmutables:

- `vX.Y.Z` — version semver completa; una por release.
- `sha-<7>` — primeros 7 caracteres del commit SHA; una por build.

Activamos *immutable tags* en el paquete GHCR para `vX.Y.Z` y `sha-*`, de modo
que el registry rechace cualquier re-push bajo esos nombres.

## Decision: mutable tags

Publicamos como mutables:

- `vX.Y` — se re-apunta con cada `vX.Y.z`.
- `vX`   — se re-apunta con cada `vX.y.z`.
- `latest` — se re-apunta con cada release que sale a prod.
- `edge` — ultima build de la rama `main` (post-merge, pre-release).
- `pr-<N>` — ultima build del PR N (sobrescrita en cada push al PR).

## Decision: production pin

Produccion referencia la imagen **por digest** (`ghcr.io/acme/orders-api@sha256:...`).
El flujo:

1. CI construye y pushea con `docker/build-push-action`, que devuelve el digest
   publicado como output del step.
2. CI abre un PR al repo `infra/` cambiando el campo `image:` del `Deployment`
   al nuevo `name@sha256:...` y agregando el tag `vX.Y.Z` en un comentario para
   humanos.
3. Argo CD reconcilia el cluster al estado del repo `infra/`.

No referenciamos tags en el manifiesto de prod bajo ninguna circunstancia.

## Decision: staging and dev pin

- **Staging**: pin por digest, resuelto en el PR de release-candidate; identico
  mecanismo que prod. Esto garantiza que lo que validamos en staging es *byte-
  por-byte* lo que luego promovemos a prod.
- **Dev**: pin por tag `edge` con `imagePullPolicy: Always`. Trade: perdemos
  reproducibilidad pero ganamos ciclo rapido para integracion continua.
- **Preview envs (PR N)**: pin por tag `pr-<N>` + `imagePullPolicy: Always`.

## Decision: base image rotation

`FROM python:3.12-slim` se pinnea en el `Dockerfile` por digest:

```dockerfile
FROM python:3.12-slim@sha256:<digest>  # alias v3.12-slim as of YYYY-MM-DD
```

Renovate corre semanalmente y abre un PR cuando el digest cambia. El PR dispara
CI completo (build + Trivy scan + tests + imagen construida comparada en
tamaño). Mergeamos solo si pasa. Esto nos da upgrades auditados en vez de
upgrades silenciosos.

## Decision: latest

`latest` existe por convencion (usuarios haciendo `docker run` de prueba, demos
en documentacion). Se mueve a cada release salido a prod. **Produccion jamas
lo consume** y lo documentamos como contrato publico. Si decidimos deprecarlo
mas adelante no romperemos nada que importe.

## Rationale

**Reproducibilidad**. Pin por digest en prod y staging asegura que un rollback
o una auditoria pueda reconstruir el bit exacto que estaba corriendo. Los
tags, al ser alias mutables, no sirven como ancla temporal: dos pulls del
mismo tag en momentos distintos pueden traer manifests distintos (si el
registry recibio un re-push o si el *latest* de la base cambio y rebuildeamos).

**Trazabilidad y SOC 2**. El tag `sha-<7>` da una correspondencia 1:1 commit ↔
imagen, y el `vX.Y.Z` da una correspondencia release ↔ imagen. Entre los dos
podemos demostrar en auditoria "el 15 de marzo prod corria `sha256:abc...`,
que corresponde al commit `7f3a1b2`, firmado como release `v1.4.2`". Si
sumamos cosign (ver `dkr-14`) la cadena queda criptograficamente verificable.

**Rate-limits y disponibilidad**. GHCR como autoritativo nos saca del rate-
limit de Docker Hub en el pull-side del cluster. La base `python:3.12-slim`
pinneada a digest sigue viviendo en Docker Hub, pero la pulleamos *una vez por
rebuild de la base*, no en cada pull del cluster.

**Preview environments**. El tag `pr-<N>` + `imagePullPolicy: Always` resuelve
el requisito del frontend sin contaminar los namespaces de prod/staging y sin
exigir pin por digest en lo efimero.

**Rollback**. Con pin por digest en el repo `infra/`, un rollback es un
`git revert` que Argo CD reconcilia. No hay riesgo de "rollback a `v1.4.1` que
alguien reescribio ayer".

## Trade-offs

- Pin por digest en prod incrementa el ruido en el repo `infra/`: cada release
  es un PR con un diff de 64 hex chars. Mitigacion: PR automatico generado
  por CI, con el `vX.Y.Z` en el titulo y en un comentario del manifiesto.
- Pin por digest en la base en el `Dockerfile` incomoda a quienes esperan
  "upgrades automaticos". Lo aceptamos: en SOC 2 "automatico y silencioso" es
  precisamente lo que no queremos.
- Mantener `latest` como mutable contradice formalmente la politica de pin por
  digest, pero es un contrato humano, no automatico. Descartamos no publicarlo
  porque confunde a quienes buscan "la ultima estable" en demos y notebooks.
- Alternativa considerada: usar `cgr.dev/chainguard/python:3.12` como base
  (ya pinneable, rebuilds diarios). La difiero a un ADR aparte porque implica
  cambiar musl/glibc, revisar wheels, y migrar scanning (ver `dkr-11`).
