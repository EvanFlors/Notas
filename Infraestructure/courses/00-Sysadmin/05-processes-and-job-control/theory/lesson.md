# sys-05 — Teoría: Procesos y control de trabajos

> Objetivo pedagógico: que al terminar sepas **qué** es un proceso, **cómo** se controla con señales, y **por qué** el shell distingue entre jobs en foreground y background. Al final hay preguntas de evaluación.

---

## 1. Proceso vs programa

Un **programa** es un artefacto en disco: un ELF ejecutable, un script con *shebang*, un bytecode. Es inerte.

Un **proceso** es la ejecución *viva* de ese programa: tiene memoria virtual propia, descriptores de archivo abiertos, un `PID`, un `PPID`, un grupo, una sesión, variables de entorno, un `cwd`, un `umask`, prioridades, límites y una tabla de disposiciones de señales.

Un mismo programa puede dar lugar a decenas de procesos simultáneos (`bash`, `python`, `nginx worker`). Un proceso puede, mediante `exec`, reemplazar el programa que ejecuta sin cambiar su `PID`.

Modelo mental: **PID = contenedor de recursos** del kernel; **programa = contenido** actual que ese contenedor ejecuta.

---

## 2. Identidades: PID, PPID, PGID, SID

Cada proceso lleva cuatro identificadores *topológicos*:

| Identidad | Significado | Dónde se ve |
|-----------|-------------|-------------|
| `PID`  | Identificador único del proceso. | `ps -o pid`, `$$`. |
| `PPID` | PID del padre. Si el padre muere antes, pasa a 1 (o al *subreaper*). | `ps -o ppid`, `$PPID`. |
| `PGID` | Grupo de procesos. Útil para enviar una señal a todos a la vez. | `ps -o pgid`. |
| `SID`  | Sesión. Agrupa grupos; típicamente una sesión = una terminal. | `ps -o sid`. |

Más identidades de seguridad: `UID`, `EUID` (effective), `SUID` (saved), `FSUID`. Las ves con `ps -o uid,euid,user` y en `/proc/[pid]/status`.

### Jerarquía

```
init/systemd (PID 1, SID=1, PGID=1)
└── login/sshd  (nueva sesión)
    └── bash   (PGID = SID = bash)
        ├── (fg) vim         ← grupo foreground
        └── (bg) long-task & ← grupo background del mismo SID
```

El **grupo foreground** de una terminal es el único que recibe señales desde el teclado (`Ctrl-C` → `SIGINT`, `Ctrl-Z` → `SIGTSTP`).

---

## 3. fork / exec / wait

El modelo UNIX para crear procesos es `fork()` + `exec()`. No existe "`spawn(program)`" en una sola llamada clásica.

1. `fork()` duplica el proceso. El hijo hereda:
   - Memoria (copy-on-write).
   - Descriptores de archivo abiertos.
   - `cwd`, `umask`, variables de entorno.
   - Disposiciones de señales (algunas se resetean en el `exec`).
2. `exec()` reemplaza la imagen de memoria del proceso por otro programa. **Mismo `PID`**, nuevo código. Los `fd` abiertos sobreviven salvo que estén marcados `O_CLOEXEC`.
3. `wait()` / `waitpid()` recolectan el *exit status* de un hijo terminado. **Mientras no se recoja, el hijo queda como `Z` (zombie).**

Esto explica tres cosas que confunden:

- Por qué `cd` **no** puede ser un binario externo: cambiaría el `cwd` del hijo, no del shell. Debe ser *builtin*.
- Por qué pipelines como `a | b` son tres procesos: el shell hace `fork` dos veces y conecta sus `fd` con un `pipe(2)` antes de `exec`.
- Por qué un script con `exec otro-programa` reemplaza al script: el `PID` es el mismo, pero ya no corre bash.

---

## 4. Ciclo de vida y estados

```
          fork()
    ┌────────────────┐
    │                ▼
   [R] ───────► [S] ◄─────── señales / IO
    ▲   sched    │
    │            ▼
    │           [D]  (uninterruptible IO)
    │            │
    │   SIGCONT  ▼
    │           [T]  (parado por SIGSTOP/SIGTSTP)
    │
    └─ exit() ─► [Z] ──── wait() ──► reaped (desaparece)
```

