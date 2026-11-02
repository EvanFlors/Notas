# Starter — backup programado

Vas a construir **tres** archivos en `solution/` (hermano de este starter):

```
solution/
├── backup.sh        # script Bash
├── backup.service   # unit systemd
└── backup.timer     # unit systemd
```

## Decisiones que debes tomar

Antes de escribir código, decide y anota:

- **Dónde van las copias**. Sugerencia: `/var/backups/myapp/`.
- **Qué incluye el backup**. Sugerencia: parametrizar con `SRC` (default `/srv/myapp`).
- **Formato del nombre**: `backup-YYYY-MM-DD.tar.gz` es lo recomendado — ordena cronológicamente con `sort`.
- **Cuántas copias retener**: variable `KEEP` (default 7).
- **Cómo marcas idempotencia**: ¿si ya existe `backup-$(date +%F).tar.gz`, saltas o reemplazas? La elección impacta los tests.
- **Dónde pones el lock**: `/var/lock/backup.lock` para producción; en tests podrás sobreescribir con `LOCK=...`.

## Esqueleto sugerido

```bash
#!/usr/bin/env bash
set -euo pipefail

SRC="${SRC:-/srv/myapp}"
DST="${DST:-/var/backups/myapp}"
KEEP="${KEEP:-7}"
LOCK="${LOCK:-/var/lock/backup.lock}"

log()  { printf '[backup %s] %s\n' "$(date -Iseconds)" "$*"; }
die()  { printf '[backup %s] ERROR: %s\n' "$(date -Iseconds)" "$*" >&2; exit 1; }

# 1. Lock
exec 9>"${LOCK}"
flock -n 9 || die "ya hay otra ejecución en curso (lock: ${LOCK})"

# 2. Validaciones
[[ -d "${SRC}" ]] || die "SRC no existe: ${SRC}"
mkdir -p "${DST}"

# 3. Nombre y skip si existe
name="backup-$(date +%F).tar.gz"
target="${DST}/${name}"
if [[ -f "${target}" ]]; then
    log "ya existe ${name}, nada que hacer (idempotencia)"
    exit 0
fi

# 4. Crear tarball a archivo temporal y mover (atómico-ish)
tmp="$(mktemp "${DST}/.backup-XXXXXX.tar.gz.part")"
trap 'rm -f "${tmp}"' EXIT
tar -czf "${tmp}" -C "${SRC}" .
mv "${tmp}" "${target}"
trap - EXIT
log "creado ${target}"

# 5. Rotación: dejar como máximo KEEP
mapfile -t all < <(find "${DST}" -maxdepth 1 -name 'backup-*.tar.gz' -printf '%f\n' | sort)
total="${#all[@]}"
if (( total > KEEP )); then
    to_delete=$(( total - KEEP ))
    for ((i = 0; i < to_delete; i++)); do
        rm -f -- "${DST}/${all[i]}"
        log "rotado (borrado) ${all[i]}"
    done
fi

log "ok: retenidos $(( total > KEEP ? KEEP : total )), eliminados $(( total > KEEP ? total - KEEP : 0 ))"
```

Léelo, entiéndelo, **reescríbelo tú**. No lo copies tal cual.

## systemd units

- `backup.service`: `Type=oneshot`, `User=root`, `Environment=SRC=...`, `Environment=DST=...`, `Environment=KEEP=7`, `ExecStart=/usr/local/bin/backup.sh`.
- `backup.timer`: `OnCalendar=*-*-* 02:00:00`, `Persistent=true`, `WantedBy=timers.target`.

## Cómo testear sin esperar a mañana

```bash
sudo install -m 0755 solution/backup.sh /usr/local/bin/backup.sh
sudo install -m 0644 solution/backup.service /etc/systemd/system/
sudo install -m 0644 solution/backup.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer
sudo systemctl start backup.service          # fuerza una ejecución ahora
journalctl -u backup.service -n 50 --no-pager
```
