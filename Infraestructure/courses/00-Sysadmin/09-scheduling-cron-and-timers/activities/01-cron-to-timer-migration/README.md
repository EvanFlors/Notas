# Actividad 01 — Migración de cron a systemd timer

**Tipo:** guided-lab · **Duración:** 45 min · **Módulo:** `sys-09`.

## Contexto

Heredaste un servidor con este crontab de root:

```cron
# /etc/cron.d/backup
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=sysadmin@example.com

30 2 * * * root /usr/local/bin/backup.sh --target /srv/data --dest /var/backups/data >> /var/log/backup.log 2>&1
```

El cliente quiere:

1. **Logs en el journal**, no en un archivo que nadie rota.
2. **Si el host estuvo apagado a las 02:30**, que el backup corra al arrancar.
3. **Jitter aleatorio** de hasta 10 minutos (varios hosts del fleet comparten horario).
4. **Mismo usuario, mismo PATH, mismo comando**: la lógica del script no cambia.

Tu trabajo es portar ese cron a una pareja `.timer` + `.service` equivalente, instalarla, y validar que carga sin errores.

## Objetivos

- Traducir una expresión cron de 5 campos a `OnCalendar=`.
- Reproducir fielmente el entorno (`User=`, `Environment=PATH=`) en el `.service`.
- Añadir `Persistent=true` y `RandomizedDelaySec=` para cubrir los requisitos nuevos.
- Instalar la unit, habilitarla, inspeccionar `systemctl list-timers` y los logs del `.service`.

## Qué hay en el starter

- `starter/old.cron` — el crontab de referencia a migrar.

## Qué debes producir (en `solution/` tuyo)

- `backup.service` — oneshot que ejecuta el comando como `root`, con `PATH` controlado, salida al journal.
- `backup.timer` — dispara `backup.service` todos los días a las 02:30, con `Persistent=true` y `RandomizedDelaySec=10min`.
- `install.sh` — script Bash que copia ambas units a `/etc/systemd/system/`, hace `daemon-reload`, y las habilita (`enable --now backup.timer`). Debe ser idempotente.

## Pasos sugeridos

1. **Lee `starter/old.cron`.** Identifica: usuario, hora, comando, variables, redirección.
2. **Traduce la hora** a `OnCalendar=`. Verifica con `systemd-analyze calendar "<tu expresion>"`.
3. **Escribe el `.service`**: `Type=oneshot`, `User=root`, `Environment=PATH=...`, `ExecStart=` con la ruta absoluta y los argumentos. **No** redirijas con `>>` — systemd ya captura stdout/stderr al journal.
4. **Escribe el `.timer`**: `OnCalendar=`, `Persistent=true`, `RandomizedDelaySec=10min`, `[Install] WantedBy=timers.target`.
5. **Escribe `install.sh`** con `#!/usr/bin/env bash` y `set -euo pipefail`. Pasos: `install -m 0644 ...` ambas units, `systemctl daemon-reload`, `systemctl enable --now backup.timer`.
6. **Verifica**:
   ```bash
   sudo systemd-analyze verify solution/backup.timer solution/backup.service
   sudo bash solution/install.sh
   systemctl list-timers backup.timer
   journalctl -u backup.service -n 20 --no-pager
   sudo systemctl start backup.service   # forzar un disparo
   ```
7. **Corre el validador**: `bash tests/validate.sh ./solution`.

## Validación

El validador comprueba:

- Existen `backup.timer`, `backup.service`, `install.sh` en el directorio pasado como argumento.
- `install.sh` empieza con `#!/usr/bin/env bash` y declara `set -euo pipefail`.
- El `.service` tiene `Type=oneshot`, `User=root`, `ExecStart=/usr/local/bin/backup.sh ...` con los argumentos correctos, y define `Environment=PATH=`.
- El `.timer` tiene `OnCalendar=` apuntando a `02:30`, `Persistent=true`, `RandomizedDelaySec=10min` y `[Install] WantedBy=timers.target`.
- `shellcheck` sobre `install.sh` sin findings (si `shellcheck` está instalado).
- `systemd-analyze verify` sobre ambas units (si está disponible).

```bash
bash tests/validate.sh ./solution
```

## Pistas

- `OnCalendar=*-*-* 02:30:00` es la traducción literal de `30 2 * * *`.
- No pongas `MAILTO` ni `>>` en systemd. El journal captura todo.
- Si no sabes qué `WantedBy` usar en el timer, es `timers.target`. (Y en el `.service`: nada, no se enciende por sí mismo.)
