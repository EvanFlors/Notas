# Ejemplo 01 — Generar y cargar una SSH key `ed25519` para GitHub

## Concepto que demuestra

Cómo crear un par de llaves `ed25519`, cargarlas en el `ssh-agent`, subir la **pública** a GitHub, y verificar la conexión. **La privada nunca sale de tu máquina.**

## Contexto

Primer paso práctico de autenticación cuando prefieres SSH sobre `gh auth` o HTTPS+PAT. Setup único por máquina.

## Objetivo

Al terminar:
- Entiendes qué archivo subir a GitHub (`.pub`) y cuál **nunca** compartir.
- Sabes probar la conexión sin tocar un repo (`ssh -T git@github.com`).
- Entiendes el fallback por puerto 443 (`ssh.github.com`) cuando el 22 está bloqueado.

## Prerrequisitos

- `ssh-keygen` (viene con OpenSSH; en macOS/Linux ya instalado; en Windows via Git Bash o OpenSSH).
- Cuenta en GitHub.
- Para la parte "subir": acceso a `https://github.com/settings/keys` o `gh` autenticado por otra vía.

**Costos**: ninguno.

## Ejecución

> **No vamos a sobreescribir una key existente.** Usamos un archivo distinto (`~/.ssh/id_ed25519_demo`).

### 1. Generar el par

```bash
ssh-keygen -t ed25519 \
  -C "demo-key for gh-05" \
  -f ~/.ssh/id_ed25519_demo \
  -N ""                         # sin passphrase para la demo; en real pon una
```

Verifica:

```bash
ls -l ~/.ssh/id_ed25519_demo*
# id_ed25519_demo       (privada, modo 600 — NUNCA subir a ningún sitio)
# id_ed25519_demo.pub   (pública, modo 644 — esta es la que subes)

cat ~/.ssh/id_ed25519_demo.pub
# ssh-ed25519 AAAAC3Nz... demo-key for gh-05
```

### 2. Cargar en `ssh-agent` (opcional pero recomendado)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_demo
ssh-add -l                     # lista llaves cargadas
```

En macOS, para que persista entre reinicios:

```bash
# ~/.ssh/config:
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519_demo
```

### 3. Subir la pública a GitHub

**Opción A — con `gh` (si ya estás auth por otra vía):**

```bash
gh ssh-key add ~/.ssh/id_ed25519_demo.pub --title "demo-key gh-05"
gh ssh-key list
```

**Opción B — con la web:**

1. Copia la pública al portapapeles:
   - macOS: `pbcopy < ~/.ssh/id_ed25519_demo.pub`
   - Linux: `xclip -sel clip < ~/.ssh/id_ed25519_demo.pub`
   - Windows: `cat ~/.ssh/id_ed25519_demo.pub | clip`
2. Entra a <https://github.com/settings/keys> → **New SSH key**.
3. Pega, pon un title, salvar.

### 4. Probar la conexión

```bash
ssh -T git@github.com
# Primera vez verás:
#   The authenticity of host 'github.com (...)' can't be established.
#   ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.
#   Are you sure you want to continue connecting (yes/no)?
#
# COMPARA el fingerprint con los oficiales:
#   https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# Si coincide, 'yes'.
#
# Luego:
#   Hi <tu-usuario>! You've successfully authenticated,
#   but GitHub does not provide shell access.
```

El mensaje "does not provide shell access" **es éxito**: GitHub nunca da shell, solo acepta operaciones git.

### 5. Fallback por 443 si el 22 está bloqueado

Si `ssh -T git@github.com` cuelga o da `Connection timed out`, prueba:

```bash
ssh -T -p 443 git@ssh.github.com
# Hi <tu-usuario>! ...
```

Si funciona, añádelo permanentemente a `~/.ssh/config`:

```ssh
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_ed25519_demo
```

A partir de ahí `git@github.com:...` funciona por 443 transparente.

## Verificación

```bash
# Script completo (modo dry-run: no sube nada a GitHub)
bash files/run-example.sh
```

El script genera el par en `/tmp/ssh-demo/`, imprime la pública (lo que subirías), y verifica permisos.

## Limpieza

```bash
# Si no quieres mantener la demo key:
ssh-add -d ~/.ssh/id_ed25519_demo
rm -f ~/.ssh/id_ed25519_demo ~/.ssh/id_ed25519_demo.pub
# Y revoca la pública en https://github.com/settings/keys si la subiste.
```

## Preguntas de reflexión

1. ¿Por qué `ed25519` sobre `rsa-2048`? Busca "ed25519 vs rsa ssh" si no sabes.
2. ¿Qué pasa si subes la privada por error (confundiste `.pub` con la privada)?
3. ¿Qué pasa si pierdes la privada y no la revocas en GitHub? ¿Y si la revocas pero la privada queda en una máquina comprometida?
4. ¿Por qué GitHub usa SHA256 para publicar los fingerprints y no SHA1 ni MD5?
