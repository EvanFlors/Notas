# Capstone Stage 5 — Pipeline: build + container scan + SBOM + firma

> Dominios: **D5 (CI/CD)**, **D6 (Containers)**, **D9 (DevSecOps)**.
> Prerrequisitos: stages 1–4 completados (app FastAPI + tests, versionamiento con tags SemVer, CI con lint/test/SAST/SCA/secret-scan y Dockerfile + Compose).

---

## 1. Resumen de la etapa

**Objetivo.** Construir un pipeline de release que, cuando se publica un tag SemVer (`vX.Y.Z`), produce una imagen de contenedor *firmada*, *escaneada* y con *SBOM + provenance* adjuntos como attestations verificables, publicada en GHCR y referenciada **por digest** (no por tag mutable).

**Delta vs. stage 4.** El stage 4 construía la imagen y la empujaba a un registry. Este stage añade el **supply-chain layer** completo:

| Capa              | Antes (stage 4)                    | Ahora (stage 5)                                                    |
|-------------------|------------------------------------|--------------------------------------------------------------------|
| Build             | `docker build` + push por tag      | `docker/build-push-action` push + output `digest` reutilizable     |
| Vulnerabilidades  | Dependabot / pip-audit             | **Trivy** container scan con gate HIGH/CRITICAL (fail-fast)        |
| Inventario        | Ninguno                            | **Syft** → SBOM SPDX JSON como artifact                            |
| Autenticidad      | Ninguna                            | **Cosign keyless** (OIDC → Fulcio → Rekor)                         |
| Integridad flujo  | Ninguna                            | **SLSA build provenance** (actions/attest-build-provenance)        |
| Verificacion pre-deploy | Ninguna                      | Workflow reutilizable `verify.yml` con `cosign verify` + `gh attestation` |

**Explícitamente fuera.** Admission control en cluster (Kyverno/Gatekeeper), rotación de keys propias (seguimos keyless), policy-as-code sobre el SBOM (CycloneDX + custom OPA), GUAC/dependency-track UI. Todo eso llega en stage 12.

---

## 2. Arquitectura al cierre de esta etapa

```
tag push (vX.Y.Z)
      │
      ▼
┌──────────────────────────────────────────────────────────────┐
│ GitHub Actions runner (ubuntu-latest)                        │
│  ┌─────────┐  ┌───────┐  ┌───────┐  ┌────────┐  ┌─────────┐  │
│  │ checkout│─▶│buildx │─▶│ Trivy │─▶│  Syft  │─▶│ cosign  │  │
│  └─────────┘  └───┬───┘  │  HIGH │  │ (SBOM) │  │ sign    │  │
│                   │      │ CRIT  │  └───┬────┘  │ attest  │  │
│                   │      └───┬───┘      │       │ (SBOM)  │  │
│                   │          │ SARIF    │       └────┬────┘  │
│                   │          ▼          │            │       │
│                   │   Code Scanning     │            ▼       │
│                   │                     │   attest-build-    │
│                   ▼                     │   provenance (SLSA)│
│          ┌─────────────────┐            │            │       │
│          │ push by digest  │◀───────────┘            │       │
│          │ ghcr.io/org/app │                         │       │
│          └────────┬────────┘                         │       │
│                   │   digest sha256:...              │       │
└───────────────────┼──────────────────────────────────┼───────┘
                    ▼                                  ▼
         ┌──────────────────────┐          ┌───────────────────────┐
         │ GHCR (OCI registry)  │◀────────▶│ Sigstore Fulcio+Rekor │
         │  manifests + sig +   │          │ (cert + tlog entry)   │
         │  attestations        │          └───────────────────────┘
         └──────────────────────┘

[deploy workflow] ──▶ uses: ./.github/workflows/verify.yml
                      with: image, digest
                      ──▶ cosign verify (identity + issuer)
                      ──▶ cosign verify-attestation --type spdxjson
                      ──▶ gh attestation verify oci://...
                      ──▶ (si todo ok) proceder a deploy
```

