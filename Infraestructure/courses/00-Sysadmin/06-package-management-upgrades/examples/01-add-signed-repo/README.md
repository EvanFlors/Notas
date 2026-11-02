# Ejemplo 01 — Añadir un repo APT firmado con `/etc/apt/keyrings/`

## Concepto que demuestra

El patrón **moderno** de alta de repositorio en Debian/Ubuntu: clave aislada en `/etc/apt/keyrings/` + `signed-by=` en el archivo `.sources`. Nunca `apt-key`, nunca `/etc/apt/trusted.gpg.d/`.

## Contexto

Vamos a añadir el repositorio oficial de **HashiCorp** (publican Terraform, Vault, etc.) a un Debian/Ubuntu. Es un buen ejemplo real porque:

- Publican su clave GPG en una URL HTTPS estable.
- Publican el *fingerprint* esperado en su documentación de seguridad.
- Mantienen un repo APT propio bien estructurado.

> No ejecutaremos aquí la instalación de ningún paquete; nos quedamos en "repo listo y `apt update` sin warnings".

## Objetivo

Al terminar, podrás responder:

- ¿Dónde vive la clave y por qué ahí?
- ¿Qué hace exactamente `signed-by=`?
- ¿Cómo verifico el *fingerprint* antes de confiar?

## Prerrequisitos

- **VM o contenedor Debian 12 / Ubuntu 22.04+** con `sudo`. **No lo hagas en tu máquina principal.**
- Comandos disponibles: `curl`, `gpg`, `apt`, `tee`, `install`.
- Red con acceso saliente a `apt.releases.hashicorp.com`.

## Ejecución

Copia-pega bloque a bloque y **lee la salida antes de continuar**.

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Preparar el directorio canónico de llaves (modo 0755, root)
sudo install -d -m 0755 /etc/apt/keyrings

# 2. Descargar la clave pública (ASCII armored) a un temporal
TMP_KEY=$(mktemp --suffix=.asc)
curl -fsSL https://apt.releases.hashicorp.com/gpg -o "${TMP_KEY}"

# 3. Mostrar el fingerprint para verificación manual
echo "=== Fingerprint de la clave descargada ==="
gpg --show-keys --with-fingerprint "${TMP_KEY}"
```

En este punto **DETENTE**. La salida del `gpg --show-keys` incluirá un bloque como:

```
pub   rsa4096 2023-01-10 [SC] [expires: 2028-01-09]
      798A EC65 4E5C 1542 8C8E  42EE AA16 FCBC A621 E701
uid                      HashiCorp Security (HashiCorp Package Signing) <security+packaging@hashicorp.com>
```

Compara ese fingerprint (`798A EC65 ... A621 E701`) **manualmente** contra lo que HashiCorp publica en su página oficial:
<https://www.hashicorp.com/trust/security>

> Si no coinciden: **para**. No continúes. La clave puede estar comprometida, el DNS envenenado, o el mirror corrupto. Reporta en los canales oficiales del proyecto.

Cuando esté verificada, continúa:

```bash
# 4. Dearmor (binario) y mover a /etc/apt/keyrings/ con permisos canónicos
sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg "${TMP_KEY}"
sudo chmod 0644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg
rm -f "${TMP_KEY}"

# 5. Detectar codename (bookworm, jammy, noble, etc.)
. /etc/os-release
CODENAME="${VERSION_CODENAME:-}"
echo "Codename detectado: ${CODENAME}"

# 6. Crear la fuente en formato DEB822 moderno
sudo tee /etc/apt/sources.list.d/hashicorp.sources >/dev/null <<EOF
Types: deb
URIs: https://apt.releases.hashicorp.com
Suites: ${CODENAME}
Components: main
Signed-By: /etc/apt/keyrings/hashicorp-archive-keyring.gpg
EOF

# 7. Refrescar índices y confirmar
sudo apt update

# 8. Comprobación: el nuevo repo aparece y no hay NO_PUBKEY ni warnings
grep -R "hashicorp" /var/lib/apt/lists/ | head -3 || true
```

## Qué deberías observar

- `apt update` termina sin errores `NO_PUBKEY`, sin warnings de "repository is not signed" y mencionando una línea `Get:... apt.releases.hashicorp.com`.
- `ls -l /etc/apt/keyrings/hashicorp-archive-keyring.gpg` muestra `-rw-r--r--`, propietario `root`.
- `cat /etc/apt/sources.list.d/hashicorp.sources` muestra la referencia `Signed-By:` exacta.

## Discusión

- **¿Qué pasaría sin `Signed-By:`?** apt caería al *keyring global* (`/etc/apt/trusted.gpg` + `trusted.gpg.d/`), que valida *cualquier* repo. Si mañana se compromete la clave de HashiCorp, un atacante podría firmar paquetes que suplanten a `coreutils`, `openssh-server`, etc.
- **¿Por qué DEB822 (.sources) en vez del .list clásico?** Es extensible, legible y oficialmente recomendado desde Debian 12. El `.list` sigue funcionando por compatibilidad.
- **¿Por qué `--dearmor`?** apt espera la clave en formato binario (OpenPGP packet format), no ASCII-armored. El `.asc` que descargaste es ASCII; `gpg --dearmor` lo convierte.

## Limpieza

Si quieres dejar la VM como estaba:

```bash
sudo rm -f /etc/apt/sources.list.d/hashicorp.sources
sudo rm -f /etc/apt/keyrings/hashicorp-archive-keyring.gpg
sudo apt update
```

## Enlaces

- Debian wiki — SecureApt: <https://wiki.debian.org/SecureApt>
- Debian wiki — DebianRepository/UseThirdParty: <https://wiki.debian.org/DebianRepository/UseThirdParty>
- HashiCorp security / signing: <https://www.hashicorp.com/trust/security>
