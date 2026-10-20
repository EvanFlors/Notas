# dkr-14-01 — Pipeline completo build → SBOM → scan → sign → attest → verify

## 1. Identificación

- **ID:** `dkr-14-01-build-sign-and-verify-pipeline`
- **Tecnología:** docker
- **Módulo:** `14-supply-chain-sbom-signing-provenance`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** mini-project

## 2. Contexto

Vas a implementar el **flujo completo de supply chain** para una imagen OCI de una app trivial:

```
build → push → syft (SBOM) → trivy (scan + gate) → cosign sign →
  cosign attest(slsa provenance) → cosign attest(cyclonedx) → verify
```

El entregable principal no es solo que el pipeline corra: es un **`verify.sh`** que **un consumidor en otra máquina** pueda ejecutar sobre tu imagen publicada y que falle de manera informativa si cualquier evidencia no cuadra.

La actividad es **dual-mode**:

- `MODE=local` (default): `registry:2` en `localhost:5000`, `cosign` con key pair local, `--tlog-upload=false`.
- `MODE=live`: GHCR + keyless OIDC desde GHA (opcional, requiere un repo propio).

## 3. Objetivos

Ver `activity.yaml` — se evalúan en §7 Criterios de aceptación.

## 4. Prerrequisitos

### Conocimientos
- Haber completado todos los `examples/` del módulo.
- `dkr-09` (digests), `dkr-13` (hardening), lectura de `gha-14` recomendada.

### Software
- `docker` (daemon corriendo)
- `python3`, `jq`
- Para la cadena completa: `syft`, `trivy`, `cosign` (si falta alguna, el validator salta la parte runtime y verifica la parte estructural).

### Infraestructura
- Puertos libres: `5000` (registry local).
- Internet solo para pull de imágenes base (y para `MODE=live`).

### Costos
- `MODE=local`: cero.
- `MODE=live`: GHCR es gratis para repos públicos personales; registra GHA minutes.

## 5. Instrucciones

### 5.1 Setup

```bash
bash starter/bootstrap.sh                # crea /tmp/dkr-14-01 con scaffolding
cd /tmp/dkr-14-01
cat NOTES.md
```

El scaffolding deja:

```
/tmp/dkr-14-01/
├── Dockerfile                        # app Python mínima (healthy, non-root)
├── app.py                            # "hello" FastAPI-like (sin framework pesado)
├── NOTES.md                          # guía rápida
├── keys/                             # vacío; aquí irá cosign.key/pub
├── sbom/                             # vacío; aquí irá sbom.cdx.json
├── provenance.json                   # predicate SLSA plantilla (reemplazar timestamps)
├── pipeline.sh                       # STUB — tú lo completas
├── verify.sh                         # STUB — tú lo completas
└── .github/workflows/release.yml     # STUB — para MODE=live
```

### 5.2 Qué tienes que escribir

#### A) `pipeline.sh` (MODE=local)

Debe hacer, en orden:

1. Levantar `registry:2` en `localhost:5000` (si no está).
2. Build + push de la imagen a `localhost:5000/app:v1`.
3. Capturar el **digest** publicado y exportar `IMG="localhost:5000/app@${DIGEST}"`.
4. Generar SBOM CycloneDX en `sbom/sbom.cdx.json` con `syft` (si está instalado).
5. **Correr `trivy image --severity CRITICAL --exit-code 1 "$IMG"`** y abortar si falla.
6. Generar key pair en `keys/` (si no existe).
7. `cosign sign` con la clave local, `--tlog-upload=false --yes`.
8. Rellenar timestamps de `provenance.json`.
9. `cosign attest --type slsaprovenance --predicate provenance.json`.
10. `cosign attest --type cyclonedx --predicate sbom/sbom.cdx.json`.

Degrada: si falta `syft` o `cosign`, imprime SKIP y continúa; si falta `trivy`, imprime SKIP (y el gate no gatea en esa corrida).

#### B) `verify.sh` (lo que un consumidor correrá)

Debe recibir el **IMG** y la **clave pública** como argumentos:

```bash
./verify.sh "localhost:5000/app@sha256:..." /tmp/dkr-14-01/keys/cosign.pub
```