**Entradas.** Un push de tag `vX.Y.Z` tras un merge a `main`.
**Salidas.** Un manifest OCI en GHCR + una firma Sigstore + 2 attestations in-toto (SBOM SPDX, SLSA provenance). Un SARIF en Code Scanning.
**Recursos.** 100% GitHub-hosted + GHCR + Sigstore público. **Coste: $0** (free tier de GHCR + runners + Sigstore).

---

## 3. Prerrequisitos verificados

Antes de ejecutar este stage, confirmar outputs del stage previo:

- [ ] `Dockerfile` multi-stage en la raíz, con un usuario no-root y `HEALTHCHECK`.
- [ ] `.dockerignore` que excluye `.git`, `tests/`, `.venv/`, `__pycache__/`.
- [ ] CI del stage 3 verde en `main` (lint + pytest + SAST + SCA + gitleaks).
- [ ] Permisos en el repo: `Settings → Actions → General → Workflow permissions = Read repository contents and packages permissions`.
- [ ] Permisos de attestations: `Settings → Actions → General → Allow GitHub Actions to create and approve pull requests` OFF; attestations se habilitan via el permission `attestations: write` en el workflow (sin ajustes de repo adicionales en orgs free).
- [ ] GHCR habilitado: el usuario/org tiene permiso para publicar packages (`write:packages` ya cubierto por `GITHUB_TOKEN` cuando el workflow declara `packages: write`).
- [ ] Un tag SemVer de prueba disponible (p. ej. `v0.5.0-rc1`).

Si algo falta, cerrarlo en stage 4 antes de continuar.

---

## 4. Implementación guiada

### 4.1 Archivos a materializar

```
projects/capstone/stages/05-pipeline-build-scan-sbom-sign/
├── README.md
├── trivy.yaml
├── .github/workflows/
│   ├── release.yml       # el pipeline principal
│   └── verify.yml        # workflow reutilizable pre-deploy
├── activities/
│   └── 01-write-signed-release-workflow/
└── resources/
    └── links.md
```

### 4.2 Decisiones y por qué

1. **Trigger solo en tags SemVer**. Cada firma gasta una entrada en el Rekor transparency log y una build en el runner. Firmar cada push a `main` genera ruido no verificable. El tag es el evento de release.

2. **Push por digest, no por tag mutable**. `docker/build-push-action` devuelve el digest exacto (`sha256:...`). Todos los steps subsiguientes (Trivy, Syft, cosign, SLSA) consumen `image@sha256:...`. Si alguien pisa el tag luego, nuestra firma sigue apuntando al bit-identical original. **Un tag no es un identificador criptografico; un digest sí.**

3. **Cosign keyless, no key-based**. Keyless evita el problema `where-do-I-store-the-private-key`. La identidad es el `sub` del id-token OIDC de GitHub (`https://github.com/org/repo/.github/workflows/release.yml@refs/tags/vX.Y.Z`). Fulcio emite un cert efímero (10 min); Rekor registra el commit `(digest, cert, firma)` publicamente. Para verificar, se exige una `--certificate-identity-regexp` y un `--certificate-oidc-issuer` conocidos.

4. **Dos attestations separadas**. El SBOM va como attestation in-toto con `--type spdxjson` (predicate SPDX). La provenance va con `actions/attest-build-provenance` (predicate SLSA v1 build). Separarlas permite que distintos consumidores validen una u otra sin acoplamiento.

5. **Trivy gate `HIGH,CRITICAL` + `ignore-unfixed`**. Fail-fast en lo que podemos arreglar (hay un fix publicado upstream). Lo unfixed se reporta en Code Scanning pero no bloquea: cerraría el pipeline por cosas que no podemos resolver en 5 min.

6. **`permissions: {}` top-level, overrides por job**. Principio de minimo privilegio. El job `build-scan-sign` pide `id-token: write` + `attestations: write` + `packages: write` + `contents: read`. Nada mas.

