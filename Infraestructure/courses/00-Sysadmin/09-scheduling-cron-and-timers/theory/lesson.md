# Lección — Scheduling: cron y systemd timers

> "El job corrió en mi shell. ¿Por qué cron dice que todo bien pero no pasó nada?" — todo sysadmin, al menos una vez.

## 1. Por qué existe el scheduling

Un servidor largo-plazo tiene tareas que **no se disparan por un usuario pulsando Enter**: rotar logs, hacer backups, renovar certificados, recoger métricas, limpiar `/tmp`, mandar reportes, recomputar caches. Alguien tiene que ejecutarlas **sin tu presencia**, **periódicamente**, **de forma observable** (debes poder decir: *corrió, a qué hora, con qué exit code, qué imprimió*).

Dos herramientas estándar en Linux resuelven esto:

- **`cron`**: el abuelo (1975, Bell Labs). Minimalista, universal, con décadas de rarezas acumuladas.
- **systemd timers**: integrado en el ecosistema de systemd. Logging unificado en el journal, dependencias explícitas, mejor manejo de arranques tardíos.

Ambos conviven. Ambos siguen siendo correctos. Entender los dos te permite elegir con criterio y leer sistemas heredados.

## 2. El modelo mental de cron

`cron` es un **daemon** (`crond` en Red Hat, `cron` en Debian) que:

1. Al arrancar, lee todas las fuentes de jobs:
   - **crontabs de usuario**: `/var/spool/cron/crontabs/<user>` (Debian) o `/var/spool/cron/<user>` (RHEL).
   - **crontab del sistema**: `/etc/crontab`.
   - **drop-ins del sistema**: todos los archivos en `/etc/cron.d/`.
   - **wrappers de frecuencia**: `/etc/cron.hourly/`, `/etc/cron.daily/`, `/etc/cron.weekly/`, `/etc/cron.monthly/` (ejecutados por `run-parts` desde `/etc/crontab` o `anacron`).
2. Se queda dormido. Cada minuto, se despierta, mira el reloj, compara con los campos de cada job, y ejecuta los que corresponden en ese minuto.
3. Captura stdout+stderr y, si hay salida, intenta enviarla por correo al propietario (`MAILTO`).

Tres consecuencias importantes:

- **Granularidad mínima: 1 minuto.** Nada más corto.
- **Si el host está apagado a la hora programada, el job se pierde.** Punto. (Para eso existe `anacron`.)
- **El entorno del job es casi vacío.** No es tu login shell. Es un `/bin/sh -c "..."` lanzado por un daemon.

## 3. Sintaxis de 5 campos

```
┌───────────── minuto         (0 - 59)
│ ┌─────────── hora           (0 - 23)
│ │ ┌───────── día del mes    (1 - 31)
│ │ │ ┌─────── mes            (1 - 12)  o jan-dec
│ │ │ │ ┌───── día de semana  (0 - 7)   0 y 7 = domingo
│ │ │ │ │
* * * * *  comando
```

Operadores sobre cualquier campo:

| Operador | Significado | Ejemplo | Lectura |
|---|---|---|---|
| `*` | cualquier valor | `* * * * *` | cada minuto |
| `,` | lista | `0,15,30,45 * * * *` | minutos 0, 15, 30, 45 |
| `-` | rango | `0 9-17 * * *` | cada hora de 9 a 17 |
| `/` | paso | `*/5 * * * *` | cada 5 minutos |
| combinado | `0-30/10 * * * *` | | min 0, 10, 20, 30 |

Shortcuts (equivalencias):

| Shortcut | Equivale a |
|---|---|
| `@yearly` / `@annually` | `0 0 1 1 *` |
| `@monthly` | `0 0 1 * *` |
| `@weekly` | `0 0 * * 0` |
| `@daily` / `@midnight` | `0 0 * * *` |
| `@hourly` | `0 * * * *` |
| `@reboot` | al arrancar `crond` (una sola vez) |

**Trampa clásica del día del mes + día de semana**: cuando **ambos** están especificados (no `*`), cron ejecuta si **cualquiera** de los dos matchea, no ambos. `0 0 1 * 1` dispara el **día 1 del mes** O **cada lunes**, no "los lunes 1".

## 4. Formato de línea completa

Un crontab de usuario:

```cron
# m   h  dom mon dow  comando
*/15  *  *   *   *    /usr/local/bin/collect-metrics.sh
0     3  *   *   *    /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1
```

Un `/etc/crontab` o un archivo de `/etc/cron.d/` tiene un **campo extra**: el usuario.

```cron
# m  h  dom mon dow  user     command
0    4  *   *   *    postgres /usr/local/bin/pg-dump.sh
```

Esa diferencia explica por qué copiar y pegar entre crontab personal y `/etc/cron.d/` suele romper cosas.

