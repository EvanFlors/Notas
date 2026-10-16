# sec-08 — SBOM y SLSA en práctica

## Identificación

- **ID:** `sec-08-sbom-and-slsa-in-practice`
- **Curso:** `devsecops`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-01` (principios y supply chain overview), `sec-05` (SCA/container scanning con Trivy), curso **docker**, curso **github-actions**.

## Objetivo

Emitir **SBOMs correctos** (CycloneDX y SPDX) con **Syft** sobre código fuente y sobre imágenes de contenedor; entender **SLSA v1.0** como marco operativo (niveles L1→L3), su relación con **provenance**, y cómo **GitHub Actions** actúa hoy como *builder* L3-capable mediante `actions/attest-build-provenance`. Al terminar deberías poder emitir y **verificar** un SBOM localmente, consumirlo con Grype para detectar CVEs, y explicar — con ejemplos — qué garantiza cada nivel SLSA.

## Alcance

Este módulo cubre:

- **Formatos de SBOM**: **CycloneDX** (OWASP, más común en CI y supply chain) vs **SPDX** (Linux Foundation, más común en legal/compliance). Equivalentes funcionales con convenciones distintas.
- **Syft** (`syft <dir>` o `syft <image>`): genera SBOMs en ambos formatos. Diferencias entre **source SBOM** (desde repo), **build SBOM** (de la imagen final) y **runtime SBOM** (lo que está efectivamente cargado en el proceso).
- **Grype** consumiendo SBOMs para producir **vulnerability reports** reproducibles (importante: escanear el SBOM es más rápido y determinista que escanear la imagen cada vez).
- **Publicación**: SBOM como **artefacto** del build **y** como **attestation adjunta a la imagen** en el registry OCI (cosign attach / cosign attest — el detalle de firma se profundiza en `sec-09`).
- **SLSA v1.0**: niveles **L1** (build script), **L2** (hosted builder + provenance autogenerada), **L3** (non-forgeable + builder isolation), **L4** (reservado — two-party review, build hermético estricto).
- **GitHub Actions como builder L3-capable**: `actions/attest-build-provenance` emite provenance SLSA v1.0 firmada vía Sigstore keyless con el OIDC token del runner.
- **Cadena productor → consumidor**: el productor firma y attesta; el consumidor **verifica** antes de desplegar (admisión K8s en `sec-11`).

Lo que **no** cubre (va en módulos posteriores):

- Firma de artefactos con `cosign` keyless end-to-end + Rekor/Fulcio → `sec-09`.
- Admisión K8s que verifica firma + attestation (Kyverno / policy-controller) → `sec-11`.
- Inventario centralizado de SBOMs y queries sobre él → `sec-14`.

Este módulo es **mixto**: parte teórica + un ejemplo *runnable* local (`syft` → SBOM → `grype`) y dos walkthrough (uno de GHA, otro de verificación). Las actividades combinan laboratorio práctico (actividad 01) y análisis escrito (actividad 02).

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — tres ejemplos:
  - `01-syft-cyclonedx-and-spdx/` — **runnable** si tienes `syft` y `grype`. Emite SBOMs en ambos formatos sobre una app Python minimal, los compara y luego escanea el SBOM con Grype. **Skip graceful** si falta tooling.
  - `02-attest-build-provenance-ghactions/` — **walkthrough**: workflow YAML comentado que construye imagen, firma, emite SBOM y provenance SLSA v1.0 via GitHub Actions (sin ejecutar — no se requiere push a GHCR).
  - `03-verify-slsa/` — **walkthrough + runnable parcial**: comandos `cosign verify-attestation` y `gh attestation verify` con `--certificate-identity` + `--certificate-oidc-issuer`. Skip graceful si falta `cosign` o `gh`.
- **`activities/`** — dos actividades independientes:
  - `01-publish-sbom-and-provenance-for-capstone/` — guided-lab: emitir SBOM CycloneDX + SPDX de una imagen local, escanearlo con Grype, dejar un `provenance.json` *stub* L1 escrito a mano y preparar el workflow GHA (sin pushear). Validador estructural + comandos.
  - `02-slsa-level-roadmap/` — independent (análisis): dado un pipeline hipotético hoy en **L0/L1**, documentar el **gap analysis** a **L2** y a **L3** (qué controles concretos faltan, qué cambios en el pipeline, qué métricas).
- **`resources/links.md`** — referencias oficiales (SLSA, Syft, Grype, Sigstore, GHA).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar SBOM (inventario — *qué* hay dentro) de provenance (historia — *cómo* se construyó, por quién, desde qué fuente). Enumerar los niveles SLSA v1.0 y qué garantiza cada uno. Explicar por qué CycloneDX ≠ SPDX pero son funcionalmente intercambiables. |
| Operativa | Emitir SBOM con `syft` en ambos formatos. Consumir el SBOM con `grype`. Escribir un workflow GHA que use `actions/attest-build-provenance`. Verificar una attestation con `cosign verify-attestation --certificate-identity`. |
| Arquitectónica | Diseñar la cadena productor→consumidor de attestations. Decidir qué attestations publicar (SBOM, provenance, test results) y dónde (adjuntas a la imagen OCI vs artefactos del build). |

## Criterios de evaluación

- Explica, con palabras propias, la frase: *"SBOM es inventario; provenance es historia; ambas son necesarias y responden preguntas distintas"*.
- Nombra los **tres tipos** de SBOM (source / build / runtime) y qué revela cada uno.
- Dado un escenario, dice si corresponde SLSA L1, L2 o L3 y qué le falta al pipeline para subir de nivel.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- SBOM CycloneDX + SPDX de una imagen local + reporte Grype sobre el SBOM (sale de la actividad 01).
- Documento `SLSA-ROADMAP.md` con gap analysis L0→L2→L3 (sale de la actividad 02).

## Siguiente módulo

→ `sec-09-signing-and-attestations-with-cosign-sigstore` — firma keyless end-to-end con cosign + Sigstore (Fulcio + Rekor), `cosign attest` sobre SBOM y provenance, verificación con *identity pin*.