### 4.3 Comandos de verificacion (local, sin empujar nada)

```bash
# Validar sintaxis de los workflows (requiere actionlint)
actionlint .github/workflows/release.yml .github/workflows/verify.yml

# Validar trivy.yaml (requiere trivy)
trivy config --config trivy.yaml --help >/dev/null

# Validar que la activity scaffoldea y pasa
bash activities/01-write-signed-release-workflow/starter/bootstrap.sh /tmp/cap-05
bash activities/01-write-signed-release-workflow/solution/solve.sh /tmp/cap-05
bash activities/01-write-signed-release-workflow/tests/validate.sh /tmp/cap-05
```

### 4.4 Primer release end-to-end

```bash
git tag v0.5.0-rc1
git push origin v0.5.0-rc1
# ...esperar que el workflow termine...

# Verificacion manual local (sustituir ORG/REPO y el digest real):
DIGEST="sha256:XXXXXXXXXXXXXXXXXXXX"
IMG="ghcr.io/ORG/REPO@${DIGEST}"

cosign verify \
  --certificate-identity-regexp "^https://github\.com/ORG/REPO/\.github/workflows/release\.yml@refs/tags/v.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${IMG}"

cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp "^https://github\.com/ORG/REPO/\.github/workflows/release\.yml@refs/tags/v.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${IMG}"

gh attestation verify "oci://${IMG}" --repo ORG/REPO
```

---

## 5. Actividades del estudiante

| # | Slug                                   | Tipo        | Duracion |
|---|----------------------------------------|-------------|----------|
| 01 | `01-write-signed-release-workflow`    | guided-lab  | 60–90 min |

Detalle completo en `activities/01-write-signed-release-workflow/README.md`.

El validador de la actividad es **dual-mode**:
- `MODE=local` (default): valida que los artefactos del estudiante (`release.yml`, `verify.yml`, `trivy.yaml`) sean correctos sin empujar nada a GHCR ni a Sigstore.
- `MODE=live`: adicionalmente verifica que `cosign` esta instalado y que el repo tiene al menos un tag SemVer para probar end-to-end.

---

## 6. Entregables

El estudiante produce (y commitea en su repo capstone):

- `.github/workflows/release.yml` que al tagear `vX.Y.Z` publica a GHCR por digest.
- `.github/workflows/verify.yml` reutilizable (`workflow_call`), consumible desde cualquier futuro `deploy.yml`.
- `trivy.yaml` con el gate HIGH/CRITICAL + `ignore-unfixed: true`.
- Al menos **una release ejecutada en GitHub** (tag `v0.5.0-rc1`) con:
  - Imagen publicada en `ghcr.io/<org>/<repo>@sha256:...`.
  - 1 firma cosign + 1 attestation SBOM + 1 attestation SLSA en el registry.
  - 1 Code Scanning alert set con los findings de Trivy (o "0 alertas" si limpio).
- Un ADR `docs/adr/0005-supply-chain-attestations.md` justificando: por que keyless, por que push-by-digest, por que SPDX y no CycloneDX en este stage.

---

## 7. Pruebas y criterios de aceptación

Automatizables:

- [ ] `bash activities/01-.../tests/validate.sh /tmp/cap-05` → `ALL CHECKS PASS`.
- [ ] GitHub Action `release.yml` termina en verde para un tag `vX.Y.Z`.
- [ ] `cosign verify` con `--certificate-identity-regexp` + `--certificate-oidc-issuer` apropiados → exit 0.
- [ ] `cosign verify-attestation --type spdxjson` → exit 0.
- [ ] `gh attestation verify oci://...` → exit 0.
- [ ] `trivy image --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed <digest>` → exit 0.
- [ ] SARIF visible en `Security → Code scanning` del repo.

Cualitativos:

