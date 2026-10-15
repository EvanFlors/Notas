# gha-14 — Supply chain: SBOM, attestations y firma

## Identificación

- **ID:** `gha-14-supply-chain-sbom-attestations-signing`
- **Curso:** `github-actions`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gha-13-security-hardening`, nociones básicas de Docker (D6 Nivel 1).

## Objetivo

Emitir **evidencias verificables** de qué se construyó, con qué código y por qué pipeline, de modo que un consumidor sin acceso previo al productor pueda **probar criptográficamente** la cadena. Al terminar, debes poder publicar una release que contenga:

1. Una **imagen OCI** firmada con `cosign` (keyless, Sigstore).
2. Un **SBOM** (CycloneDX o SPDX) generado por `syft` / `anchore/sbom-action`.
3. Una **attestation SLSA build provenance** emitida por `actions/attest-build-provenance`.
4. Una **attestation SBOM** emitida por `actions/attest-sbom`.

Y además escribir el workflow **del consumidor** que verifica todo eso antes de usar la imagen.

## Alcance

- SBOM: formatos **CycloneDX** y **SPDX**; qué incluyen y qué no.
- `anchore/sbom-action` como wrapper de `syft`.
- Attestations: `actions/attest-build-provenance@v2` y `actions/attest-sbom@v2` (Sigstore keyless).
- Firma de imágenes OCI con **cosign** (modo keyless OIDC y modo con par de claves local).
- Verificación con `cosign verify`, `cosign verify-attestation` y `gh attestation verify`.
- Modelo **SLSA v1.0**: niveles y qué puede atestiguar GHA automáticamente.
- Publicación a **GHCR** (`ghcr.io/<owner>/<repo>`).
- **Flujo Sigstore completo**: Fulcio (CA efímera) + Rekor (log transparente) + Trusted Root.

Lo que **no** cubre (va en otros módulos):

- Policy enforcement con `cosign policy` o Kyverno/OPA Gatekeeper en Kubernetes → D8/D9.
- SLSA Level 3+ con builders aislados (reusable workflows SLSA, GitHub-hosted larger runners dedicados) — se menciona solo en teoría.
- `in-toto` layouts complejos.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones (incluye diagramas ASCII de Sigstore).
- **`examples/`**:
  - `01-sbom-with-syft/` — generar SBOM CycloneDX/SPDX con `anchore/sbom-action`.
  - `02-attest-build-provenance/` — attestation SLSA v1 nativa, verificable con `gh attestation verify`.
  - `03-cosign-sign-and-verify/` — firma OCI keyless con `cosign` + verificación.
- **`activities/`**:
  - `01-publish-signed-image-to-ghcr/` — guided-lab, dual-mode (**MODE=local** con `registry:2` + cosign con key pair local, o **MODE=live** con GHCR + OIDC real).
  - `02-verify-in-downstream-workflow/` — independiente: te damos una referencia de imagen firmada por *otro* repo y debes escribir el workflow que la verifica correctamente.
- **`resources/links.md`** — documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar el flujo keyless Sigstore (OIDC → Fulcio → certificado efímero → firma → Rekor). Diferenciar attestation vs firma vs SBOM. Enunciar qué nivel SLSA alcanza un workflow GHA típico y qué requeriría subir de nivel. |
| Operativa | Emitir SBOM + build provenance + firma cosign desde un workflow. Verificar desde un workflow consumidor con las claves de identidad del issuer correctas. Diagnosticar un `verification failed`. |
| Arquitectónica | Diseñar la política de verificación de un consumidor (qué identity confiar, qué claims exigir, qué hacer si Rekor no responde). Justificar GHCR vs otro registry en el contexto de attestations. |

## Criterios de evaluación

- Pipeline que publica imagen + SBOM + 2 attestations y es **reproducible**.
- Workflow consumidor que verifica desde un repo distinto con `cosign verify --certificate-identity-regexp` apuntando al workflow correcto.
- Explicación escrita (en respuestas a preguntas de reflexión de las actividades) de qué garantiza y qué NO garantiza cada evidencia.

## Secuencia recomendada

1. Lee `theory/lesson.md` entera (prioriza secciones 4 y 5).
2. Reproduce los 3 `examples/` en orden.
3. Haz `activities/01-publish-signed-image-to-ghcr/` en modo `local` (no requiere GHCR).
4. Si tienes repo propio, rehaz `01` en modo `live`.
5. Haz `activities/02-verify-in-downstream-workflow/` (independiente).
6. Lee `resources/links.md` para referencia.

## Siguiente

→ `gha-15-platform-patterns-and-cost-governance`.
