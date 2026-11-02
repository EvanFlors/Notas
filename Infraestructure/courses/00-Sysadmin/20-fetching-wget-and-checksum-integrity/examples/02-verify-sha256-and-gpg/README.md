# Ejemplo 02 — Verificar SHA256 y firma GPG

## Concepto que demuestra

El pipeline mínimo correcto: **descargar → verificar checksum → verificar firma → usar**. Y qué ocurre en cada paso si corrompés el input.

## Contexto

Vamos a verificar un artefacto cuyo `SHA256SUMS` conocemos (en este ejemplo, lo generamos nosotros a partir de un archivo local para que el lab sea 100% offline). En la actividad 2 verás una variante con un `SHA256SUMS` **firmado**.

## Objetivo

Al terminar, podrás responder:

- ¿Qué devuelve `sha256sum --check` cuando el archivo coincide? ¿Y cuando no?
- ¿Qué sale `gpg --verify` ante una firma válida? ¿Y una alterada?
- ¿Por qué chequear exit code **y** fingerprint?

## Prerrequisitos

- `sha256sum` (coreutils).
- `gpg` (GnuPG ≥ 2.2) — opcional para la segunda parte.
- Bash.

## Ejecución

```bash
bash files/verify.sh
echo "exit code: $?"
```

Luego, probá "corromper" el archivo entre pasos:

```bash
# Alterar un byte del artefacto y re-correr
echo "manipulado" >> /tmp/sys20-verify/artifact.bin
bash files/verify.sh
echo "exit code: $?"
# Debe FALLAR con mensaje de MISMATCH y exit no-cero.
```

## Resultado esperado

- Primera corrida: `OK sha256`, (si GPG disponible) `OK gpg`, exit `0`.
- Tras corromper: `FAIL sha256sum --check`, exit `65` (`EX_DATAERR`).

## Interpretación

- `sha256sum --check` es el modo *auditable*: lee el `SHA256SUMS` y verifica cada entrada; su exit code es la verdad.
- `gpg --verify` sobre `SHA256SUMS.asc` certifica que *quien firmó la clave* declaró ese `SHA256SUMS`. Si confías en esa clave, confías en el checksum, y por transitividad en el artefacto.
- Nunca saltes a usar el artefacto antes de ambos chequeos.

## Archivos de muestra

- `files/SHA256SUMS.sample` — ejemplo de formato (hash + nombre, dos espacios).
- `files/verify.sh` — pipeline que genera el artefacto, calcula/verifica hash y opcionalmente verifica firma GPG.

## Errores frecuentes

- Comparar hashes "a ojo" en vez de `--check` → fallos silenciosos por errores de copia.
- Confiar en `Good signature` sin inspeccionar `Primary key fingerprint`.
- Usar SHA-1 "porque el proyecto lo publica así" → pedí SHA-256 o migrá a otro proyecto.

## Limpieza

```bash
rm -rf /tmp/sys20-verify
```
