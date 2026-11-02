# Ejemplo 02 — Timer vs cron: el mismo job, dos formas

El objetivo: **el mismo trabajo real** expresado en cron clásico y en una pareja `.timer`+`.service`. Léelos lado a lado y responde: ¿qué información tiene uno que el otro no?

## El job

> Todos los días a las 03:00, ejecutar `/usr/local/bin/report.sh` como el usuario `reports`, con `PATH` controlado, logueando salida y errores. Si el host estuvo apagado a esa hora, reejecutar al arrancar. Añadir hasta 5 minutos de jitter aleatorio para no coincidir con otras máquinas del fleet.

## Versión cron

Archivo: [`files/report.cron`](files/report.cron)

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=sysadmin@example.com

# m  h  dom mon dow  user     command
0    3  *   *   *    reports  /usr/local/bin/with-jitter.sh 300 /usr/local/bin/report.sh >> /var/log/report.log 2>&1
```

Donde `with-jitter.sh` es un wrapper manual porque cron no sabe hacer jitter:

```bash
#!/usr/bin/env bash
set -euo pipefail
max="${1:?max jitter en segundos}"
shift
sleep "$((RANDOM % max))"
exec "$@"
```

**Para recuperar jobs perdidos** (si el host estuvo apagado): instalar y configurar `anacron`, mover el job a `/etc/cron.daily/`, y aceptar que ya no controlas la hora exacta.

## Versión systemd timer

Archivo `.service`: [`files/report.service`](files/report.service)

```ini
[Unit]
Description=Reporte diario
Documentation=man:report.sh(1)

[Service]
Type=oneshot
User=reports
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/local/bin/report.sh
StandardOutput=journal
StandardError=journal
```

Archivo `.timer`: [`files/report.timer`](files/report.timer)

```ini
[Unit]
Description=Dispara report.service todos los días a las 03:00

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=5min
Unit=report.service

[Install]
WantedBy=timers.target
```

Instalar:

```bash
sudo install -m 0644 files/report.service /etc/systemd/system/
sudo install -m 0644 files/report.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now report.timer

systemctl list-timers report.timer
journalctl -u report.service -n 50
```

## Comparación directa

| Capacidad | Cron | Timer |
|---|---|---|
| Expresión del "cuándo" | 5 campos | `OnCalendar=` + varios triggers combinables |
| Jitter aleatorio | wrapper manual | `RandomizedDelaySec=` nativo |
| Recuperar disparos perdidos | `anacron` (pierde hora exacta) | `Persistent=true` nativo |
| Logging | redirección manual a archivo + MAILTO | `journalctl -u report.service` (metadata, exit code, timestamps) |
| Ejecución forzada ad-hoc | ejecutar el comando a mano | `systemctl start report.service` |
| Estado consultable | ninguno | `systemctl status report.timer` |
| Siguiente disparo visible | hay que calcularlo | `systemctl list-timers` lo imprime |
| Portabilidad | cualquier Unix | solo distros con systemd |
| Líneas de configuración | 4 | ~15 (dos archivos) |

**La versión cron es más corta.** La versión timer es más larga pero el coste adicional compra observabilidad.

## Qué mirar primero cuando algo falla

Cron:
```bash
sudo journalctl -u cron -n 50     # Debian; en RHEL: journalctl -u crond
tail -f /var/log/report.log
```

Timer:
```bash
systemctl status report.timer report.service
journalctl -u report.service --since today
systemd-analyze calendar "*-*-* 03:00:00" --iterations=3
```
