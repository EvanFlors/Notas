# Actividad 01 — Publicar imagen firmada con SBOM y provenance

## 1. Identificación

- **ID:** `gha-14-01-publish-signed-image-to-ghcr`
- **Tecnología:** `github-actions`
- **Módulo:** `14-supply-chain-sbom-attestations-signing`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (dual-mode: `local` sin red / `live` con GHCR + OIDC)

## 2. Contexto

Vas a producir un release *verificable*: una imagen OCI que lleva consigo (vía referrers OCI 1.1 en el registry y vía attestations de GitHub) una **firma criptográfica**, un **SBOM** y, en modo live, una **attestation SLSA build provenance**. Esto es la base operativa de supply chain security moderna.

Dos modos:

- **MODE=local** (default) — levanta un `registry:2` en `localhost:5050`, construye imagen, firma con `cosign` usando un par de claves generado localmente (sin red hacia Sigstore pública). Es lo que el validator corre por default y lo que te permite practicar sin cuenta de GitHub ni GHCR.
- **MODE=live** — publica a GHCR real desde un workflow con `id-token: write`. Firma keyless con Sigstore. Emite attestations. Requiere repo propio con Actions habilitado.

## 3. Objetivos

- Construir imagen OCI con `docker build` y pushearla a un registry (local o GHCR).
- Generar SBOM CycloneDX de la imagen (no del source) con `syft`.
- Firmar la imagen por **digest** (no por tag) con `cosign`.
- En live: emitir `actions/attest-build-provenance` y `actions/attest-sbom`.
- Verificar firma y attestation localmente antes de dar por hecho el release.
- Diseñar el bloque `permissions:` del workflow con escalada mínima.

## 4. Prerrequisitos

- **Software**: Docker ≥ 20.10, `bash`, `jq`.
- **Opcional**: `cosign` ≥ 2.0 y `syft` ≥ 1.0. Si faltan, el validator pasa a modo *SKIP runtime, verifica YAML*.
- **Cuenta GitHub** solo para MODE=live.
- **Costos**: ninguno en local; en live, consume minutos de Actions y storage de GHCR (plan free lo cubre para prácticas).
- Haber leído `theory/lesson.md` secciones 4 y 5.
- Haber reproducido `examples/02-attest-build-provenance/` y `examples/03-cosign-sign-and-verify/`.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-14-01
```

Esto crea:

```
/tmp/gha-14-01/
├── Dockerfile                       (imagen demo)
├── .github/workflows/               (vacío — tú añades release.yml)
├── keys/                            (vacío; MODE=local escribirá aquí)
├── sbom/                            (vacío; se llena al correr)
└── NOTES.md                         (recordatorio de pasos)
```

### 5.2 Tareas

Trabaja en `/tmp/gha-14-01/`:

#### A — MODE=local (siempre lo haces)

1. Arranca un `registry:2` en `localhost:5050` (el bootstrap no lo arranca por ti; es parte del aprendizaje). Nombre sugerido: `gha-14-01-registry`.
2. Construye la imagen: `docker build -t localhost:5050/app:v0.1.0 .`.
3. Push: `docker push localhost:5050/app:v0.1.0`.
4. Captura el digest exacto: `docker inspect ... --format='{{index .RepoDigests 0}}'`.
5. Genera SBOM: `syft -o cyclonedx-json=sbom/sbom.cdx.json localhost:5050/app@sha256:...` (si no tienes syft, SKIP este paso; el validator avisa).
6. Genera key pair cosign en `keys/cosign.key` + `keys/cosign.pub` (`COSIGN_PASSWORD=''`).
7. Firma: `cosign sign --key keys/cosign.key --tlog-upload=false --yes localhost:5050/app@sha256:...`.
8. Verifica: `cosign verify --key keys/cosign.pub --insecure-ignore-tlog localhost:5050/app@sha256:...`.

#### B — Escribir el workflow (siempre, aunque no lo corras en Actions)

Crea `.github/workflows/release.yml` que, en un tag `v*`, haga:

- Checkout, buildx, login a GHCR.
- Build + push a `ghcr.io/${{ github.repository }}/app:${{ github.ref_name }}`.
- Install syft, genera `sbom.cdx.json`.
- `actions/attest-build-provenance@v2` con `subject-name` y `subject-digest`.
- `actions/attest-sbom@v2` con el mismo subject + `sbom-path`.
- `cosign sign --yes` sobre el digest (modo keyless).

Permissions **mínimas**:

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
```

**Nada más**. Si usas `permissions: write-all` el validator te marca FAIL.

#### C — (Opcional) MODE=live

Si tienes un repo donde puedes correr Actions:

