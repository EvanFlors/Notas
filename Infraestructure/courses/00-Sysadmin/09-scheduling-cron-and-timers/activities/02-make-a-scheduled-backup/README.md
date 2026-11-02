# Actividad 02 — Backup programado con rotación y logs al journal

**Tipo:** mini-project · **Duración:** 60 min · **Módulo:** `sys-09`.

## Contexto

Diseña e implementa, desde cero, un backup programado real que cumpla **cuatro propiedades no negociables**:

1. **Idempotente**: lanzarlo dos veces seguidas no corrompe ni duplica basura. Si ya existe el backup del día, puede reemplazarlo o saltarlo, pero no debe fallar.
2. **Observable en el journal**: toda operación significativa va al journal mediante stdout/stderr (systemd lo captura). No crees archivos de log propios.
3. **Rotación**: conserva como máximo **N** copias (configurable, por defecto 7). Elimina las más antiguas.
4. **Programado con systemd**: pareja `.timer`+`.service`, dispara diariamente, `Persistent=true`, corre como `root` (es un backup del sistema).

## Objetivos

- Escribir un script Bash defensivo (`set -euo pipefail`, shellcheck-clean, rutas absolutas).
- Diseñar un esquema de nombres y rotación que sea trivial de inspeccionar (`ls` en el directorio de destino debe contar la historia).
- Escribir una pareja `.timer`+`.service` correcta: `Type=oneshot`, salida al journal, `OnCalendar=`, `Persistent=true`.
- Validar que `systemd-analyze verify` acepta las units.

## Qué hay en el starter

- `starter/README.md` — bosquejo con las decisiones que debes tomar y pistas para empezar.

## Qué debes producir (en `solution/` tuyo)

- `backup.sh` — script Bash con:
  - `#!/usr/bin/env bash`, `set -euo pipefail`.
  - Variables parametrizadas (vía env, con defaults sanos): `SRC` (origen), `DST` (destino), `KEEP` (número de copias a retener, default 7).
  - Un **lock** con `flock` sobre un archivo bajo `/var/lock/` para evitar solapes.
  - Nombre del backup predecible por fecha: `backup-YYYY-MM-DD.tar.gz`.
  - **Idempotencia**: si ya existe el backup del día, no re-tarring; log y salida 0.
  - **Rotación**: tras crear el nuevo, lista todos los `backup-*.tar.gz`, ordena por fecha, elimina los que exceden `KEEP`.
  - Logs informativos (fecha, src, dst, acción tomada, cantidad de archivos retenidos y eliminados) por stdout; errores por stderr.
- `backup.service` — oneshot que invoca `/usr/local/bin/backup.sh`, con `User=root`, `Environment=` con las variables antes mencionadas, stdout/stderr al journal.
- `backup.timer` — dispara `backup.service` diariamente a las 02:00, `Persistent=true`.

## Pasos sugeridos

1. **Diseña primero**: en papel, dibuja qué va a haber en `/var/backups/myapp/` después de 10 días. Define exactamente el formato del nombre y el criterio de rotación.
2. **Escribe `backup.sh`**. Pruébalo a mano con `SRC=/tmp/fuente DST=/tmp/dest KEEP=3 bash backup.sh` sobre directorios de prueba. Verifica idempotencia (córrelo dos veces el mismo día) y rotación (fuerza fechas pasadas con `touch -d "..." backup-YYYY-MM-DD.tar.gz` falsos y relanza).
3. **Shellcheck**: `shellcheck solution/backup.sh` y arregla todo. Cero findings.
4. **Escribe el `.service`** con `Environment=` para `SRC`/`DST`/`KEEP`.
5. **Escribe el `.timer`** con `OnCalendar=*-*-* 02:00:00`, `Persistent=true`, `WantedBy=timers.target`.
6. **Verifica units**: `systemd-analyze verify solution/backup.{service,timer}`.
7. **Corre el validador**: `bash tests/validate.sh ./solution`.

## Validación

El validador comprueba:

- Los tres archivos existen.
- `backup.sh` empieza con shebang `#!/usr/bin/env bash` y declara `set -euo pipefail`.
- `backup.sh` usa `flock` para locking.
- `backup.sh` referencia `KEEP` y `tar` en su cuerpo.
- `shellcheck` sobre `backup.sh` sin findings (si está instalado).
- **Smoke test funcional**: el validador prepara un `SRC` temporal con contenido, corre `backup.sh` dos veces seguidas, y comprueba:
  - La segunda ejecución no falla (idempotencia).
  - Se creó exactamente **un** `backup-*.tar.gz` tras ambas ejecuciones.
  - El tarball es extraíble y contiene los archivos de origen.
- Rotación: el validador fabrica 5 backups falsos con fechas antiguas, corre `backup.sh` con `KEEP=3`, y comprueba que quedan como máximo 3.
- `.service` tiene `Type=oneshot`, `ExecStart=/usr/local/bin/backup.sh`.
- `.timer` tiene `OnCalendar=`, `Persistent=true`, `WantedBy=timers.target`.
- `systemd-analyze verify` opcional.

```bash
bash tests/validate.sh ./solution
```

## Pistas

- `flock -n 9` + `exec 9>"$LOCK"` para no bloquear si otro proceso ya corre.
- `date +%F` da `YYYY-MM-DD`.
- `find "$DST" -maxdepth 1 -name 'backup-*.tar.gz' -printf '%f\n' | sort` lista cronológicamente (los nombres ordenan igual que las fechas).
- `tar -czf tmp && mv tmp final` es más seguro que escribir directo al nombre final (evita dejar tarballs a medio escribir si el proceso muere).
