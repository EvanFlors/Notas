# gh-13 — GitHub security and supply chain

## Identificación

- **ID:** `gh-13-github-security-and-supply-chain`
- **Curso:** `git-and-github`
- **Nivel:** producción
- **Duración estimada:** 5–6 h
- **Prerrequisitos:** `gh-12-github-governance-and-automation`.

## Objetivo

Aplicar **seguridad del repositorio y de la cadena de suministro** desde Git/GitHub: firmar commits y tags, eliminar secretos de larga vida, habilitar escaneo y gestión de vulnerabilidades, generar SBOM y attestations SLSA, y federar credenciales con OIDC hacia proveedores cloud.

Al terminar, un repositorio productivo debe tener **todos los controles activos y documentados**, y tú debes poder **auditar un repo ajeno** señalando brechas con justificación.

## Alcance

- **Firma de commits y tags**: SSH signing (recomendación 2024+), GPG (legacy), Sigstore `gitsign` (keyless con OIDC).
- **Verified commits** en GitHub: cómo se verifica una firma del lado del servidor.
- **Dependabot**: alerts, security updates, version updates (`.github/dependabot.yml`).
- **CodeQL / code scanning**: workflows `github/codeql-action`.
- **Secret scanning + push protection**: habilitación en GitHub + defensa en profundidad local (gitleaks/pre-commit).
- **Private vulnerability reporting (PVR)**: canal responsable `/security/advisories`.
- **SBOM** nativo (dependency graph) y export vía API o `gh sbom`.
- **Attestations / SLSA build provenance** con `actions/attest-build-provenance`.
- **OIDC a cloud providers**: eliminar `AWS_ACCESS_KEY_ID` largos; trust policy con `sub` pinning.
- **Secrets de Actions** (repo / org / environment) y variables.
- **Audit log** (org y enterprise).

## No cubre

- Ejecución de un pipeline CI/CD completo (va en el curso **CI/CD**, D5).
- Firma de contenedores con `cosign` end-to-end (sí mencionado como alternativa).
- Hardening de runners self-hosted (D5).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-sign-commits-with-ssh/` — configuración mínima de SSH signing local.
  - `02-dependabot-config/` — `.github/dependabot.yml` cubierto por ecosistema.
  - `03-oidc-to-aws/` — workflow GHA que asume rol en AWS sin secretos.
  - `04-attestation-build-provenance/` — build + `actions/attest-build-provenance`.
- **`activities/`**:
  - `01-enable-secret-scanning-and-push-protection/` — guided-lab, dual-mode (live GitHub o local con gitleaks como defensa en profundidad).
  - `02-sign-and-verify-commits/` — guided-lab, 100% local, SSH signing + verificación con `allowed_signers`.
  - `03-oidc-federation-to-cloud/` — dual-mode: con cuenta AWS real **o** validación local del YAML de workflow + trust policy JSON.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar cómo GitHub verifica una firma (SSH o GPG) y qué significa el badge "Verified". Explicar qué garantiza una attestation SLSA de GitHub Actions (quién, dónde, cómo). Justificar por qué OIDC-to-cloud **elimina** las credenciales de larga vida y qué requiere en el trust policy del lado cloud. |
| Operativa | Configurar firma de commits con SSH y publicar la clave en GitHub. Crear un `dependabot.yml` para varios ecosistemas. Escribir un workflow GHA que asume rol en AWS vía OIDC. Habilitar secret scanning + push protection vía API/UI y como defensa en profundidad local con gitleaks o `pre-commit`. |
| Arquitectónica | Diseñar la **política de seguridad** del repo: qué firmar, qué escanear, qué federar, qué atestiguar, dónde documentarlo. Auditar un repo ajeno y producir un informe de brechas priorizado. |

## Criterios de evaluación

- Capacidad de **auditar** un repo ajeno y señalar brechas con justificación (ejercicio final del lesson).
- Repo propio del alumno con: SSH signing activo, Dependabot configurado, secret scanning + push protection habilitados (si cuenta GitHub lo permite) o alternativa local documentada, un workflow OIDC validado, un workflow que publica un release con attestation.
- Respuesta argumentada a las 8 preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` (secciones 1–6 primero).
2. Reproduce `examples/01-sign-commits-with-ssh/`.
3. Haz `activities/02-sign-and-verify-commits/` (local, no requiere GitHub).
4. Lee `examples/02-dependabot-config/`.
5. Haz `activities/01-enable-secret-scanning-and-push-protection/` (MODE=local recomendado si no quieres tocar un repo real).
6. Lee `examples/03-oidc-to-aws/` y `04-attestation-build-provenance/`.
7. Haz `activities/03-oidc-federation-to-cloud/` (MODE=local por defecto).
8. Lee las secciones 7–12 de la lección (profesional, trade-offs, errores, prácticas, ejercicios, evaluación).
9. Responde las preguntas de evaluación sin consultar.

## Siguiente

Fin del curso **Git & GitHub**. El alumno continúa con el curso de **CI/CD** (D5), que asume este módulo como base para pipelines seguros.
