# REFERENCE — sec-01-02-slsa-gap-analysis

> Modelo razonado. No es la única respuesta correcta.

## Sección 1 — Estado actual

**Clasificación: L0 (bordeando L1).**

Justificación:

- Existe un `Dockerfile` versionado y un workflow (eso es L1 potencial).
- Pero el workflow usa **tag mutable** (`:latest`), **no publica digest**, **no publica provenance** ni SBOM, y el token es un **PAT long-lived**.
- Sin provenance publicada, no cumple el mínimo de L1. Por tanto: **L0** operativo con los ingredientes para subir rápido.

## Sección 2 — Nivel objetivo (en 1 trimestre)

**Objetivo: L3** (con `actions/attest-build-provenance@v2` o `slsa-github-generator`).

Por qué L3 y no L2:

- GitHub Actions ya soporta L3 sin esfuerzo heroico desde 2024.
- El salto L2 → L3 es "cambiar la estructura del workflow a un reusable", no "cambiar de plataforma".
- Parar en L2 deja la vulnerabilidad de "autor manipula provenance" abierta — y es la que SolarWinds explotó.

Prerequisitos del equipo:

- Entender `permissions:` en GitHub Actions.
- Saber verificar con `cosign verify-attestation` (para que la publicación tenga valor).

## Sección 3 — Gaps

| ID | Gap | Qué cambia | Esfuerzo (H/M/L) |
|----|-----|------------|------------------|
| G1 | Tag mutable `:latest` | Pasar a tag inmutable por `${{ github.sha }}` + opcionalmente tag SemVer firmado. | L |
| G2 | Sin digest publicado | Usar `docker/build-push-action@v6` que retorna `outputs.digest`; publicarlo en release notes. | L |
| G3 | Sin provenance | Añadir `actions/attest-build-provenance@v2` + `permissions: id-token: write, attestations: write`. | L |
| G4 | Sin SBOM | Añadir step `anchore/sbom-action@v0` con `syft` y adjuntar al release + `attest-sbom` para firmarlo. | M |
| G5 | PAT long-lived (`GHCR_TOKEN`) | Reemplazar por `GITHUB_TOKEN` con `permissions: packages: write` o por OIDC federation con el registry. | M |
| G6 | Actions pineados por tag mutable | Pin de todos los `uses:` por SHA (`actions/checkout@a5ac7e51...`). | M |
| G7 | Sin verificación en consumidor | Añadir policy en admission (Kyverno `verifyImages` o `policy-controller`) con `--certificate-identity` esperado. | H |
| G8 | Builds no aislados (misma job) | Separar build y provenance en jobs distintos (base para L3) o migrar a `slsa-github-generator`. | M |

## Sección 4 — SBOM vs provenance

- **SBOM (Software Bill of Materials)**: inventario de **qué hay dentro** del artefacto — paquetes OS, librerías de lenguaje, versiones, licencias. Formatos: **CycloneDX**, **SPDX**. Herramienta típica: `syft`. Responde: *"¿tengo log4j vulnerable?"*.
- **Provenance**: historia de **cómo** se construyó el artefacto — commit SHA, builder, workflow, timestamp. Formato: **in-toto attestation** (SLSA predicate). Herramienta típica: `actions/attest-build-provenance`. Responde: *"¿este artefacto salió realmente de `main` del repo oficial, construido por el workflow esperado?"*.

**Son ortogonales**:

- Un SBOM impecable con una provenance ausente te deja indefenso ante un ataque tipo SolarWinds (el inventario sería del binario comprometido).
- Una provenance impecable sin SBOM te deja indefenso ante log4shell (sabes de dónde salió el binario pero no si contiene la librería vulnerable).

**Ambos** deberían publicarse como attestations firmadas junto al artefacto.

## Sección 5 — Roadmap

Ordenado por quick wins primero:

1. **G1 + G2** (L): tag inmutable + digest publicado. **Hecho** = release notes muestran `sha256:...`.
2. **G3** (L): `actions/attest-build-provenance@v2` publicando a GHCR. **Hecho** = `cosign download attestation` devuelve algo.
3. **G5** (M): quitar `GHCR_TOKEN`, pasar a `GITHUB_TOKEN`. **Hecho** = PAT revocado.
4. **G6** (M): script que pine todos los actions por SHA (p. ej. `renovate` + preset `helpers:pinGitHubActionDigests`). **Hecho** = `grep '@v' .github/workflows/` vacío.
5. **G4** (M): SBOM con `syft` + `attest-sbom`. **Hecho** = SBOM descargable de GHCR, verificable con `cosign verify-attestation --type cyclonedx`.
6. **G8** (M): migrar a `slsa-github-generator` para L3 real. **Hecho** = provenance tiene `builder.id` del reusable workflow oficial.
7. **G7** (H): Kyverno `verifyImages` en el cluster. **Hecho** = Pod con imagen no firmada es rechazado por admisión.

Esfuerzo total estimado: 1 sprint (quick wins) + 1 trimestre (los demás).

## Sección 6 — Incidentes de referencia

- **SolarWinds (2020)**: el build system fue comprometido e inyectó código malicioso en el binario firmado y distribuido. Lección directa aplicable al pipeline: **la firma del vendor no basta si el builder está comprometido** — provenance non-forgeable (SLSA L3) es la respuesta.
- **log4shell (2021)**: RCE universal por una funcionalidad "legítima" de log4j vía dependencia transitiva. Lección: **sin SBOM** no sabes si tu artefacto incluye la librería; sin SCA no sabes qué versión. Prioriza SBOM + Trivy en CI (G4 + futuros módulos).
- **xz-utils (2024)**: backdoor insertado por un maintainer malicioso tras 2 años de social engineering. Lección: dependencias críticas con pocos maintainers son blanco; audit de `go.mod`/`package.json`/`requirements.txt` incluyendo quién mantiene cada paquete clave.
- **tj-actions/changed-files (2025)**: compromiso de un GitHub Action popular que exfiltraba secretos; pineado por tag mutable propagó el ataque en horas. Lección directa: **pinnear actions por SHA** (G6) y `permissions:` mínimos.

## Punto a repetir hasta que suene aburrido

> SLSA es **cómo** se construyó. SBOM es **qué** hay dentro. **Ambos** firmados **y** verificados. Lo demás es decoración.