- [ ] Ningún workflow usa secrets de larga vida (`AKIA...`, `secrets.DOCKERHUB_*`, PATs). Solo `GITHUB_TOKEN` + OIDC.
- [ ] `permissions:` top-level restrictivo (`{}` o solo `contents: read`), overrides por job.
- [ ] Actions pinneadas por SHA (no por tag mutable como `@v4`).
- [ ] Ningún secret real en el repo. Dummies obvios (`000000000000`, `ORG/REPO`).

---

## 8. Costos y limpieza

**Costo recurrente.** $0.
- Runners `ubuntu-latest`: 2000 min/mes free en repos privados; publicos ilimitados.
- GHCR: free para repos publicos; para privados cuenta en los 500 MB free + egress free a Actions.
- Sigstore Fulcio/Rekor: servicio publico gratuito.

**Limpieza.** Para quitar artefactos de pruebas sin borrar el repo:

```bash
# Borrar la version del package en GHCR (requiere gh + token con delete:packages)
gh api -X DELETE "/user/packages/container/<pkg-name>/versions/<version-id>"

# Borrar el tag git local y remoto
git tag -d v0.5.0-rc1
git push --delete origin v0.5.0-rc1

# Rekor es append-only: las entradas publicas NO se pueden borrar.
# Nunca firmar artefactos con nombres de clientes reales u otra PII.
```

**Guard-rails.**
- Rama protegida en `main`: PR + review + CI verde requeridos.
- `.github/dependabot.yml` para actions (cerrar supply-chain por el lado de las actions mismas).
- Branch protection: `release.yml` solo corre contra tags firmados; opcional, forzar `rulesets` que exijan tag signing.

---

## 9. Riesgos y mitigaciones

| # | Riesgo | Mitigacion |
|---|--------|------------|
| R1 | **Attestation sin verificacion = teatro de seguridad.** Firmar sin que nadie verifique en deploy no cambia la postura real. | `verify.yml` es `workflow_call`; stage 7+ lo invoca obligatoriamente antes de `kubectl apply` / `aws ecs update-service`. Documentar explicito en el ADR. |
| R2 | **Rekor es publico.** Nombres de imagen, repos y timestamps quedan registrados. | Nunca firmar artefactos con nombres de clientes reales; para artefactos privados, considerar `cosign sign --tlog-upload=false` + un Rekor privado (fuera de scope aqui). |
| R3 | **Trivy gate bloquea releases legitimos** cuando aparece un CVE HIGH el viernes a las 6 pm. | `ignore-unfixed: true` reduce ruido. Documentar runbook: (a) bumpear la base image, (b) si no hay fix upstream, excepcion temporal en `trivy.yaml` con TTL + issue trackeando. |

**Si el estudiante se atasca**:
- Pista 1: Si `cosign verify` falla con "no matching signatures", revisar que el `--certificate-identity-regexp` escapa los `.` como `\.`.
- Pista 2: Si el push a GHCR falla con 403, revisar `permissions: packages: write` en el job y que el package *existente* en GHCR tenga visibilidad coherente con el repo.
- Pista 3: Si `actions/attest-build-provenance` falla con "attestation API error", confirmar `permissions: id-token: write` + `attestations: write` en el job.

---

## 10. Puente con la siguiente etapa

**Lo que este stage habilita.**
- Un artefacto *inmutable y verificable* por digest, listo para ser desplegado por IaC (stage 6: Terraform).
- Un workflow reutilizable (`verify.yml`) que cualquier `deploy.yml` futuro puede llamar antes de empujar la imagen a un entorno.

**Qué queda corriendo.** Nada persistente en cloud. Los artefactos viven en GHCR + Sigstore publico; sin coste recurrente.

**Cliffhanger.** Terraform va a crear la red + los recursos que corran esta imagen. ¿Dónde guardas el state? ¿Como separas `dev` de `prod` sin duplicar codigo? ¿Como fuerzas que Terraform solo acepte imagenes firmadas (`terraform validate` no sabe de cosign)? Stage 6 responde las dos primeras; stage 12 responde la tercera via Kyverno.
