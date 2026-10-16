# helm-08 — Repositorios, OCI y provenance

## Identificación

- **ID:** `helm-08-repositories-oci-and-provenance`
- **Curso:** `helm`
- **Nivel:** avanzado
- **Duración estimada:** 3 h
- **Prerrequisitos:** `helm-03-chart-anatomy` (necesitas un chart propio para publicar). Recomendado: curso **docker** Nivel 3+ (OCI registries) y familiaridad con GHCR.

## Objetivo

Publicar y consumir charts con **registries modernos** (OCI, p. ej. GHCR) y **firmarlos** de dos formas:

1. El camino **tradicional** de Helm: `helm package --sign` + GPG → genera `.prov`.
2. El camino **moderno**: **cosign** firmando el artefacto OCI (keyless OIDC o key pair local).

Al terminar el módulo deberías poder publicar tu propio chart firmado a GHCR como OCI y verificarlo desde otro entorno limpio sin confiar en el publisher.

## Alcance

Este módulo cubre:

- Chart repositories HTTP tradicionales: `index.yaml`, `helm repo index`, servir con cualquier bucket/estático.
- **OCI registries** como preferencia moderna: `helm registry login`, `helm push oci://…`, `helm pull oci://…`.
- Versionado con **SemVer** y por qué un registry *rechaza* la re-publicación de la misma versión.
- **Chart signing clásico**: `helm package --sign --key --keyring` → `.tgz` + `.prov` (provenance file con firma GPG). Verificación con `helm verify` y `helm install --verify`.
- **cosign + OCI**: firma del artefacto OCI del chart (modo offline con key pair; modo moderno keyless con OIDC + Fulcio + Rekor).
- **Artifact Hub** como índice público (search, no hosting).
- Límites operativos de un registry: visibility (public/private), pull limits, rate limiting, retención.
- `helm pull` para operación **air-gapped** (sin cluster conectado al registry).

Lo que **no** cubre:

- Admission policies que exijan firma (Kyverno/CUE) → se verán en el curso **kubernetes** / **argocd**.
- Firma de imágenes (ya cubierta en `docker-14`); aquí reutilizamos cosign para charts.
- Pipelines GHA de publicación → se verán en `helm-09` y en el curso **github-actions**.

## Materiales

- **`theory/lesson.md`** — lección profunda en 12 secciones (HTTP vs OCI, SemVer, `.prov` + GPG, cosign + OCI, air-gap, trade-offs).
- **`examples/`** — tres ejemplos ejecutables, todos **dual-mode** (`MODE=local` por defecto con `registry:2`; `MODE=live` contra GHCR real):
  - `01-publish-chart-to-ghcr-oci/` — empaquetar y hacer `helm push oci://`.
  - `02-sign-with-cosign-and-verify/` — firmar el chart OCI con cosign y verificar.
  - `03-air-gapped-pull/` — `helm pull` del `.tgz` y `helm template`/`install` sin acceso al registry.
- **`activities/`**:
  - `01-publish-your-chart-signed/` — guided-lab dual-mode: publica tu chart firmado.
  - `02-verify-in-another-env/` — independiente: valida un chart firmado desde otro entorno limpio sin confiar en el publisher.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `.prov` + GPG y cosign + OCI. Justificar por qué OCI unifica distribución (misma infra que imágenes). Describir el flujo keyless (OIDC → Fulcio → Rekor). |
| Operativa | Publicar un chart a GHCR como OCI, firmarlo con cosign, verificar la firma en un entorno limpio, operar air-gapped con `helm pull`. |
| Arquitectónica | Elegir entre `.prov`+GPG, cosign con key pair o cosign keyless para un escenario dado (team interno, open source, air-gapped, compliance). Decidir visibility, retención y pull limits. |

## Criterios de evaluación

- Chart propio empaquetado con versión SemVer válida, publicado a un registry OCI (local o GHCR) **sin errores de autenticación**.
- Firma del chart generada y verificable:
  - **Mínimo**: cosign en modo local, verificación OK con la pública correcta y FAIL con una pública distinta.
  - **Avanzado**: cosign keyless desde un workflow GHA (o `MODE=live` local con OIDC browser).
- Capacidad de hacer `helm pull oci://…` y `helm template` / `helm install` desde el `.tgz` descargado, sin volver al registry.
- Respuesta argumentada: ¿cuándo `.prov` + GPG tiene sentido y cuándo cosign + OCI?

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin pausar en comandos).
2. Reproduce `examples/01-publish-chart-to-ghcr-oci/` en `MODE=local`.
3. Reproduce `examples/02-sign-with-cosign-and-verify/` en `MODE=local`.
4. Reproduce `examples/03-air-gapped-pull/` en `MODE=local`.
5. Haz `activities/01-publish-your-chart-signed/` (guided-lab).
6. Haz `activities/02-verify-in-another-env/` (independiente — es la que valida comprensión).
7. (Opcional) Repite ejemplo 02 en `MODE=live` contra GHCR con un repo tuyo.

## Siguiente

→ `helm-09-testing-lint-unittest-and-chart-testing`: pipeline completo de validación (`lint` + `template` + `unittest` + `ct install`) antes de que un chart llegue al registry.
