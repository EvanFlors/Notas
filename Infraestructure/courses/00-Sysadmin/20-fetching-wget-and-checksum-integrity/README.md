# sys-20 — Fetching con wget y verificación por checksum

## Identificación

- **ID:** `sys-20-fetching-wget-and-checksum-integrity`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 2 h
- **Prerrequisitos:** `sys-14-robust-scripts-and-error-handling` (scripts con `set -euo pipefail`, `trap` de limpieza, exit codes semánticos, `shellcheck` limpio).

## Objetivo

Descargar artefactos de Internet de forma **reproducible, resiliente y verificable**. Al terminar deberías poder: elegir `wget` o `curl` con criterio, reanudar transferencias caídas, reintentar con *backoff*, y **nunca** confiar en un binario sin verificar su checksum y, cuando exista, su firma GPG.

## Alcance

Este módulo cubre:

- `wget` vs `curl`: cuándo cada uno (no son intercambiables).
- Flags clave de `wget`: `-c` (resume), `-O` (output), `--tries`, `--timeout`, `--retry-connrefused`, por qué **nunca** `--no-check-certificate`.
- Mirror recursivo con `-m` (y por qué casi nunca es lo que querés).
- Verificación de integridad: `sha256sum --check`, `sha512sum`, publicar un `SHA256SUMS` propio.
- Verificación de autenticidad: `gpg --verify foo.tar.gz.asc foo.tar.gz`, modelo de confianza (web of trust vs. TOFU), por qué **checksum + firma** son defensas distintas.
- Supply chain: revisitar `curl … | bash` y por qué sigue siendo peligroso aun con TLS.
- Escenarios de ataque: MITM activo, compromiso upstream, mirror malicioso, y qué defensa mitiga cada uno.

Lo que **no** cubre (se verá después):

- Autenticación con tokens / `netrc` para APIs privadas.
- `apt`/`dnf` secure repository metadata (se tocó en `sys-06`).
- Firma de artefactos propios con `cosign` / Sigstore (módulo posterior de supply chain).

## Materiales

- **`theory/lesson.md`** — lección profunda (~450 líneas): tabla `wget` vs `curl`, estrategia de retry/backoff, walkthrough SHA256, modelo de confianza GPG, escenarios de ataque y qué mitiga cada defensa.
- **`examples/`**:
  - `01-wget-with-retries/` — descarga con resume y reintentos observando qué cambia en cada flag.
  - `02-verify-sha256-and-gpg/` — pipeline mínimo de verificación con un `SHA256SUMS` de muestra.
- **`activities/`**:
  - `01-wget-with-retries/` — guided-lab (45 min): bajar un artefacto con resume, timeout, reintentos; fallar con exit code no-cero si no se completa.
  - `02-verified-download-pipeline/` — mini-project (75 min): pipeline que descarga artefacto + `.sha256` + `.asc`, verifica checksum, verifica firma, aborta ante cualquier mismatch y loggea cada paso.
- **`resources/links.md`** — `wget(1)`, `curl(1)`, GnuPG handbook, Reproducible Builds, Debian SecureApt.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia operativa `wget` vs `curl`. Decir qué protege un checksum publicado en el **mismo** servidor y qué **no**. Explicar por qué una firma GPG añade garantías que el checksum solo no puede dar. |
| Operativa | Escribir un `wget` con `-c --tries --timeout --retry-connrefused` que falla claro. Verificar un artefacto con `sha256sum --check` y `gpg --verify`. Nunca pasar `--no-check-certificate` ni `-k`. |
| Arquitectónica | Decidir cuándo basta un checksum y cuándo exigir firma. Diseñar un pipeline que aborta en cualquier etapa fallida y deja log auditable. Argumentar por qué `curl … \| bash` es inaceptable para artefactos de producción. |

## Criterios de evaluación

- Las dos actividades pasan `tests/validate.sh`.
- Los scripts entregados comienzan con `#!/usr/bin/env bash` + `set -euo pipefail` y pasan `shellcheck -S warning` sin findings.
- **Ningún** script usa `--no-check-certificate`, `-k`, `--insecure` ni desactiva verificación TLS.
- Puedes responder sin consultar: ¿por qué un `SHA256SUMS` servido desde el mismo host que el tarball no protege contra un atacante que controla el host? ¿qué cambia si el `SHA256SUMS` viene firmado?

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-wget-with-retries/` modificando los flags para ver cómo cambia el comportamiento.
3. Reproduce `examples/02-verify-sha256-and-gpg/` observando qué pasa si corrompés el archivo entre descarga y verificación.
4. Haz `activities/01-wget-with-retries/` (45 min). No mires la solución hasta pasar tests o anclarte 15 min.
5. Haz `activities/02-verified-download-pipeline/` (75 min). Este es el que valida comprensión real.
6. Responde las preguntas de reflexión de la lección sin consultar.

## Siguiente

→ Próximo módulo del curso (gestión de artefactos firmados y repositorios internos).
