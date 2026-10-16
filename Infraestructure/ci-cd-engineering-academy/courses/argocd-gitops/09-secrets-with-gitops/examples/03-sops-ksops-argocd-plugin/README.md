# Ejemplo 03 — SOPS + KSOPS integrado con Argo CD

> Objetivo: cifrar un `Secret` con **SOPS** usando una clave **age** local, verlo en Git como ciphertext, y preparar un **Config Management Plugin (CMP)** en el `repo-server` de Argo CD que lo descifre vía **KSOPS**.
>
> La parte local (crear clave age, cifrar, descifrar) es ejecutable y verificable sin desplegar nada en Argo CD. La integración CMP se muestra como manifiesto de referencia.

## Prerrequisitos

- `sops` 3.9+ (`brew install sops`).
- `age` (`brew install age`).
- Scratch: `/tmp/argo-09-sops`.

## 1. Generar una clave `age` y configurar SOPS

```bash
mkdir -p /tmp/argo-09-sops && cd /tmp/argo-09-sops

age-keygen -o key.txt
export SOPS_AGE_KEY_FILE="$PWD/key.txt"
export AGE_RECIPIENT=$(grep "public key:" key.txt | awk '{print $4}')
echo "recipient=$AGE_RECIPIENT"
```

Crea `.sops.yaml` (en producción iría al root del repo de infra):

```yaml
# .sops.yaml
creation_rules:
  - path_regex: ".*secret.*\\.yaml$"
    encrypted_regex: "^(data|stringData)$"
    age: "REPLACE_WITH_RECIPIENT"
```

```bash
sed -i.bak "s|REPLACE_WITH_RECIPIENT|$AGE_RECIPIENT|" .sops.yaml && rm .sops.yaml.bak
```

## 2. Cifrar un Secret

```bash
cat > db-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db
  namespace: demo
type: Opaque
stringData:
  password: s3cr3t
EOF

sops --encrypt --in-place db-secret.yaml
grep -c "ENC\[AES256_GCM" db-secret.yaml   # -> >=1
```

Fíjate que `metadata.name` y `metadata.namespace` quedan **en claro** (gracias a `encrypted_regex`): el diff en Git sigue siendo útil.

## 3. Descifrar (como lo haría KSOPS en el `repo-server`)

```bash
sops --decrypt db-secret.yaml
# apiVersion: v1
# kind: Secret
# stringData:
#   password: s3cr3t
```

## 4. Integración con Argo CD (manifiesto de referencia)

Argo CD renderiza manifiestos en el `repo-server`. Para KSOPS se instala como **CMP sidecar** o se construye una imagen custom del `repo-server` con `kustomize` + `ksops` + `sops`. Manifiesto del CMP:

```yaml
# argocd-cm-plugin.yaml  (referencia; se monta en el namespace argocd)
apiVersion: v1
kind: ConfigMap
metadata:
  name: ksops-plugin
  namespace: argocd
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: ksops
    spec:
      version: v1.0
      generate:
        command: ["sh", "-c"]
        args: ["kustomize build --enable-alpha-plugins --enable-exec ."]
```

El `repo-server` necesita el **age key** como variable de entorno `SOPS_AGE_KEY` o montado desde un `Secret`:

```yaml
env:
  - name: SOPS_AGE_KEY
    valueFrom:
      secretKeyRef:
        name: sops-age
        key: key.txt
```

**Blast radius**: comprometer el `repo-server` ⇒ fugar todos los secretos cifrados con esa clave age. Mínimo privilegio: una clave age por entorno; rotación anual.

## 5. Rotar un valor

```bash
sops set db-secret.yaml '["stringData"]["password"]' '"s3cr3t-v2"'
sops --decrypt db-secret.yaml | grep password
# password: s3cr3t-v2
```

## 6. Rotar la clave maestra

Si cambia el recipient en `.sops.yaml`, re-cifrar todos los archivos:

```bash
# producción: iterar sobre todos los secret files
sops updatekeys db-secret.yaml
```

## Limpieza

```bash
rm -rf /tmp/argo-09-sops
```
