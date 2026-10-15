# Ejemplo 01 — Firmar commits con una clave SSH

## Concepto que demuestra

Configuración mínima para firmar commits (y tags) con **SSH** de forma local y verificable sin tocar GitHub. Es el patrón recomendado por GitHub desde 2022 por ser mucho más simple que GPG.

## Contexto

Un commit firmado se diferencia de uno "normal" en que incluye un campo `gpgsig` dentro del objeto commit. El contenido cubre todo lo demás (tree, parent, author, committer, mensaje). Alterar cualquier byte invalida la firma. Ver `theory/lesson.md` sección 2.2.

## Objetivo

- Generar una clave SSH **exclusiva para firmar** (no reusar la de auth).
- Configurar git para firmar automáticamente commits y tags.
- Preparar un `allowed_signers` para que `git verify-commit` pueda validar.
- Ver el badge "Good signature" en `git log --show-signature`.

## Prerrequisitos

- Git ≥ 2.34 (SSH signing requiere esta versión mínima).
- OpenSSH ≥ 8.0 (para `ssh-keygen -Y`).

## Ejecución

```bash
# 0) Limpieza previa por si re-ejecutas
rm -rf /tmp/sign-demo
mkdir -p /tmp/sign-demo/keys /tmp/sign-demo/repo /tmp/sign-demo/config

# 1) Generar la clave de firma (sin passphrase para la demo)
ssh-keygen -t ed25519 -C "git-signing-demo" \
  -f /tmp/sign-demo/keys/signing_ed25519 -N ""

# 2) Preparar allowed_signers (mapea identidad -> clave pública aceptada)
EMAIL="demo@example.com"
printf '%s %s\n' "$EMAIL" "$(cat /tmp/sign-demo/keys/signing_ed25519.pub)" \
  > /tmp/sign-demo/config/allowed_signers

# 3) Inicializar repo con la configuración de firma LOCAL (no global, para no ensuciar tu máquina)
cd /tmp/sign-demo/repo
git init -q -b main
git config user.name  "Demo"
git config user.email "$EMAIL"
git config gpg.format ssh
git config user.signingkey /tmp/sign-demo/keys/signing_ed25519.pub
git config commit.gpgsign true
git config tag.gpgsign true
git config gpg.ssh.allowedSignersFile /tmp/sign-demo/config/allowed_signers

# 4) Hacer un commit firmado
echo hello > README.md
git add README.md
git commit -q -m "chore: signed init"

# 5) Verificar
git log --show-signature -1
# Esperado:
#   commit <hash> (HEAD -> main)
#   Good "demo@example.com" signature with ED25519 key SHA256:...
#   Author: Demo <demo@example.com>
#   ...

# 6) (Opcional) Firmar un tag y verificar
git tag -s v0.1.0 -m "signed tag v0.1.0"
git tag -v v0.1.0
# Esperado: "Good 'demo@example.com' signature ..."
```

## Resultado esperado

- `git log --show-signature -1` imprime una línea `Good "..." signature with ED25519 key ...`.
- `git tag -v v0.1.0` también verifica correctamente.
- El commit NO está "verified" en GitHub mientras no subas la pública como *Signing Key* en tu perfil, pero localmente es completamente verificable.

## Verificación cruda (sin git)

Puedes verificar que la firma está en el objeto commit directamente:

```bash
git cat-file commit HEAD | head -20
# Verás una línea 'gpgsig -----BEGIN SSH SIGNATURE-----' seguida del blob.
```

## Interpretación

- La configuración vive en `.git/config` del repo (porque usamos `git config` sin `--global`). Para producción personal, pásalo a `--global` para que aplique en todos tus repos.
- El `allowed_signers` es lo que convierte una firma criptográficamente válida en una firma **atribuible a una identidad**. Sin él, Git puede verificar matemáticamente pero no decir "esto es de demo@example.com".
- GitHub usa su propio `allowed_signers` implícito con las Signing Keys registradas en los perfiles.

## Errores frecuentes

- `error: gpg failed to sign the data`: típicamente `gpg.format` quedó en `openpgp` (default). Asegura `gpg.format ssh`.
- `No principal matched`: la línea del `allowed_signers` no coincide con el `user.email` del repo.
- `missing key`: `user.signingkey` apunta a una ruta inexistente o apunta a la privada en vez de la pública.

## Para producción (globalmente)

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

Y sube la pública a **GitHub → Settings → SSH and GPG keys → New SSH key → tipo: Signing Key**.

## Limpieza

```bash
rm -rf /tmp/sign-demo
```