## 5. Variables de entorno en crontab

Antes de los jobs, puedes definir variables. Son las **únicas** que estarán disponibles:

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=sysadmin@example.com
TZ=America/Mexico_City

0 3 * * * /usr/local/bin/backup.sh
```

- **`SHELL`**: con qué shell se ejecuta el comando. Por defecto `/bin/sh`.
- **`PATH`**: casi siempre más corto que el de tu login. Por eso `python` falla pero `/usr/bin/python` funciona. **Usa rutas absolutas o define `PATH` explícito.**
- **`MAILTO`**: a dónde se envía la salida del job. Vacío (`MAILTO=""`) para suprimir correo.
- **`TZ`**: zona horaria interpretada por cron. **OJO**: no todas las implementaciones honran `TZ` dentro del crontab; algunas usan la del sistema (`/etc/localtime`). Verifica con `date` dentro de un job de prueba.

## 6. `anacron`: cuando el host no está siempre encendido

`cron` **no** reejecuta jobs perdidos. Si tu laptop estaba apagada a las 03:00, el backup de las 03:00 no corre. `anacron` resuelve esto para jobs diarios/semanales/mensuales:

- Guarda la última ejecución exitosa en `/var/spool/anacron/`.
- Al arrancar (o cuando se le invoca), compara "hace cuánto que no corrí este job" con el período configurado.
- Si pasó el período, lo ejecuta **con un retraso aleatorio** para no saturar el sistema al boot.

Configurado en `/etc/anacrontab`:

```
# period(días) delay(min) job-id    command
1    5    cron.daily    run-parts --report /etc/cron.daily
7    25   cron.weekly   run-parts --report /etc/cron.weekly
```

En servidores siempre encendidos `anacron` es irrelevante. En laptops/workstations es esencial.

## 7. `at`: scheduling de un solo tiro

Para "corre esto una vez, dentro de X tiempo":

```bash
echo "/usr/local/bin/notify.sh" | at now + 10 minutes
echo "shutdown -h now" | at 02:30 tomorrow
atq                 # lista pendientes
atrm <jobid>        # cancela
```

Útil para mantenimientos puntuales. En producción se usa poco porque es poco auditable.

## 8. systemd timers: el modelo moderno

Un timer de systemd es **una unit** (`.timer`) que, al dispararse, activa otra unit (`.service`). Son **dos archivos** vinculados por el nombre.

### 8.1 La pareja mínima

`/etc/systemd/system/backup.service`:

```ini
[Unit]
Description=Backup diario del directorio de datos

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
User=backups
```

`/etc/systemd/system/backup.timer`:

```ini
[Unit]
Description=Dispara backup.service todos los días a las 03:00

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=5min
Unit=backup.service

[Install]
WantedBy=timers.target
```

Instalación:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer
systemctl list-timers --all
journalctl -u backup.service -n 50
```

Notas:

- Si el `.service` tiene **el mismo nombre base** que el `.timer`, la directiva `Unit=` es opcional. Se infiere.
- `enable --now` crea el enlace en `timers.target.wants` **y** arranca el timer sin esperar al próximo boot.

### 8.2 Directivas clave del `[Timer]`

| Directiva | Significado |
|---|---|
| `OnCalendar=` | Especificación tipo-cron pero más expresiva. Ej.: `Mon,Fri *-*-* 09:00`, `*-*-01 00:00` (día 1 de cada mes), `hourly`, `daily`. |
| `OnBootSec=` | X tiempo tras el boot del sistema. |
| `OnStartupSec=` | X tiempo tras arrancar systemd (prácticamente igual a `OnBootSec` para el PID 1). |
| `OnUnitActiveSec=` | X tiempo tras la última activación del service asociado (útil para "cada N horas desde la última vez que corrió"). |
| `OnUnitInactiveSec=` | X tiempo tras la última desactivación. |
| `Persistent=true` | Si el host estuvo apagado y se perdió el disparo, lo ejecuta en cuanto el timer arranque. **Es el `anacron` incorporado.** |
| `RandomizedDelaySec=` | Añade un jitter aleatorio para evitar que N máquinas disparen a la misma hora exacta. |
| `AccuracySec=` | Ventana de tolerancia (por defecto 1 min). Más grande = menos consumo (systemd agrupa disparos). |
| `WakeSystem=` | Si debe despertar al sistema desde suspend. |

### 8.3 Sintaxis de `OnCalendar=`

Formato: `DOW YYYY-MM-DD HH:MM:SS` donde cualquier campo acepta `*` o listas. Ejemplos útiles:

```ini
OnCalendar=hourly                 ; a los :00 cada hora
OnCalendar=daily                  ; 00:00 cada día
OnCalendar=weekly                 ; lunes 00:00
OnCalendar=*-*-* 03:00:00         ; todos los días a las 03:00
OnCalendar=Mon..Fri *-*-* 09:00   ; L-V a las 09:00
OnCalendar=*-*-01 00:00:00        ; primer día de cada mes
OnCalendar=*:0/15                 ; cada 15 minutos
```

Para probar una expresión sin esperar:

```bash
systemd-analyze calendar "Mon..Fri *-*-* 09:00"
```

## 9. Cron vs systemd timers — tabla sincera

| Aspecto | cron | systemd timer |
|---|---|---|
| Granularidad | 1 minuto | 1 segundo (con `AccuracySec=1s`) |
| Logs | correo local; redirección manual a archivo | journal unificado (`journalctl -u`) |
| Estado | ninguno, es stateless | `systemctl status`, `list-timers` |
| Jobs perdidos (host apagado) | no se recuperan | `Persistent=true` sí |
| Jitter aleatorio | manual (`sleep $((RANDOM % 300))`) | `RandomizedDelaySec=` |
| Dependencias entre jobs | no | `After=`, `Requires=` del `.service` |
| Entorno | mínimo, `PATH` corto | tomado del `.service` (`Environment=`, `EnvironmentFile=`) |
| Portabilidad | universal (todo Unix) | solo distros con systemd |
| Curva de aprendizaje | plana | dos archivos por job |
| Debug de un fallo | `grep CRON /var/log/syslog` + revisar correo | `systemctl status`, `journalctl -u`, exit code visible |

**Regla práctica:**

- Script trivial, host simple, equipo acostumbrado a cron → **cron está bien**.
- Jobs con dependencias, logging consultable, host que puede estar apagado, varios hosts coordinados → **timers**.

## 10. Internals: ¿quién corre el job y con qué entorno?

Esta es **la causa #1** de los bugs "funciona en mi shell pero no en el scheduler". Entenderlo evita horas perdidas.

### 10.1 Usuario

- **Crontab de usuario (`crontab -e`)**: corre como ese usuario. Con su UID, GID, grupos secundarios, `HOME`.
- **`/etc/crontab` y `/etc/cron.d/`**: el usuario se especifica en el campo extra. Si no, cron rechaza la línea.
- **Timer de systemd**: corre como el `User=` del `.service` asociado (`root` si no se especifica).

### 10.2 Entorno (variables)

- **cron** limpia casi todo. Define típicamente:
  - `HOME=` (del usuario)
  - `LOGNAME=` (del usuario)
  - `SHELL=/bin/sh`
  - `PATH=/usr/bin:/bin`
  - Nada más.
- **systemd service** limpia **todavía más** por defecto, pero permite declararlo explícitamente:
  ```ini
  [Service]
  Environment=LANG=C.UTF-8
  Environment=PATH=/usr/local/bin:/usr/bin:/bin
  EnvironmentFile=/etc/default/backup
  ```

Lo que **nunca** heredas automáticamente en ninguno de los dos:

- Tu `PATH` de login (nada de `~/.cargo/bin`, `~/go/bin`, `~/.local/bin`).
- Variables puestas en `~/.bashrc`, `~/.zshrc`, `~/.profile` (no se cargan: no es shell interactiva ni de login).
- Agentes (`SSH_AUTH_SOCK`, `GPG_AGENT_INFO`).
- Virtualenvs activados.

### 10.3 Directorio de trabajo (`cwd`)

- **cron**: `cwd` es `HOME` del usuario.
- **systemd service**: `cwd` es `/` salvo que uses `WorkingDirectory=`.

Si tu script hace `cat ./config.yml`, en ambos casos probablemente falle. Usa rutas absolutas o fija `cd` al principio del script.

### 10.4 TTY

Ninguno de los dos tiene TTY. `read`, `sudo` interactivo, cualquier cosa que pida stdin se cuelga o falla.

## 11. Walkthrough: *"el cron no corre y no sé por qué"*

Caso: tienes esto en tu crontab y, según el log, nunca corre:

```cron
*/5 * * * * backup.sh >> ~/backup.log
```

Pasos de debug, en orden:

**(1) ¿El demonio está activo?**

```bash
systemctl status cron       # Debian
systemctl status crond      # RHEL
```

Si está `inactive (dead)`, nada corre. Enciéndelo (`enable --now`).

**(2) ¿Cron ve tu crontab?**

```bash
crontab -l
sudo grep CRON /var/log/syslog | tail -20     # Debian
sudo journalctl -u cron -n 50                 # systemd
```

Busca una línea tipo `CMD (backup.sh >> /home/you/backup.log)`. Si está, cron **sí** intentó correr. Si no, el crontab no se registró (¿guardaste en el editor?).

**(3) ¿El comando se resuelve?**

```bash
which backup.sh
```