1. Copia el workflow a `.github/workflows/release.yml` del repo.
2. Push un tag `v0.1.0`.
3. Observa el run completarse.
4. Desde tu máquina (fuera del repo), verifica:
   ```bash
   gh attestation verify oci://ghcr.io/OWNER/REPO/app:v0.1.0 --repo OWNER/REPO
   cosign verify ghcr.io/OWNER/REPO/app:v0.1.0 \
     --certificate-identity-regexp "^https://github\.com/OWNER/REPO/\.github/workflows/release\.yml@refs/tags/v.*$" \
     --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
   ```

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/gha-14-01
```

El validator comprueba, en orden:

1. Estructura del directorio y presencia del Dockerfile.
2. Workflow `release.yml` existe y es YAML válido.
3. Workflow declara **exactamente** los permissions esperados (ni más, ni menos).
4. Workflow usa `actions/attest-build-provenance`, `actions/attest-sbom`, `sigstore/cosign-installer` (o invoca `cosign` directo), `anchore/sbom-action` o `syft`.
5. **Runtime (si docker + cosign disponibles)**: hay una imagen pusheada en `localhost:5050`, hay firma, `cosign verify` pasa, y existe `sbom/sbom.cdx.json`.
6. Si falta alguna herramienta, SKIP el chunk con mensaje claro y suma al resumen.

### 5.4 Pistas

- Pista 1: El digest exacto después de push: `docker inspect localhost:5050/app:v0.1.0 --format='{{index .RepoDigests 0}}'`.
- Pista 2: Para que `cosign sign --key` no intente hablar con Rekor público, usa `--tlog-upload=false`.
- Pista 3: Verifica siempre por `@sha256:...`, no por `:tag`.
- Pista 4: Si el runtime check falla con `write_package: denied`, asegúrate de `docker login` al registry (en local no hace falta; en live el `docker/login-action` ya lo hace con `GITHUB_TOKEN`).

### Solución de referencia

`solution/solve-local.sh` — reproduce el flujo MODE=local completo.
`solution/release.yml` — el workflow correcto para MODE=live.

**Mírala solo después de intentarlo.**

## 6. Resultado esperado

- MODE=local: `cosign verify --key keys/cosign.pub ...` imprime JSON con el digest esperado.
- Workflow `release.yml` válido y con permissions mínimos.
- `tests/validate.sh` termina con `RESULT: ALL CHECKS PASS` (o con SKIPs documentados si falta tooling).

## 7. Criterios de aceptación

- [ ] Imagen pusheada y firmada por digest en el registry local.
- [ ] `sbom/sbom.cdx.json` existe y es JSON válido con `components[]`.
- [ ] `release.yml` presente, YAML válido, permissions mínimos, usa `attest-build-provenance` + `attest-sbom` + cosign.
- [ ] (Live, opcional) `gh attestation verify` pasa desde fuera del repo.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gha-14-01
```

Reporte por check con `OK`/`FAIL`/`SKIP` y diagnóstico.

## 9. Preguntas de reflexión

1. **¿Por qué firmar por digest y no por tag?** Da un escenario concreto donde firmar por tag deja huecos.
2. **El workflow usa `permissions: id-token: write`**. ¿Qué daño podría hacer un atacante que compromete una action usada por el workflow si pudiera leer ese token? ¿Qué mitigación existe más allá de "pin a SHA"?
3. **En MODE=local firmas con un key pair en disco**. Enumera 3 razones por las que esto es peor que keyless en producción, y 1 razón por la que puede ser mejor en un contexto específico.
4. **`cosign verify` sin `--certificate-identity-regexp` ni `--certificate-oidc-issuer`** — ¿qué garantiza y qué deja de garantizar?
5. **Rediseña el regex de identidad** para aceptar solo firmas producidas en tags SemVer (`v1.2.3`) del workflow `release.yml` del repo `acme/billing`. Escribe el regex exacto.
6. **¿Qué nivel SLSA alcanza tu workflow?** ¿Qué tendrías que cambiar para subir un nivel?

## 10. Extensiones

- **E1** — Añade un step de `grype` que lea el SBOM y falle el build si hay vulns `critical`.
- **E2** — Firma también el SBOM como blob (`cosign sign-blob --key ... sbom.cdx.json`) además de la attestation.
- **E3** — Convierte el workflow a reusable (`workflow_call`) con inputs `image_name` y `tag`.
- **E4** — Añade `environment: release` + required reviewers para gatear la firma (double-signing).

## 11. Limpieza

```bash
# Para el registry local
docker rm -f gha-14-01-registry 2>/dev/null || true
rm -rf /tmp/gha-14-01
```

En live, elimina paquetes de prueba desde `Settings → Packages` si no los quieres persistir.
