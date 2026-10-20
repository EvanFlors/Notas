# Actividad 01 — Publica tu chart firmado

## 1. Identificación

- **ID:** `helm-08-01-publish-your-chart-signed`
- **Tecnología:** `helm`
- **Módulo:** `08-repositories-oci-and-provenance`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a publicar un chart propio a un registry OCI y lo vas a **firmar con cosign**, en los dos modos que ya conoces por los ejemplos:

- `MODE=local` — practica el flujo completo contra un `registry:2` local. Reproducible, sin tocar nada remoto.
- `MODE=live` — publica a GHCR real y firma. Requiere PAT y, para firma keyless, que corra desde un workflow GHA con `id-token: write`.

El objetivo es que acabes con un chart publicado, firmado y una verificación OK + una negativa que FAIL. Más adelante (actividad 02) otro ambiente lo consumirá sin confiar en ti.

## 3. Objetivos

Al terminar deberías poder:

- Empaquetar un chart propio con una versión SemVer válida.
- Hacer `helm push` al registry OCI (local o GHCR).
- Firmar con `cosign sign` **por digest** (no por tag).
- Verificar la firma con la clave pública correcta (OK).
- Verificar con una clave pública distinta (FAIL — prueba negativa).
- Explicar por qué firmar por tag en vez de digest sería frágil.

## 4. Prerrequisitos

- `helm` ≥ 3.11 (`helm version`).
- `docker` corriendo (para `MODE=local`).
- `cosign` ≥ 2.0 instalado (`cosign version`).
- Opcional (`MODE=live`): cuenta en GitHub, PAT con scope `write:packages`, y haber ejecutado `helm registry login ghcr.io`.
- Costos: ninguno (local) o $0 (GHCR free tier con public packages).

## 5. Instrucciones

### 5.1 Preparar el workspace

```bash
rm -rf /tmp/helm-08-act01
mkdir -p /tmp/helm-08-act01 && cd /tmp/helm-08-act01
```

### 5.2 Crear tu chart

Toma `helm create` como punto de partida y renómbralo a algo tuyo (p. ej. `<tu-usuario>-app`):

```bash
helm create mi-app
# Edita Chart.yaml:
#   version: 0.1.0     (SemVer; respétalo religiosamente)
#   appVersion: "1.0"  (versión de la app empaquetada)
```

Haz un cambio mínimo para que *sea tuyo* (p. ej. editar `values.yaml` → `replicaCount: 2`).

### 5.3 Modo local — registry + push

```bash
# Levanta registry local
docker run -d --rm --name helm-08-act01-reg -p 5000:5000 registry:2
sleep 2

helm package mi-app                           # → mi-app-0.1.0.tgz
helm push mi-app-0.1.0.tgz oci://localhost:5000/charts --plain-http
```

Confirma el push leyendo el listado de tags:

```bash
curl -s http://localhost:5000/v2/charts/mi-app/tags/list
```

### 5.4 Firma con cosign (local, sin Rekor)

```bash
mkdir keys && cd keys
export COSIGN_PASSWORD=''
cosign generate-key-pair
cd ..

# Resuelve el DIGEST del chart publicado
DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  http://localhost:5000/v2/charts/mi-app/manifests/0.1.0 \
  | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
echo "DIGEST=$DIGEST"

IMG="localhost:5000/charts/mi-app@${DIGEST}"

cosign sign --key keys/cosign.key \
  --tlog-upload=false --allow-insecure-registry --yes "$IMG"
```

### 5.5 Verificar

**Positiva** (clave correcta → OK):

```bash
cosign verify --key keys/cosign.pub \
  --insecure-ignore-tlog --allow-insecure-registry "$IMG"
```

**Negativa** (clave distinta → FAIL esperado):

```bash
mkdir -p other-keys && (cd other-keys && cosign generate-key-pair)
cosign verify --key other-keys/cosign.pub \
  --insecure-ignore-tlog --allow-insecure-registry "$IMG" \
  && echo "WRONG: should have failed" \
  || echo "OK: wrong key correctly rejected"
```

