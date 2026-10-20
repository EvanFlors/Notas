# Ejemplo 02 — Verificación de firmas con Kyverno + cosign

Demuestra el patrón "imagen firmada obligatoria" en admission. Pipeline:

1. **Instalar Kyverno** en el cluster.
2. **Generar key pair** cosign y **firmar** una imagen de prueba empujada a un registry local.
3. **ClusterPolicy** `verify-images-cosign` con la clave pública.
4. Un Pod con la imagen **firmada** se admite. Un Pod con una imagen **no firmada** es rechazado.

Modo: **offline-key** (sin OIDC, sin Rekor). Para el modo keyless, ver lección §7.5 y `dkr-14`.

## Requisitos

- `kind`, `kubectl`, `helm`, `docker`, `cosign` (`brew install cosign` o binario oficial).
- Red para pull de imágenes base y del chart de Kyverno.

## Qué contiene

- `kyverno-install.sh` — script idempotente para instalar Kyverno vía Helm.
- `sign-and-push.sh` — levanta un `registry:2` local en el nodo kind, firma una imagen con cosign y la empuja.
- `cluster-policy.yaml.tpl` — plantilla de la `ClusterPolicy`; se completa con la clave pública real.
- `pod-signed.yaml` — Pod que referencia la imagen firmada (**debe admitirse**).
- `pod-unsigned.yaml` — Pod que referencia una imagen sin firma (**debe ser rechazado**).

## Ejecución

```bash
export WORK=/tmp/k8s-16-ex02
mkdir -p "$WORK" && cd "$WORK"

# Clona los artefactos
SRC="courses/kubernetes/16-security-hardening-and-supply-chain/examples/02-cosign-verify-admission"
cp "$SRC"/*.sh "$SRC"/*.yaml "$SRC"/*.yaml.tpl "$WORK/"
chmod +x *.sh

# 1) Cluster kind con registry local accesible desde los nodos.
#    Si ya tienes un cluster, puedes reutilizarlo; el registry debe
#    resolverse desde los nodos como 'localhost:5000' o similar.
kind create cluster --name k8s-16-ex02 || true

# 2) Instala Kyverno
./kyverno-install.sh

# 3) Firma una imagen y empujala al registry local
./sign-and-push.sh
# Genera: cosign.key, cosign.pub, y empuja web@sha256:... firmada

# 4) Carga la ClusterPolicy con la clave publica embebida
# La clave publica debe quedar correctamente indentada bajo el block scalar YAML:
python3 - <<'PY' > cluster-policy.yaml
pub = open('cosign.pub').read().rstrip()
tpl = open('cluster-policy.yaml.tpl').read()
indent = ' ' * 22
indented = '\n'.join(indent + line for line in pub.split('\n'))
print(tpl.replace('__COSIGN_PUBKEY__', indented))
PY
kubectl apply -f cluster-policy.yaml

# 5) Pod con imagen firmada: se admite
kubectl create ns app --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f pod-signed.yaml
kubectl -n app get pod signed -w  # Ctrl+C cuando pase a Running

# 6) Pod sin firma: Kyverno rechaza
kubectl apply -f pod-unsigned.yaml
# Esperado:
#   Error from server: ...
#     admission webhook "mutate.kyverno.svc" denied the request:
#     ... /unsigned-image failed: no signatures found
```

## Qué aprendiste

- Kyverno `verifyImages` corre como **mutating + validating** webhook: valida la firma y, con `mutateDigest: true`, reescribe el `tag` a `@sha256:<digest>` para que el runtime consuma exactamente el bit firmado.
- En modo offline-key (lab), `rekor.ignoreTlog: true` es obligatorio: sin eso Kyverno busca Rekor y falla.
- Para modo keyless (producción), se cambia `keys` por `keyless` con `subject`/`issuer` y Rekor público.

## Limpieza

```bash
kubectl delete -f pod-signed.yaml --ignore-not-found
kubectl delete -f pod-unsigned.yaml --ignore-not-found
kubectl delete -f cluster-policy.yaml --ignore-not-found
helm uninstall kyverno -n kyverno || true
kubectl delete ns kyverno --ignore-not-found
rm -rf "$WORK"
# kind delete cluster --name k8s-16-ex02   # si lo creaste solo para esto
```
