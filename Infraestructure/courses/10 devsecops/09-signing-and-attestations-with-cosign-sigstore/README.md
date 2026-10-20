# sec-09 — Firma y attestations con cosign / Sigstore

## Identificación

- **ID:** `sec-09-signing-and-attestations-with-cosign-sigstore`
- **Curso:** `devsecops`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-08-sbom-and-slsa-in-practice`. Haber producido un SBOM y entender provenance como concepto.

## Objetivo

Firmar artefactos (imágenes OCI, blobs, attestations) y verificar su firma **end-to-end**, entendiendo tanto el **modelo clásico con claves** como el **modelo keyless de Sigstore** (Fulcio + Rekor). Al terminar deberías poder:

- Explicar por qué el modelo keyless reduce el **blast radius** respecto al modelo con claves custodiadas.
- Firmar una imagen local con cosign (claves generadas) empujada a un `registry:2` y verificarla.
- Diseñar una **política de verificación** keyless con `--certificate-identity` + `--certificate-oidc-issuer` que **no sea insegura**.
- Firmar y verificar una **attestation** (p. ej. SBOM, SLSA provenance) con `cosign attest` / `cosign verify-attestation`.

## Alcance

Este módulo cubre:

- Modelo **clásico con claves** (`cosign generate-key-pair`, `cosign sign --key`, `cosign verify --key`) y sus problemas operativos: rotación, custodia, revocación.
- Modelo **Sigstore keyless**: emisión de **certificado efímero** por **Fulcio** vinculado al OIDC claim (ej: `repo:owner/repo:ref:refs/heads/main` en GitHub Actions), firma con la clave efímera, publicación de la inclusión en **Rekor** (transparency log inmutable). Visión conceptual + walkthrough (ejecutable solo con token OIDC real de CI).
- `cosign sign` y `cosign verify` — **flags obligatorios** para verificación segura (`--certificate-identity` + `--certificate-oidc-issuer`) y por qué omitirlos equivale a aceptar cualquier firma.
- `cosign attest` y `cosign verify-attestation`: cómo asociar una **attestation tipada** (SBOM CycloneDX/SPDX, SLSA provenance, resultados de tests) a una imagen OCI y verificarla con una política de `--type`.
- `gitsign` como aplicación del mismo patrón keyless para firmar **commits** sin GPG.
- Integración con `policy-controller` / Kyverno `verifyImages` en Kubernetes como *gate* en admisión (se profundiza en `sec-11`).

Lo que **no** cubre:

- Policies de admisión en K8s (`sec-11`).
- Emisión de SBOM / provenance (ya cubierto en `sec-08`).
- OPA/Rego para verificación offline (`sec-10`).

## Materiales

- **`theory/lesson.md`** — lección en 10 secciones: del PGP de los noventa al modelo keyless, flujo Fulcio ↔ Rekor, anatomía del certificado efímero, política de verificación segura, attestations tipadas, errores comunes.
- **`examples/`** — ejemplos demostrativos:
  - `01-cosign-sign-keyless/` — walkthrough del flujo keyless desde GitHub Actions (lectura — requiere token OIDC real para ejecutar).
  - `02-attest-sbom-and-provenance/` — anatomía de una attestation CycloneDX + SLSA provenance firmada con cosign (walkthrough).
  - `03-verify-with-identity-pin/` — walkthrough de verificación con `--certificate-identity` y por qué omitirlo es la falla crítica más común.
- **`activities/`** — dos actividades **independientes**:
  - `01-sign-capstone-image/` — firmar una imagen local empujada a un `registry:2` con cosign **key-based** (ejecutable sin acceso a OIDC), empaquetar el flujo en scripts reproducibles.
  - `02-verify-in-clean-env/` — producir una **política de verificación** (`VERIFY-POLICY.md`) que describa cómo un consumidor verificaría la imagen del capstone desde un entorno limpio, incluyendo los pins de identidad y los fallos esperados ante firmas no reconocidas.
- **`resources/links.md`** — referencias oficiales a cosign, Fulcio, Rekor, SLSA.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar firma con clave custodiada vs keyless + Rekor; explicar qué garantiza cada parte (Fulcio = *identity binding*, Rekor = *inclusion log* no-repudiable). |
| Operativa | Firmar y verificar una imagen local con `cosign` + `registry:2`; firmar una attestation SBOM y verificarla por `--type`. |
| Arquitectónica | Diseñar una política de verificación con pin de identidad; detectar y corregir una verificación insegura (p. ej. `cosign verify` sin `--certificate-identity`). |

## Criterios de evaluación

- Firma una imagen local y la verificación `cosign verify --key cosign.pub` pasa; una verificación equivalente con la clave equivocada **falla**.
- Describe el flujo keyless sin saltarse Fulcio ni Rekor.
- Dado el comando `cosign verify ghcr.io/foo/bar:tag` **sin** `--certificate-identity`, detecta la insuficiencia y propone la corrección mínima.
- Explica por qué una attestation sin firma es solo *un JSON junto a la imagen*.

## Entregables

- Imagen local firmada en `registry:2` + verificación reproducible (actividad 01).
- Documento `VERIFY-POLICY.md` con política de verificación para un consumidor en entorno limpio (actividad 02).

## Siguiente módulo

→ `sec-10-policy-as-code-opa-rego-conftest` — expresar políticas como código ejecutable (OPA/Rego/Conftest).