Si está en `~/bin/backup.sh` o `/usr/local/bin/backup.sh`, cron **no lo encontrará** salvo que uses ruta absoluta o definas `PATH` en el crontab:

```cron
PATH=/usr/local/bin:/usr/bin:/bin:/home/you/bin
*/5 * * * * backup.sh >> /home/you/backup.log 2>&1
```

**Nota adicional**: `~` no se expande en el campo de redirección como podrías esperar. Usa `$HOME` o la ruta absoluta.

**(4) ¿Captura stderr?**

El original tiene `>> ~/backup.log` que **solo redirige stdout**. Si el script explota, el error va a stderr, que cron intenta mandar por correo, y si no hay MTA local, se pierde silenciosamente. **Siempre** usa `2>&1`:

```cron
*/5 * * * * /usr/local/bin/backup.sh >> /home/you/backup.log 2>&1
```

**(5) ¿Funciona en el entorno de cron?**

Simula el entorno de cron explícitamente:

```bash
env -i HOME="$HOME" PATH=/usr/bin:/bin SHELL=/bin/sh /bin/sh -c '/usr/local/bin/backup.sh'
```

Si falla **aquí**, falla en cron. Ahora puedes depurar la causa real (`python` no está, `.env` no está cargado, el virtualenv no está activo, etc.).

**(6) Para timers de systemd, el equivalente:**

```bash
systemctl list-timers --all | grep backup
systemctl status backup.timer backup.service
journalctl -u backup.service -n 100 --no-pager
sudo systemctl start backup.service     # fuerza una ejecución ahora
```

El journal muestra el exit code y stdout/stderr del service sin trucos de redirección.

## 12. Buenas prácticas (consolidadas)

- **Rutas absolutas** en comandos y archivos. Siempre.
- **`PATH` explícito** en crontab, o en `Environment=` del service.
- **`2>&1`** en cron para no perder stderr. En systemd no lo necesitas, el journal captura ambos.
- **Scripts idempotentes**: reejecutar no debe corromper nada. Un backup repetido debería ser seguro.
- **Lock para evitar solapes**: `flock -n /var/lock/backup.lock` o directiva `ExecStart=flock ...`. Para timers, el `.service` siendo `Type=oneshot` ya evita que systemd dispare dos a la vez.
- **Logs estructurados**: una línea por operación con timestamp, con identificador del job. En systemd basta con `echo` del script; va al journal con metadata completa.
- **Alerta en fallo**: `OnFailure=notify@%n.service` en el `.service` (unit template que mande a Slack/email/etc.). En cron, un wrapper que haga `curl ... || true` al terminar.
- **Zona horaria consistente**: si varias máquinas corren el mismo job, decide si usas UTC o local; documéntalo en comentarios.
- **Testéalo antes de confiar**: `systemd-analyze calendar` para la expresión; `systemctl start` para forzar un disparo; verifica el journal.
- **Un job = un propósito**. Jobs monolíticos ("hace backup, rota, notifica, limpia") son difíciles de depurar. Divide en varios `.service` encadenados con `After=`.

## 13. Checklist antes de dar un job por "listo"

- [ ] ¿Rutas absolutas en todas partes?
- [ ] ¿`PATH` definido explícitamente?
- [ ] ¿stderr capturado?
- [ ] ¿El script es idempotente?
- [ ] ¿Hay protección contra solapes?
- [ ] ¿Puedes ver fácilmente si corrió hoy y qué pasó?
- [ ] ¿Qué pasa si el host estuvo apagado a la hora programada?
- [ ] ¿Qué pasa si el script tarda más que el intervalo?
- [ ] ¿Está documentado quién lo instaló y por qué?

## 14. Preguntas de evaluación

Responde sin consultar documentación:

1. En tu distro, ¿cuál es el `PATH` por defecto que usa un cron de root? ¿cómo lo verificarías empíricamente con un job de prueba de una línea?
2. Explica la diferencia semántica entre `OnCalendar=daily` y `0 0 * * *` en cron, considerando un host que estuvo apagado toda la madrugada.
3. ¿Qué diferencia hay entre `OnBootSec=` y `OnStartupSec=`? ¿cuándo elegirías cada uno?
4. Tienes un cron que corre cada 5 minutos y a veces el job tarda 7. ¿Qué puede pasar? ¿cómo lo prevendrías con `flock`? ¿y con un timer de systemd?
5. ¿Por qué `~` dentro de una línea de crontab no siempre se expande como esperas? Da la alternativa correcta.
6. Un job de cron falla silenciosamente. Lista 5 causas distintas, cada una con cómo descartarla.
7. Portas este cron a timer: `30 2 * * 0 /usr/local/bin/weekly-report.sh`. Escribe la pareja `.timer` + `.service` mínima equivalente, con `Persistent=true`.
