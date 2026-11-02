#!/usr/bin/env bash
# backup.sh — crea un tarball diario de $SRC en $DST, idempotente, con rotación.
#
# Variables de entorno (todas opcionales):
#   SRC   origen a respaldar               (default /srv/myapp)
#   DST   directorio de destino            (default /var/backups/myapp)
#   KEEP  cuántas copias retener           (default 7)
#   LOCK  archivo de lock para flock       (default /var/lock/backup.lock)
#
# Salida: logs informativos a stdout, errores a stderr. Sin archivos de log propios:
# systemd (vía .service con StandardOutput=journal) captura todo al journal.

set -euo pipefail

SRC="${SRC:-/srv/myapp}"
DST="${DST:-/var/backups/myapp}"
KEEP="${KEEP:-7}"
LOCK="${LOCK:-/var/lock/backup.lock}"

log() { printf '[backup %s] %s\n' "$(date -Iseconds)" "$*"; }
die() { printf '[backup %s] ERROR: %s\n' "$(date -Iseconds)" "$*" >&2; exit 1; }

# Numeric sanity on KEEP.
if ! [[ "${KEEP}" =~ ^[0-9]+$ ]] || [[ "${KEEP}" -lt 1 ]]; then
    die "KEEP debe ser un entero >= 1 (recibido: '${KEEP}')"
fi

# Lock no bloqueante: si otro proceso corre, salimos limpios.
exec 9>"${LOCK}"
if ! flock -n 9; then
    die "ya hay otra ejecución en curso (lock: ${LOCK})"
fi

[[ -d "${SRC}" ]] || die "SRC no existe o no es un directorio: ${SRC}"
mkdir -p "${DST}"

today="$(date +%F)"
name="backup-${today}.tar.gz"
target="${DST}/${name}"

if [[ -f "${target}" ]]; then
    log "ya existe ${name}, nada que hacer (idempotencia)"
else
    # Escribir a .part y renombrar para que el nombre final solo exista si está completo.
    tmp="$(mktemp "${DST}/.backup-XXXXXX.tar.gz.part")"
    trap 'rm -f -- "${tmp}"' EXIT
    log "creando ${target} desde ${SRC}"
    tar -czf "${tmp}" -C "${SRC}" .
    mv -- "${tmp}" "${target}"
    trap - EXIT
    log "creado ${target}"
fi

# Rotación: lista por nombre (equivalente a por fecha), elimina los más antiguos.
mapfile -t all < <(find "${DST}" -maxdepth 1 -type f -name 'backup-*.tar.gz' -printf '%f\n' | sort)
total="${#all[@]}"
deleted=0

if (( total > KEEP )); then
    to_delete=$(( total - KEEP ))
    for (( i = 0; i < to_delete; i++ )); do
        rm -f -- "${DST}/${all[i]}"
        log "rotado (borrado) ${all[i]}"
        deleted=$(( deleted + 1 ))
    done
fi

retained=$(( total - deleted ))
# retained puede ser 0 si el único backup acabamos de crearlo y no estaba en 'all'.
if (( retained < 1 )); then
    retained=1
fi

log "ok: retenidos ${retained}, eliminados ${deleted} (keep=${KEEP})"
