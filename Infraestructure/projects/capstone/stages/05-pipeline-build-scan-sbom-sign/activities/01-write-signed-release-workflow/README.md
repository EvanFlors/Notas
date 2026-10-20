# Actividad 01 — Release workflow firmado (Trivy + Syft + cosign + SLSA)

## 1. Identificación

- **ID:** `cap-05-01-write-signed-release-workflow`
- **Tecnología:** `capstone`
- **Módulo:** `05-pipeline-build-scan-sbom-sign`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (dual-mode: `local` por defecto, `live` opcional)

## 2. Contexto

El stage 4 publicaba una imagen en GHCR y punto. Un atacante que compromete tu PAT, o que swap-ea un tag mutable, podria colar un binario arbitrario a produccion. Este lab construye el **supply-chain layer** que convierte una imagen en un artefacto *verificable*: digest estable, escaneo gated, SBOM adjunto como attestation in-toto, firma cosign keyless y provenance SLSA de GitHub.

En `MODE=local` escribes los artefactos y el validador los parsea semanticamente (YAML + regex sobre los steps correctos). En `MODE=live` ademas corre `cosign version` para verificar la toolchain.

## 3. Objetivos

- Escribir `.github/workflows/release.yml` con:
  - Trigger `on: push: tags: ['v*.*.*']` + `workflow_dispatch`.
  - `permissions: {}` top-level; el job pide `id-token: write`, `attestations: write`, `packages: write`, `contents: read`.
  - `docker/build-push-action` que publica y expone `outputs.digest`.
  - `aquasecurity/trivy-action` apuntando a `trivy.yaml`, con `exit-code: 1`.
  - `anchore/sbom-action` generando `sbom.spdx.json`.
  - `sigstore/cosign-installer` + `cosign sign` + `cosign attest --type spdxjson` sobre `image@digest`.
  - `actions/attest-build-provenance` con `subject-digest`.
- Escribir `.github/workflows/verify.yml` con `on: workflow_call` + inputs `image` y `digest`; usa `cosign verify` con `--certificate-identity-regexp` + `--certificate-oidc-issuer`.
- Escribir `trivy.yaml` con `severity: [HIGH, CRITICAL]`, `exit-code: 1`, `ignore-unfixed: true`.
- **Prohibiciones**: nada de `AKIA...`, `${{ secrets.DOCKERHUB_* }}`, `${{ secrets.AWS_*_KEY }}`, ni Actions pinneadas por tag (`@v4`) — todas por SHA de 40 hex.

## 4. Prerrequisitos

- `MODE=local`: bash + python3 + PyYAML (`pip install pyyaml`).
- `MODE=live` adicional: `cosign` v2.x y `gh` CLI auth.

**Costos**: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/cap-05
```

Esto crea `/tmp/cap-05/project/` con la estructura vacia y un `README.md` guia.

### 5.2 Tareas

Trabaja dentro de `/tmp/cap-05/project/`:

1. **Crear `trivy.yaml`** en la raiz con el gate HIGH/CRITICAL + `ignore-unfixed: true`.
2. **Crear `.github/workflows/release.yml`** con la secuencia build → trivy → syft → cosign sign → cosign attest SBOM → SLSA provenance → push por digest.
3. **Crear `.github/workflows/verify.yml`** como workflow reutilizable (`workflow_call`) que ejecuta `cosign verify` + `cosign verify-attestation` + `gh attestation verify`.

Si te quedas atascado, la solucion de referencia esta en `solution/solve.sh` (no la mires antes de intentarlo).

### 5.3 Validar

```bash
# MODE=local (default)
bash tests/validate.sh /tmp/cap-05

