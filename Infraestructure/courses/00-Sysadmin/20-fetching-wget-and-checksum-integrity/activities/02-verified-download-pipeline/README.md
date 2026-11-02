# Actividad 02 — Pipeline de descarga verificada

## 1. Identificación

- **ID:** `sys-20-02-verified-download-pipeline`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-20-fetching-wget-and-checksum-integrity`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** mini-project

## 2. Contexto

Un instalador de un servicio en producción no debe correr nunca un binario que no fue verificado. Vas a escribir un pipeline que **descarga un artefacto, su sidecar `.sha256` y su `.asc` de firma**, verifica checksum, verifica firma, y **aborta** ante cualquier error con exit code semántico.

El lab es **offline-friendly**: si no pasás una URL, el pipeline construye un artefacto local firmado con una clave GPG efímera, para que todo funcione sin red. Si pasás URL + sidecars, el pipeline los descarga de verdad (p. ej. un tarball de GNU).

## 3. Objetivos

Al terminar deberías poder:

- Orquestar `fetch → sha256sum --check → gpg --verify` en un solo script.
- Abortar con exit code semántico (`65 EX_DATAERR` para checksum, `69 EX_UNAVAILABLE` para firma/red).
- Loggear cada paso con timestamp a `stderr`.
- Nunca silenciar TLS. Nunca confiar en `Good signature` sin inspeccionar fingerprint.

## 4. Prerrequisitos

- `wget`, `sha256sum`, `gpg` (≥ 2.2), `bash`, `shellcheck`.
- Actividad `01-wget-with-retries` completada.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
cd activities/02-verified-download-pipeline
cp starter/pipeline.sh pipeline.sh
```

### 5.2 Completar `pipeline.sh`

Interfaz:

```bash
./pipeline.sh [URL_ARTIFACT URL_SHA256 URL_ASC EXPECTED_FINGERPRINT]
```

- Sin argumentos → **modo offline**: generar artefacto, `SHA256SUMS`, clave GPG efímera y firma; verificar todo.
- Con 4 argumentos → **modo online**: descargar los tres artefactos, verificar checksum y firma; además, chequear que la clave que firmó coincida con `EXPECTED_FINGERPRINT`.

Requisitos:

1. Shebang + `set -euo pipefail` + `IFS=$'\n\t'`.
2. Un `trap EXIT` que limpie el `GNUPGHOME` temporal.
3. Para descargas: usá las mismas flags de la actividad 1 (`--continue --tries=5 --waitretry=10 --connect-timeout=10 --read-timeout=30 --retry-connrefused --output-document`).
4. Para checksum: `sha256sum --check --strict`.
5. Para firma: `gpg --verify ARTIFACT.asc ARTIFACT` (o sobre el `SHA256SUMS` según el flujo).
6. En modo online, comparar fingerprint del firmante contra `EXPECTED_FINGERPRINT` (normalizado a mayúsculas sin espacios). Mismatch → **abort exit 69**.
7. Logs `[timestamp] INFO|OK|ERROR` por paso.
8. **Prohibido**: `--no-check-certificate`, `-k`, `--insecure`.

### 5.3 shellcheck

```bash
shellcheck -S warning pipeline.sh
```

### 5.4 Pruebas manuales

```bash
# Offline (sin red)
./pipeline.sh
echo "exit: $?"           # 0

# Online (ejemplo con un release de GNU que publique SHA256 y asc)
# ./pipeline.sh \
#   https://ejemplo.org/tool-1.2.3.tar.gz \
#   https://ejemplo.org/tool-1.2.3.tar.gz.sha256 \
#   https://ejemplo.org/tool-1.2.3.tar.gz.asc \
#   ABCD1234ABCD1234ABCD1234ABCD1234ABCD1234

# Corromper manualmente el artefacto despues de la descarga y re-correr:
# echo bad >> /tmp/sys20-pipeline/artifact
# ./pipeline.sh ; echo $?    # 65
```

### 5.5 Validar

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- Modo offline: exit `0`, logs `OK sha256`, `OK gpg`.
- Si se altera el artefacto antes de verificar: exit `65`.
- Si falta el `.asc` o la firma no verifica: exit `69`.
- Fingerprint mismatch en modo online: exit `69`.
- `shellcheck -S warning` limpio.

## 7. Criterios de aceptación

- [ ] Funcionalidad: modos offline y online.
- [ ] Seguridad: ninguna flag TLS-insegura; fingerprint chequeado en online.
- [ ] Robustez: aborta claro ante checksum o firma mala.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

Chequea: shebang, `set -euo pipefail`, uso de `sha256sum --check`, uso de `gpg --verify`, ausencia de flags prohibidas, modo offline retorna 0, corromper artefacto genera exit 65, `shellcheck -S warning` limpio.

## 9. Preguntas de reflexión

1. ¿Por qué el orden `checksum → firma` o `firma → checksum`? ¿Qué cambia en términos operativos y de defensa?
2. Si `gpg --verify` devuelve `Good signature` pero el fingerprint no está en tu lista conocida, ¿qué hacés?
3. ¿Qué ataque **sigue sin estar** mitigado aun con este pipeline completo? Nombralo y describí una defensa adicional.
4. ¿Por qué firmamos el `SHA256SUMS` y no cada artefacto individualmente? ¿Qué perdés y qué ganás?

## 10. Extensiones (opcional)

- **E1** — Soportá `SHA256SUMS` con múltiples entradas (varios artefactos) y verificá solo los presentes (`--ignore-missing`).
- **E2** — Cacheá el keyring del publisher en `~/.config/sys20/keyring` para no re-importar en cada run.
- **E3** — Agregá un flag `--dry-run` que descargue y verifique **sin** mover el artefacto al destino final.

## 11. Limpieza

```bash
rm -rf /tmp/sys20-pipeline pipeline.sh
```
