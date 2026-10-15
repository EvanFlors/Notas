# Ejemplo 03 — cosign: firma y verificación (keyless + key pair local)

## Concepto que demuestra

Firmar una imagen OCI y verificar la firma en **ambos modos** que cubre el módulo:

- **`MODE=local` (default)**: key pair local (`cosign generate-key-pair`), registry local (`registry:2` en `localhost:5000`), sin Rekor (`--tlog-upload=false` + `--insecure-ignore-tlog`).
- **`MODE=live`**: keyless OIDC vía Sigstore (requiere internet y un IdP — típicamente desde un workflow GHA; corriendo local, cosign abre browser).

## Contexto

cosign *firma el digest* de la imagen (nunca el tag) y publica la firma al registry como un artefacto OCI relacionado — vía la convención legacy de tags (`sha256-<digest>.sig`) o vía la OCI 1.1 referrers API moderna. El verificador descarga esos artefactos relacionados y comprueba la firma.

Ver `theory/lesson.md` §2.3 (modalidades), §4.3 (flujo keyless), §4.4 (dónde se guarda la firma).

## Archivos

- `Dockerfile.sample` — imagen demo mínima.
- `run.sh` — orquesta build + push + sign + verify. Lee `MODE` del env (`local` o `live`).

## Ejecución

### MODE=local (recomendado para seguir el ejemplo)

```bash
bash run.sh                 # MODE=local por default, workdir /tmp/dkr-14-ex03
# o
MODE=local bash run.sh /tmp/mi-ex03
```

Hace:

1. Levanta `registry:2` en `localhost:5000` (si no está).
2. Build + push de `localhost:5000/cosign-demo:v1`.
3. Resuelve el **digest** del manifest publicado.
4. Genera key pair en `$BASE/keys/` (contraseña vacía).
5. `cosign sign --key keys/cosign.key --tlog-upload=false --yes <IMG@DIGEST>`.
6. `cosign verify --key keys/cosign.pub --insecure-ignore-tlog <IMG@DIGEST>` → OK esperado.
7. **Prueba negativa**: verify con una clave distinta → debe FALLAR.

### MODE=live (requiere OIDC — típicamente desde GHA, no local)

```bash
MODE=live REGISTRY=ghcr.io/youruser bash run.sh
```

Firma keyless con el OIDC del runner (si corres local, cosign abrirá un browser para OAuth2 contra `oauth2.sigstore.dev`). Verifica con `--certificate-identity-regexp` y `--certificate-oidc-issuer`.

## Qué mirar

Después del `cosign sign` en modo local, inspecciona el registry:

```bash
curl -s http://localhost:5000/v2/cosign-demo/tags/list | jq
# verás:
# {
#   "name": "cosign-demo",
#   "tags": [
#     "v1",
#     "sha256-abcd...sig"      ← firma, como tag derivado del digest
#   ]
# }
```

Y descarga manualmente el blob de la firma si quieres curiosear:

```bash
# El tag .sig apunta a un manifest cuyo config/blob es la firma DSSE.
curl -s http://localhost:5000/v2/cosign-demo/manifests/sha256-abcd...sig \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" | jq
```

## Prueba negativa (ya automática en `run.sh`)

Verificar con una clave que no firmó debe fallar:

```bash
# Genera una segunda clave sin usar
mkdir -p /tmp/other && cd /tmp/other
export COSIGN_PASSWORD=''
cosign generate-key-pair
# Verifica la imagen firmada con esta clave: FAIL
cosign verify --key /tmp/other/cosign.pub --insecure-ignore-tlog <IMG@DIGEST>
# → Error: no matching signatures found
```

## Limpieza

```bash
docker stop dkr-14-ex03-reg 2>/dev/null || true
docker image rm localhost:5000/cosign-demo:v1 2>/dev/null || true
rm -rf /tmp/dkr-14-ex03
```

## Referencias

- `theory/lesson.md` §2.3, §4.3, §4.4.
- `resources/links.md` → cosign.
