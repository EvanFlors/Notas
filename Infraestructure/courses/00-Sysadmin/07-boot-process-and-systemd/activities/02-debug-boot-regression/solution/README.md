# Solución — Regresión de boot

> No leas esto hasta haber intentado diagnosticar por tu cuenta.

## Síntoma observado

`systemctl start broken.service` falla inmediatamente. `systemctl status broken.service` muestra:

```
Active: failed (Result: exit-code)
Process: ... (code=exited, status=203/EXEC)
```

El código `203/EXEC` es la pista: significa que systemd no pudo ejecutar el binario del `ExecStart=`.

## Herramienta clave

```bash
sudo systemd-analyze verify /etc/systemd/system/broken.service
```

Reporta algo como:

```
broken.service: Executable path is not absolute: bash -c '...'
```

`verify` lo detecta **sin arrancar** el servicio. Es la primera herramienta a ejecutar siempre.

## Línea culpable

```
ExecStart=bash -c 'while true; do echo "broken tick $(date -Is)"; sleep 2; done'
```

`bash` no es ruta absoluta. systemd no realiza búsqueda en `$PATH` para `ExecStart=`; exige rutas absolutas (hay que decirle *exactamente* qué ejecutar, sin ambigüedad del entorno).

## Fix mínimo

Cambiar la línea por:

```
ExecStart=/bin/bash -c 'while true; do echo "broken tick $(date -Is)"; sleep 2; done'
```

Una sola línea. Nada más.

## Verificación

```bash
sudo systemd-analyze verify /etc/systemd/system/broken.service
sudo systemctl daemon-reload
sudo systemctl restart broken.service
systemctl is-active broken.service       # => active
journalctl -u broken.service -n 5
```

## Lección

El loop canónico de debug de unidades:

1. **`systemd-analyze verify`** — syntax y semántica estática. Rápido, sin side effects, corre en CI.
2. **`systemctl status`** — estado runtime + exit code + últimas líneas de log inline.
3. **`journalctl -u <unit> -b`** — logs completos del boot actual.
4. **`systemctl cat <unit>`** — ver el archivo efectivo tras drop-ins (descartar que un override introdujo el bug).

Siempre en ese orden salvo que tengas evidencia de otro camino.