Debe verificar:

1. Que la imagen existe en el registry (manifest head).
2. `cosign verify --key cosign.pub --insecure-ignore-tlog <IMG>`.
3. `cosign verify-attestation --key cosign.pub --insecure-ignore-tlog --type slsaprovenance <IMG>`.
4. `cosign verify-attestation --key cosign.pub --insecure-ignore-tlog --type cyclonedx <IMG>`.
5. Imprimir OK/FAIL por paso y salir con 0 solo si todos pasan.

#### C) `.github/workflows/release.yml` (MODE=live, opcional)

Debe incluir, mínimamente:

- `permissions: {}` a nivel top (default-deny).
- Job `publish` con `permissions: { contents: read, packages: write, id-token: write, attestations: write }`.
- `docker/login-action` a `ghcr.io`.
- `docker/build-push-action` con `push: true`.
- `syft` o `anchore/sbom-action` generando SBOM.
- `cosign sign` keyless.
- `actions/attest-build-provenance` con `push-to-registry: true`.
- `actions/attest-sbom` con `sbom-path`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/dkr-14-01
```

El validator:

- Verifica estructura y archivos esperados.
- Si el workflow existe, lo parsea con `python3 -c yaml.safe_load`.
- Verifica permisos declarados en el workflow (id-token, attestations, packages).
- Si herramientas runtime (docker, syft, cosign, trivy) están instaladas, intenta ejercitar la cadena (verify sobre la imagen pusheada).

## 6. Resultado esperado

Al terminar:

- `pipeline.sh` corre end-to-end sin fallar (o con SKIP claros si alguna herramienta falta).
- `verify.sh` ejecutado desde `/tmp/limpio` con argumentos `IMG` + `cosign.pub` pasa todos los pasos.
- Si corres con la clave *equivocada*, `verify.sh` falla con mensaje legible.
- `tests/validate.sh /tmp/dkr-14-01` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- **Funcional**: la imagen publicada tiene firma + 2 attestations verificables.
- **Seguridad**: `trivy` corre antes de firmar; si falla, no se firma.
- **Reproducibilidad**: `verify.sh` solo depende de `IMG` + `cosign.pub` (nada del pipeline).
- **Permisos (MODE=live)**: workflow con `permissions: {}` default-deny y escalado por job al mínimo.
- **Documentación**: `NOTES.md` actualizado si tomaste decisiones específicas (p.ej. `--ignore-unfixed` para trivy).

## 8. Validación

```bash
# estructural + runtime (si tools instaladas)
bash tests/validate.sh /tmp/dkr-14-01

# consumer check (lo que haría un tercero)
cd /tmp/limpio && cp /tmp/dkr-14-01/verify.sh . && cp /tmp/dkr-14-01/keys/cosign.pub .
./verify.sh "localhost:5000/app@sha256:...<digest>..." cosign.pub
```

## 9. Preguntas de reflexión

1. Si firmas **antes** de scanear, ¿qué garantía pierdes?
2. ¿Por qué `cosign sign` sobre el tag (`:v1`) es peligroso aunque el bytes-level sea idéntico al digest?
3. Un atacante compromete el runner tras el `cosign sign` keyless pero antes del final del job. ¿Qué puede hacer con la clave efímera?
4. En `verify-attestation --type cyclonedx` sale OK pero el SBOM listado **no contiene** uno de los paquetes que ves con `docker run app sh -c 'apk info'`. ¿Qué explicaciones son posibles?
5. ¿Qué cambia en `verify.sh` cuando el modo de firma es keyless y no key pair?

## 10. Extensiones

- Añade `grype sbom:sbom/sbom.cdx.json` después del attest y compara hallazgos vs trivy.
- Añade attestation **VEX** (`cyclonedx-vex`) marcando una CVE como *not_affected*.
- Pin de todas las actions del workflow a commit SHA (ver `gha-13`).
- Añade un job `verify` en el mismo workflow que corra después de `publish` y falle si algo no cuadra.

## 11. Limpieza

```bash
docker stop dkr-14-01-registry 2>/dev/null || true
rm -rf /tmp/dkr-14-01 /tmp/limpio
```