Estados visibles en `ps` y en `/proc/[pid]/status`:

| Estado | Significado |
|--------|-------------|
| `R` | Running o runnable. Está en CPU o en la cola del scheduler. |
| `S` | Sleep interrumpible. Esperando un evento; se puede despertar con una señal. |
| `D` | Uninterruptible sleep. Típicamente IO al kernel (disco, NFS). Ni `SIGKILL` lo mueve. |
| `T` | Stopped. Fue parado con `SIGSTOP`/`SIGTSTP` o por un ptrace. Reanuda con `SIGCONT`. |
| `Z` | Zombie. Terminado pero su padre todavía no llamó `wait()`. Solo ocupa una entrada en la tabla de procesos. |
| `X` | Dead. Transición interna; casi nunca lo verás. |

Modificadores: `+` (foreground), `s` (session leader), `l` (multi-hilo), `<` (prioridad alta), `N` (nice bajo), `L` (páginas lockeadas).

---

## 5. Inspección del árbol de procesos

Herramientas estándar y por qué cada una:

```bash
ps -ef                      # BSD-style, snapshot plano, útil para grep
ps auxf                     # con árbol ASCII y uso CPU/MEM
ps -eo pid,ppid,pgid,sid,stat,comm   # exacto, scriptable
pstree -p -s $$             # árbol desde PID 1 hasta tu shell actual
top                         # interactivo, kernel-cercano
htop                        # top con árbol, colores, mouse (recomendado)
```

Un patrón sysadmin cotidiano:

```bash
# Buscar quién está consumiendo CPU
ps -eo pid,ppid,user,%cpu,%mem,cmd --sort=-%cpu | head
# ¿Y de qué subárbol cuelgan?
pstree -p -s <PID>
```

En `/proc`:

- `/proc/<pid>/status`  — resumen humano.
- `/proc/<pid>/stat`    — una línea densa (la que lee `ps`).
- `/proc/<pid>/cmdline` — argv real (separado por NULs).
- `/proc/<pid>/fd/`     — descriptores abiertos.
- `/proc/<pid>/environ` — entorno con el que arrancó.

---

## 6. Señales: el lenguaje universal

Una señal es un **evento asíncrono** entregado al proceso. El kernel marca al proceso como pendiente de esa señal; cuando el scheduler lo vuelve a planificar, el proceso ejecuta su **disposición**: default, ignorar, o un *handler* instalado.

### 6.1 Tabla de señales clave

| Señal | Nº (Linux x86_64) | Default | ¿Trap? | ¿Ignorable? | Semántica |
|-------|-------------------|---------|--------|-------------|-----------|
| `SIGHUP`  | 1  | Term | Sí | Sí | Terminal se cerró. Convención en demonios: *reload config*. |
| `SIGINT`  | 2  | Term | Sí | Sí | Interrupción desde teclado (`Ctrl-C`). |
| `SIGQUIT` | 3  | Core | Sí | Sí | `Ctrl-\`. Genera core dump. |
| `SIGKILL` | 9  | Term | **No** | **No** | Terminación forzosa por el kernel. No llega al proceso. |
| `SIGTERM` | 15 | Term | Sí | Sí | Petición cortés de terminar. **Default de `kill`.** |
| `SIGSTOP` | 19 | Stop | **No** | **No** | Parada forzosa. |
| `SIGTSTP` | 20 | Stop | Sí | Sí | Parada desde teclado (`Ctrl-Z`). |
| `SIGCONT` | 18 | Cont | Sí | Sí | Reanudar un proceso parado. |
| `SIGPIPE` | 13 | Term | Sí | Sí | Escribiste en un pipe sin lector. Explica muchos "exit 141". |
| `SIGCHLD` | 17 | Ignore | Sí | Sí | Un hijo cambió de estado (muy útil para reaping). |
| `SIGUSR1` | 10 | Term | Sí | Sí | A tu disposición (p.ej. `nginx -s reopen`). |
| `SIGUSR2` | 12 | Term | Sí | Sí | A tu disposición. |

Regla central a memorizar: **`SIGKILL` (9) y `SIGSTOP` (19) no se pueden atrapar ni ignorar.** Son los únicos garantizados.

Códigos de salida de shell cuando un proceso muere por señal `N`: `128 + N`. Por eso `exit 143` = killed by `SIGTERM`, `exit 137` = killed by `SIGKILL`, `exit 141` = `SIGPIPE`.

### 6.2 Entrega

```bash
kill <PID>                   # SIGTERM por defecto
kill -TERM <PID>             # explícito, recomendado
kill -9 <PID>                # SIGKILL — último recurso
kill -0 <PID>                # ¿existe el proceso? (no envía señal)
kill -HUP -- -<PGID>         # a todo un grupo (nota el guion antes del PGID)

