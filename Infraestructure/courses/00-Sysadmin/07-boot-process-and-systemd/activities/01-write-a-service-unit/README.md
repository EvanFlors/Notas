# Actividad 01 — Escribir un unit file de servicio

## 1. Identificación

- **ID:** `sys-07-01-write-a-service-unit`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-07-boot-process-and-systemd`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a tomar un script `starter/app.sh` que no sabe nada de systemd (es un loop infinito que imprime a stdout) y a envolverlo en un `.service` civilizado: habilitable al boot, supervisado con `Restart=on-failure`, con logs al journal, y con un mínimo de hardening.

Al terminar, podrás escribir una unidad desde cero sin plantilla y defender cada línea.

## 3. Objetivos

Al terminar deberías poder:

- Escribir una `.service` con las tres secciones (`[Unit]`, `[Service]`, `[Install]`).
- Instalarla en `/etc/systemd/system/`, hacer `daemon-reload`, `enable`, `start`.
- Verificar que los logs van al journal.
- Confirmar que el servicio reinicia tras `kill -9`.
- Validar la unidad con `systemd-analyze verify` sin warnings.

## 4. Prerrequisitos

- Linux con systemd (cualquier distro moderna). WSL2 funciona si tienes systemd habilitado.
- `sudo` disponible.
- `bash`, `systemctl`, `journalctl`, `systemd-analyze` instalados (vienen con systemd).

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Inspecciona el starter

```bash
cat starter/app.sh
chmod +x starter/app.sh
./starter/app.sh &   # pruébalo manualmente
# Ctrl+C o kill %1 cuando te canses
```

Es un loop que imprime una línea cada 2 segundos. No hace nada útil; el punto es *supervisarlo* con systemd.

### 5.2 Copia el script a una ubicación permanente

Las rutas en unit files **deben** ser absolutas:

```bash
sudo install -m 0755 starter/app.sh /usr/local/bin/sys07-app
```

### 5.3 Escribe tu unit file

Crea `/etc/systemd/system/sys07-app.service` con tu editor favorito. Debe cumplir:

- `Description=` significativo.
- `After=network-online.target` y `Wants=network-online.target`.
- `Type=simple`.
- `User=nobody`, `Group=nogroup` (o `nobody` en algunas distros).
- `ExecStart=/usr/local/bin/sys07-app`.
- `Restart=on-failure` + `RestartSec=` razonable.
- `StartLimitIntervalSec=` + `StartLimitBurst=` para evitar loops.
- Al menos **tres** de: `PrivateTmp=`, `ProtectSystem=`, `ProtectHome=`, `NoNewPrivileges=`.
- Sección `[Install]` con `WantedBy=multi-user.target`.

Hay una solución de referencia en `solution/app.service`. **No la mires hasta terminar.**

### 5.4 Valida la sintaxis sin activarla

```bash
sudo systemd-analyze verify /etc/systemd/system/sys07-app.service
```

Debe salir **sin output** (silencio = OK). Cualquier warning se corrige antes de continuar.

### 5.5 Activa

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sys07-app.service
systemctl status sys07-app.service
```

### 5.6 Observa los logs

```bash
journalctl -u sys07-app.service -f
```

Debes ver una línea cada 2 segundos. Ctrl+C para salir del follow (el servicio sigue corriendo).

### 5.7 Prueba la supervisión

Mata el proceso brutalmente:

```bash
sudo pkill -9 -f /usr/local/bin/sys07-app
```

Verifica que vuelve solo:

```bash
systemctl status sys07-app.service
journalctl -u sys07-app.service -n 20
```

Debes ver un evento "Main process exited" seguido de "Scheduled restart job" y el proceso de nuevo activo.

### 5.8 Valida todo

```bash
bash tests/validate.sh
```

Debe terminar con `OK: unit cumple requisitos`.

## 6. Resultado esperado

- `/etc/systemd/system/sys07-app.service` existe y es válida.
- `systemctl is-enabled sys07-app.service` devuelve `enabled`.
- `systemctl is-active sys07-app.service` devuelve `active`.
- `journalctl -u sys07-app.service` muestra al menos 5 líneas de output del script.
- `systemd-analyze verify` no reporta nada.
- Tras `kill -9`, el servicio reinicia en menos de 10s.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: la unidad arranca, loguea, reinicia tras crash.
- [ ] **Calidad**: `systemd-analyze verify` limpio.
- [ ] **Seguridad**: corre como `nobody`, al menos tres opciones de hardening.
- [ ] **Reproducibilidad**: `solution/install.sh` reproduce todo el setup.
- [ ] **Mantenibilidad**: cada directiva es defendible (no copy-paste ciego).

## 8. Validación

```bash
bash tests/validate.sh
```

Verifica: existencia del archivo, syntax, estado activo/enabled, `Restart=on-failure`, `User=` no-root, sección `[Install]`, logs presentes.

## 9. Preguntas de reflexión

Responde (puedes escribir en `starter/notes.md` si lo creas):

1. ¿Qué pasa si quitas la sección `[Install]` y haces `systemctl enable`? ¿Y `start`?
2. ¿Por qué `User=nobody` sin `ProtectSystem=` no es suficiente desde el punto de vista de seguridad?
3. ¿Qué diferencia observable hay entre `Restart=always` y `Restart=on-failure` para este servicio concreto?
4. Si pones `WantedBy=graphical.target` en vez de `multi-user.target`, ¿qué cambia en la práctica para un servidor sin GUI?
5. ¿Por qué el `ExecStart=` debe ser una ruta absoluta y no `app.sh`?

## 10. Extensiones (opcional)

- **E1** — Agrega `WatchdogSec=` y modifica el script para llamar a `systemd-notify WATCHDOG=1` periódicamente. Observa qué pasa si dejas de notificar.
- **E2** — Convierte el `.service` en `.timer` + `.service` (una ejecución cada minuto en vez de loop infinito).
- **E3** — Agrega un drop-in en `/etc/systemd/system/sys07-app.service.d/override.conf` que ajuste `MemoryMax=`. Verifica con `systemctl show -p MemoryMax`.
- **E4** — Corre `systemd-analyze security sys07-app.service` y agrega opciones de hardening hasta bajar el score por debajo de 5.

## 11. Limpieza

```bash
sudo systemctl disable --now sys07-app.service
sudo rm /etc/systemd/system/sys07-app.service
sudo rm -f /etc/systemd/system/sys07-app.service.d/*.conf
sudo rmdir /etc/systemd/system/sys07-app.service.d 2>/dev/null || true
sudo rm -f /usr/local/bin/sys07-app
sudo systemctl daemon-reload
```