# MODE=live
MODE=live bash tests/validate.sh /tmp/cap-05
```

### 5.4 Pistas

- Pista 1: El digest sale de `${{ steps.<build-step-id>.outputs.digest }}`. Trivy, Syft y cosign deben consumir `IMAGE@${DIGEST}`, no `IMAGE:tag`.
- Pista 2: `cosign sign` + `cosign attest` no necesitan secrets. Lo que requieren es `permissions: id-token: write` en el job.
- Pista 3: SLSA attestation va con la action `actions/attest-build-provenance`, parametros `subject-name` (sin tag) + `subject-digest` (sha256:...).
- Pista 4: Pinnear por SHA es una condicion dura del supply-chain layer. Un tag `@v4` lo puede repisar su maintainer; un SHA de 40 hex no.

## 6. Resultado esperado

- Tres archivos validos (parsean YAML).
- `release.yml` cumple todas las comprobaciones del validator: permisos, Actions pinneadas por SHA, trivy + syft + cosign + SLSA presentes, consumo por digest, sin secrets largos.
- `verify.yml` cumple: `workflow_call` + `cosign verify` con `--certificate-identity-regexp` y `--certificate-oidc-issuer`.
- `trivy.yaml` cumple: severidades + exit-code + ignore-unfixed.
- `bash tests/validate.sh /tmp/cap-05` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] `release.yml` dispara en tags `v*.*.*`.
- [ ] `release.yml` tiene `permissions: id-token: write` + `attestations: write` + `packages: write` en el job.
- [ ] `release.yml` usa `docker/build-push-action` y los steps subsiguientes consumen `@${{ steps.*.outputs.digest }}`.
- [ ] `release.yml` incluye Trivy con `trivy-config: trivy.yaml` y `exit-code: '1'`.
- [ ] `release.yml` incluye Syft (`anchore/sbom-action`) con `format: spdx-json`.
- [ ] `release.yml` incluye `cosign sign` + `cosign attest --type spdxjson`.
- [ ] `release.yml` incluye `actions/attest-build-provenance` con `subject-digest`.
- [ ] `verify.yml` tiene `workflow_call` + `cosign verify` + flags de identity/issuer.
- [ ] `trivy.yaml` filtra `HIGH`+`CRITICAL`, con `exit-code: 1`, `ignore-unfixed: true`.
- [ ] Cero menciones a `AKIA`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DOCKERHUB_TOKEN`.
- [ ] Todas las `uses:` de Actions pinneadas por SHA de 40 hex.

## 8. Validación

```bash
bash tests/validate.sh /tmp/cap-05
```

Comprueba:

1. Los tres archivos existen y parsean (YAML).
2. En `release.yml`:
   - Trigger incluye tags SemVer.
   - Job tiene los 4 `permissions` requeridos.
   - Hay un step `docker/build-push-action` con `id:` y los steps siguientes referencian `steps.<id>.outputs.digest`.
   - Hay step Trivy con `trivy-config: trivy.yaml`.
   - Hay step Syft (`anchore/sbom-action`) con `format: spdx-json`.
   - Hay step cosign sign + cosign attest spdxjson.
   - Hay step `actions/attest-build-provenance`.
   - Todas las `uses:` tienen pin por SHA de 40 hex.
   - Cero secrets largos prohibidos.
3. En `verify.yml`:
   - Trigger `workflow_call` con inputs `image` + `digest`.
   - `cosign verify` con `--certificate-identity-regexp` y `--certificate-oidc-issuer`.
4. En `trivy.yaml`:
   - `severity` incluye HIGH y CRITICAL.
   - `exit-code: 1`.
   - `ignore-unfixed: true`.

En `MODE=live` adicional: `cosign version` responde.

## 9. Preguntas de reflexión

1. ¿Por que firmar `image@sha256:...` y no `image:v1.2.3`? ¿Que pasa si alguien reusa el tag?
2. ¿Que ganas con una attestation SPDX JSON vs tener el SBOM como simple artifact de GitHub?
3. Cosign keyless deja todo en el log publico Rekor. ¿Que informacion filtras y como lo mitigas en un repo privado comercial?
4. SLSA L3 exige "isolation" del builder. ¿Que te lo da `actions/attest-build-provenance` sin que lo pidas explicito?
5. Un atacante hace un fork del repo, cambia `release.yml` para firmar con su propia identity y abre un PR. ¿Puede firmar como el repo original? ¿Por que no?

## 10. Extensiones

- **E1** — Añade una segunda attestation con el output SARIF de Trivy (predicate custom). Reflexiona: ¿se verifica igual que la SPDX?
- **E2** — Convierte `verify.yml` en una `composite action` reutilizable publicada en el marketplace.
- **E3** — Añade un segundo tag `type=semver,pattern={{major}}` en `metadata-action` y discute: ¿rompe la propiedad "digest estable"? ¿Por que no?

## 11. Limpieza

```bash
rm -rf /tmp/cap-05
```

En `MODE=live`, si has empujado alguna imagen de prueba a GHCR, borrar la version del package desde Settings → Packages del repo (o `gh api -X DELETE /user/packages/container/<pkg>/versions/<id>`).