pkill -TERM -f 'python.*worker'   # por patrón de cmdline
killall -QUIT nginx               # por nombre exacto del binario
```

**El guion extra en `kill -- -<PGID>`** es crucial: separa opciones de argumentos; sin él, `kill -123` intenta usar `-123` como opción.

---

## 7. Patrón: graceful shutdown

Un servicio bien escrito atrapa `SIGTERM` y hace: deja de aceptar trabajo nuevo, drena lo pendiente con un *deadline*, cierra recursos, y entonces sale. Esquema en bash:

```bash
#!/usr/bin/env bash
set -euo pipefail

shutdown=0
trap 'shutdown=1' TERM INT HUP

worker &
WORKER_PID=$!

# bucle principal supervisado
while (( shutdown == 0 )); do
  sleep 1
done

# fase de drenaje con grace period
kill -TERM "$WORKER_PID" 2>/dev/null || true
for _ in {1..10}; do
  kill -0 "$WORKER_PID" 2>/dev/null || break
  sleep 1
done

# escalada si no colaboró
if kill -0 "$WORKER_PID" 2>/dev/null; then
  kill -KILL "$WORKER_PID" || true
fi

wait "$WORKER_PID" 2>/dev/null || true
exit 0
```

Lo que hay que ver en ese patrón:

1. El `trap` marca una **bandera**; no mata al worker desde el handler. Los handlers deben ser cortos.
2. Hay un *grace period* fijo (10 s). Esa es la decisión arquitectónica.
3. La escalada a `KILL` solo ocurre si el proceso **no colaboró**.
4. `wait` al final cosecha al zombie.

Es el mismo contrato que ofrecen `systemd` (`TimeoutStopSec`) y Kubernetes (`terminationGracePeriodSeconds`): `TERM`, esperar, `KILL`.

---

## 8. Zombies y huérfanos

### Zombie

Un hijo que ya salió (`exit()` ejecutado) pero cuyo padre todavía no llamó `wait()`. El kernel conserva la entrada en la tabla de procesos para que el padre pueda leer el exit status. Si el padre nunca cosecha, el zombie se queda hasta que el padre muera: entonces `init`/`systemd` lo adopta y lo cosecha.

Demo (reproducible):

```bash
# Terminal A
bash -c 'bash -c "exit 7" & sleep 60; wait'
# Terminal B
ps -eo pid,ppid,stat,comm | grep -E 'Z|defunct'
# Verás algo como:
#   12345  12300  Z  bash <defunct>
```

Cuando el padre acabe el `sleep 60` y haga `wait`, el zombie desaparece.

**Un zombie no consume CPU ni memoria significativa**, solo una entrada en la tabla. El problema real es que **miles de zombies** indican un servicio que no cosecha hijos: típicamente falta un handler de `SIGCHLD` o un `wait` final.

### Huérfano

Un hijo cuyo padre murió antes que él. Es *reparentado*: su `PPID` pasa a `1` (o al *subreaper* más cercano). No es patológico; `nohup` depende de esto.

---

## 9. Control de trabajos del shell

El *job control* es una capa del shell encima de `PGID`/`SID`. Un *job* es un grupo de procesos lanzado por un único comando del shell (incluye todo el pipeline).

| Operación | Qué hace |
|-----------|----------|
| `cmd &` | Lanza `cmd` en background. Devuelve inmediatamente, imprime `[1] 12345`. |
| `jobs` | Lista los jobs del shell actual con su estado. |
| `fg %1` | Trae el job `%1` a foreground. |
| `bg %1` | Reanuda en background un job parado. |
| `Ctrl-Z` | Envía `SIGTSTP` al grupo foreground: lo *para*. |
| `Ctrl-C` | Envía `SIGINT` al grupo foreground. |
| `disown %1` | Quita el job de la tabla del shell. No morirá al salir del shell. |
| `nohup cmd &` | Ignora `SIGHUP` y redirige stdout/err a `nohup.out`. |
| `wait %1` | Espera a que termine el job. |

Interacción crucial: cuando sales del shell, por defecto se envía `SIGHUP` a los jobs de su sesión. Soluciones:

- `nohup cmd &` desde el principio.
- `disown` después de lanzar.
- `shopt -u huponexit` para desactivar la convención en bash.
- `setsid cmd` para arrancar al proceso en una **sesión nueva** sin terminal controladora.

---

## 10. Prioridad y recursos

### `nice` y `renice`

El valor *nice* va de `-20` (más prioridad) a `+19` (menos). Un usuario normal solo puede subirlo; `root` puede bajarlo.

```bash
nice -n 10 big-build.sh         # arranca con nice 10
renice -n 15 -p <PID>           # subir el nice de un proceso vivo
renice -n 5  -g <PGID>          # a todo el grupo
```

### `ionice`

Prioridad de IO (clases 1=realtime, 2=best-effort, 3=idle):

```bash
ionice -c3 rsync -a /src /dst   # idle: solo IO cuando nadie más la usa
```

### `ulimit`

Límites por proceso (los hereda al `exec`):

```bash
ulimit -a                       # ver todos los límites actuales
ulimit -n 4096                  # fd abiertos
ulimit -u 1024                  # procesos del usuario
ulimit -v 2000000               # memoria virtual en KB
ulimit -c unlimited             # tamaño de core dump
```

Para persistencia: `/etc/security/limits.conf` o la directiva `LimitNOFILE=` en una unit de `systemd`.

---

## 11. Desacople del terminal: `nohup` vs `setsid` vs `systemd`

Los tres resuelven el mismo problema de "no quiero que este proceso muera cuando cierre la terminal", pero no son equivalentes.

| Opción | ¿Hace? | ¿Para qué sirve? | Limitaciones |
|--------|--------|------------------|--------------|
| `nohup cmd &` | Ignora `SIGHUP`, redirige stdout/err a `nohup.out`. | Script interactivo que debe sobrevivir al logout. | No se reinicia si cae. No hay logs rotados. No hay dependencias. |
| `setsid cmd` | Arranca `cmd` en una sesión nueva, sin terminal controladora. | Procesos que deben estar realmente desacoplados (p.ej. mini-demonios ad hoc). | Igual que `nohup`: no supervisado, sin restart. |
| **systemd service** | Supervisado por `PID 1`. Reinicia, loguea en journald, aplica `LimitNOFILE`, `User=`, cgroup, dependencias. | Cualquier servicio con vocación de permanencia. | Más setup. Requiere privilegios para unidades de sistema (hay *user units*). |

Regla operativa:

- Prueba de 10 min → `nohup`.
- Script interno sin SLA pero que vive días → `setsid` + log file explícito.
- Algo que el equipo depende de que esté arriba → **unit de systemd**. Fin de la discusión.

---

## 12. Preguntas de evaluación

Respóndelas sin consultar la lección.

1. ¿Qué diferencia hay entre `SIGTERM`, `SIGKILL` y `SIGINT`? ¿Cuál usarías primero y por qué?
2. ¿Qué significa estado `D` y por qué `kill -9` no lo saca de ahí?
3. ¿Qué objetos del proceso cambian con `exec` y cuáles sobreviven?
4. Describe un escenario donde `SIGPIPE` cause un fallo silencioso y cómo lo diagnosticarías.
5. ¿Qué hace exactamente `nohup` que no hace `&` por sí solo?
6. ¿Cuándo elegirías `setsid` en vez de una unit de `systemd`?
7. ¿Por qué el handler de `trap` debe limitarse a mover una bandera y no hacer el trabajo pesado?
8. Explica qué pasa con un zombie si nunca llamas `wait` y luego el padre muere.
9. ¿Qué diferencia operativa hay entre `nice` y `ionice`?
10. ¿Por qué `kill -HUP -- -1234` requiere el `--` y el guion antes del `1234`?
