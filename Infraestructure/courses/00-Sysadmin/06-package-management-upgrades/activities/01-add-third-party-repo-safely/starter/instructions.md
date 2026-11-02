# Instrucciones — Añadir repo HashiCorp firmado

## Antes de empezar

- Confirma que estás en una **VM/contenedor desechable** Debian 12 o Ubuntu 22.04+:
  ```bash
  . /etc/os-release && echo "${PRETTY_NAME}"
  ```
- Confirma `sudo` funcional y acceso a internet:
  ```bash
  sudo -v
  curl -I https://apt.releases.hashicorp.com/gpg
  ```

## Pasos

### 1. Preparar el directorio de llaves

El directorio `/etc/apt/keyrings/` es el estándar moderno para claves por repo. Debe existir con modo `0755` y propiedad `root:root`.

```bash
sudo install -d -m 0755 /etc/apt/keyrings
ls -ld /etc/apt/keyrings
```

### 2. Descargar la clave pública a un temporal

**No** la guardes aún en su ubicación final; primero verifica el fingerprint.

```bash
TMP_KEY=$(mktemp --suffix=.asc)
curl -fsSL https://apt.releases.hashicorp.com/gpg -o "${TMP_KEY}"
ls -l "${TMP_KEY}"
```

### 3. **PASO CRÍTICO** — Verificar el fingerprint

Mira el fingerprint de la clave recién descargada:

```bash
gpg --show-keys --with-fingerprint "${TMP_KEY}"
```

Busca en la salida una línea tipo:

```
      798A EC65 4E5C 1542 8C8E  42EE AA16 FCBC A621 E701
```

Compara **con tus propios ojos** contra el fingerprint publicado por HashiCorp:

<https://www.hashicorp.com/trust/security>

> Si el fingerprint de la página oficial no coincide: **DETENTE AHORA**. Borra el `${TMP_KEY}`, no sigas. Reporta en los canales oficiales.

Anota en tus notas: el fingerprint que viste, la fecha, y la URL exacta donde lo verificaste. Esto es tu evidencia de diligencia.

### 4. Instalar la clave en formato binario

`apt` espera la clave en formato *binary OpenPGP*, no ASCII armored. `gpg --dearmor` lo convierte:

```bash
sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg "${TMP_KEY}"
sudo chmod 0644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg
sudo chown root:root /etc/apt/keyrings/hashicorp-archive-keyring.gpg
rm -f "${TMP_KEY}"

ls -l /etc/apt/keyrings/hashicorp-archive-keyring.gpg
# -rw-r--r-- 1 root root ... hashicorp-archive-keyring.gpg
```

### 5. Crear el archivo `.sources` (DEB822)

Detecta tu codename:

```bash
. /etc/os-release
echo "Codename: ${VERSION_CODENAME}"
```

Crea el archivo:

```bash
sudo tee /etc/apt/sources.list.d/hashicorp.sources >/dev/null <<EOF
Types: deb
URIs: https://apt.releases.hashicorp.com
Suites: ${VERSION_CODENAME}
Components: main
Signed-By: /etc/apt/keyrings/hashicorp-archive-keyring.gpg
EOF

cat /etc/apt/sources.list.d/hashicorp.sources
```

### 6. Refrescar y confirmar

```bash
sudo apt update
```

Deberías ver una línea tipo `Get:X https://apt.releases.hashicorp.com ${CODENAME} InRelease [...]` y **ningún** warning `NO_PUBKEY` ni "repository is not signed".

### 7. Validar con el test

```bash
bash tests/validate.sh
```

## Reglas duras

- **No** uses `apt-key add -`. Está deprecado.
- **No** metas la clave en `/etc/apt/trusted.gpg.d/`. Eso la haría válida para *cualquier* repo.
- **No** ejecutes `curl ... | sudo bash` ni "scripts de instalación" opacos aunque el proyecto los recomiende.
- **Sí** verifica siempre el fingerprint antes de instalar la clave. Es el único paso que no se puede automatizar.

## Si algo falla

- `NO_PUBKEY <hex>`: la clave no está donde `signed-by=` dice. Comprueba la ruta exacta.
- `The following signatures couldn't be verified`: la clave no coincide con la que firmó el repo. Posible mirror corrupto, URL equivocada, o descarga interrumpida — vuelve al paso 2.
- `E: Malformed entry ...`: error de sintaxis en el `.sources`. Revisa indentación y nombres de campos exactos.