### 5.6 Validar automáticamente

```bash
bash <ruta-al-repo>/courses/helm/08-repositories-oci-and-provenance/activities/01-publish-your-chart-signed/tests/validate.sh
# o pasando workdir custom:
BASE=/tmp/helm-08-act01 bash tests/validate.sh
```

### 5.7 (Opcional) Modo live — GHCR + keyless

Si tienes un repo GitHub tuyo:

```bash
echo "$GHCR_TOKEN" | helm registry login ghcr.io -u "$GHCR_USER" --password-stdin
helm push mi-app-0.1.0.tgz oci://ghcr.io/<yourorg>/charts

# Resuelve digest con helm show (requiere helm 3.14+)
DIGEST=$(helm show chart oci://ghcr.io/<yourorg>/charts/mi-app --version 0.1.0 \
         | awk '/^digest:/ {print $2}')
cosign sign --yes "ghcr.io/<yourorg>/charts/mi-app@${DIGEST}"
# cosign abrirá un browser → OAuth2 con Sigstore → firma keyless.
```

Mejor aún: haz este paso desde un workflow GHA con `id-token: write` para firma keyless *automática* sin browser.

## 6. Resultado esperado

- Un chart `mi-app` versión `0.1.0` publicado en:
  - `oci://localhost:5000/charts/mi-app:0.1.0` (local), **o**
  - `oci://ghcr.io/<yourorg>/charts/mi-app:0.1.0` (live).
- Una firma cosign asociada al digest del chart.
- `cosign verify` con la clave/identidad correcta → OK.
- `cosign verify` con una clave distinta → FAIL.

## 7. Criterios de aceptación

- `tests/validate.sh` sale con código 0.
- La firma se hizo **por digest** (no por tag) — verifícalo volviendo a correr `cosign verify` con la misma referencia tras un hipotético re-push (debería seguir siendo válida solo porque el digest es idéntico).
- El chart tiene `version:` que respeta SemVer.
- Nunca se re-publicó la misma versión; si tuviste que corregir algo, hiciste bump a `0.1.1`.

## 8. Validación

```bash
bash tests/validate.sh
```

El script comprueba:

- `docker ps` muestra el `registry:2` del lab.
- El tag `0.1.0` existe para `charts/mi-app` en la API del registry.
- Hay un artefacto firma asociado (tag `sha256-....sig`).
- `cosign verify` con `keys/cosign.pub` pasa.
- `cosign verify` con una pública fresca falla.

## 9. Preguntas de reflexión

1. ¿Por qué `cosign sign` espera un digest y no acepta solo un tag? ¿Qué garantía te da esto?
2. ¿Qué cambia si en `MODE=live` haces `cosign sign` sin `--tlog-upload=false`? ¿Dónde queda ese registro?
3. ¿Qué pasa si borras `keys/cosign.key` después de firmar? ¿Y si borras `keys/cosign.pub`?
4. Imagina que mañana filtran tu `cosign.key`. ¿Cómo invalidas las firmas hechas con esa clave? Compara con el flujo keyless.
5. ¿Por qué `helm push` no acepta `--tag`? ¿Cómo re-publicarías "la misma versión" si *tuvieras* que hacerlo?

## 10. Extensiones

- Firma también una **attestation** con `cosign attest` (p. ej. un SBOM del chart generado con `syft` sobre el `.tgz`).
- Reproduce todo desde un workflow GHA. Pide a `permissions:` el `id-token: write`, usa `sigstore/cosign-installer`, y firma keyless. Tu `verify` cambiará a `--certificate-identity-regexp` / `--certificate-oidc-issuer`.
- Añade un `artifacthub-repo.yml` al namespace OCI (`charts/`) y registra tu repo en Artifact Hub. Confirma que detecta la firma automáticamente.

## 11. Limpieza

```bash
docker rm -f helm-08-act01-reg 2>/dev/null || true
rm -rf /tmp/helm-08-act01
```

Para `MODE=live`: borra el package desde la UI de GHCR si fue solo una prueba.
