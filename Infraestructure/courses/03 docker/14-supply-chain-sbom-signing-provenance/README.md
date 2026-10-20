# dkr-14 — Supply chain: SBOM, firma y provenance

## Identificación

- **ID:** `dkr-14-supply-chain-sbom-signing-provenance`
- **Curso:** `docker`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `dkr-09-registries-tags-and-digests`, `dkr-13-runtime-security-and-hardening`, puente con `gha-14-supply-chain-sbom-attestations-signing`.

## Objetivo

Emitir y verificar **evidencias criptográficas de la cadena de suministro** de una imagen OCI: SBOM, resultado de escaneo de vulnerabilidades, firma, attestations de SLSA Provenance y SBOM. Al terminar, un tercero sin acceso a tu pipeline debe poder *demostrar* qué construiste y con qué, descargando únicamente la imagen y sus artefactos relacionados del registry.

## Relación con `gha-14`

El módulo hermano `gha-14` aborda este mismo problema desde el **workflow de CI** (actions `attest-build-provenance`, `attest-sbom`, Sigstore keyless desde el runner). `dkr-14` lo aborda desde el **artefacto Docker**: cómo se construye el SBOM a partir de las capas, cómo cosign empuja al registry, cómo se verifica localmente *sin* GHA, y cómo cambia cuando el firmante no es un IdP sino una clave local. Idealmente se cursan en paralelo.

## Temas y subtemas

1. **SBOM** con `syft`: formatos CycloneDX y SPDX, qué extrae del grafo de capas.
2. **Escaneo** con `trivy` y `grype`: vulnerabilidades (CVE) y misconfiguración; gates por severidad.
3. **Firma con `cosign`**:
   - keyless OIDC (desde GHA o `cosign` interactivo).
   - key pair local (`cosign generate-key-pair`) para dev y para registries air-gapped.
   - cómo la firma se publica como artefacto OCI relacionado (OCI 1.1 referrers / `sha256-<digest>.sig` tag convention).
4. **Verificación**: `cosign verify`, `cosign verify-attestation`, políticas de identity.
5. **Attestations**: predicate SLSA Provenance v1 y SBOM, embebidas al mismo digest.
6. **Policy enforcement** (introducción): Kyverno `verifyImages`, OPA/Gatekeeper, sigstore `policy-controller`.

## Conceptos internos

- Relación entre `image digest`, `SBOM digest` y `attestation digest`: todas apuntan al `sha256:` de la imagen.
- Cómo cosign resuelve el *tag convention* legacy (`sha256-<hex>.sig`) y el *OCI 1.1 referrers API* moderno.
- SLSA v1.0: qué garantiza el **builder** (CI) vs qué debe verificar el **consumer** (runtime / admission).
- Diferencia entre `cosign sign` (firma la imagen) y `cosign attest` (añade un predicate tipado firmado).
- Por qué el SBOM del *source tree* y el SBOM de la *imagen* no son el mismo documento.

## Competencias

- **Conceptual**: diferenciar SBOM, scan report, firma y attestation; explicar el flujo keyless Sigstore y cómo se traduce al modo local; justificar qué parte de SLSA es del productor y qué del consumidor.
- **Operativa**: generar SBOM, firmar imagen, atestar provenance+SBOM, verificar firma y attestations desde una máquina limpia.
- **Arquitectónica**: diseñar un gate de CI que corte un release por CVE crítica; diseñar la política de verificación de un cluster que acepta solo imágenes firmadas por tu identidad.

## Ejemplos

- [`examples/01-syft-sbom/`](examples/01-syft-sbom/) — `syft` genera SBOM CycloneDX y SPDX desde una imagen.
- [`examples/02-trivy-scan-gate/`](examples/02-trivy-scan-gate/) — `trivy image --severity CRITICAL --exit-code 1` como gate.
- [`examples/03-cosign-keyless-and-verify/`](examples/03-cosign-keyless-and-verify/) — firma con cosign (keyless y key pair) y verificación.
- [`examples/04-attest-provenance-and-sbom/`](examples/04-attest-provenance-and-sbom/) — `cosign attest` con predicates SLSA Provenance y SBOM.

## Actividades

- [`activities/01-build-sign-and-verify-pipeline/`](activities/01-build-sign-and-verify-pipeline/) — mini-proyecto dual-mode: cadena completa build → SBOM → scan → sign → attest → verify.
- [`activities/02-fail-build-on-critical-cve/`](activities/02-fail-build-on-critical-cve/) — guided-lab: la starter image tiene CVEs conocidas; el estudiante escribe el gate de `trivy` que corta.

## Entregables

- Imagen OCI publicada (al registry local o a GHCR) con:
  - SBOM CycloneDX (`sbom.cdx.json`).
  - Reporte de scan con decisión binaria (gate).
  - Firma cosign subida al registry como artefacto relacionado.
  - Attestation SLSA Provenance v1 y attestation SBOM.
- Script de verificación reproducible desde otra máquina (`verify.sh`) que descarga únicamente del registry y falla si cualquier evidencia no cuadra.

## Criterios de evaluación

- **Conceptual**: respondes sin consultar cómo se relacionan digest, firma y attestation; explicas por qué cosign firma el digest y nunca el tag.
- **Operativa**: la cadena completa corre end-to-end en modo local; `verify.sh` ejecutado en `/tmp/` sin acceso al pipeline original pasa todas las comprobaciones.
- **Arquitectónica**: justificas qué `--certificate-identity-regexp` usarías en producción y por qué, y qué pasa cuando Rekor no está disponible.

## Modo de ejecución

Todas las actividades y ejemplos son **dual-mode**:

| Modo | Registry | Firmante | Red requerida |
|------|----------|----------|---------------|
| `MODE=local` (default) | `registry:2` en `localhost:5000` | `cosign generate-key-pair` + `--tlog-upload=false` | Solo para pull inicial de imágenes base |
| `MODE=live` | `ghcr.io/<owner>/<repo>` | cosign keyless OIDC via GHA | Sí, GHCR + Fulcio + Rekor |

Si falta cualquier herramienta (`docker`, `syft`, `cosign`, `trivy`) los validators **saltan** la comprobación runtime y verifican la parte estructural (Dockerfiles, workflows YAML, formato CycloneDX). Instrucciones de instalación en `theory/lesson.md` §2.

## Secuencia recomendada

1. Lee `theory/lesson.md` completa (prioriza §3 y §4).
2. Reproduce `examples/` en orden 01 → 04.
3. Haz `activities/02-fail-build-on-critical-cve/` (más corto, consolida escaneo).
4. Haz `activities/01-build-sign-and-verify-pipeline/` (mini-proyecto integrador).
5. Lee `resources/links.md` para profundizar en policy enforcement.

## Siguiente

Fin del curso Docker. Continúa con `kubernetes-01-...` o integra lo aprendido en el capstone CI/CD con `gha-14`.
