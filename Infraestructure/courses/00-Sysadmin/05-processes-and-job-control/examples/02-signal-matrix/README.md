# Ejemplo 02 — Matriz de señales: qué se puede atrapar, ignorar o no

## Concepto que demuestra

No todas las señales son iguales. Algunas se pueden interceptar con `trap` (y así implementar *graceful shutdown*), otras se pueden ignorar, y dos (`SIGKILL`, `SIGSTOP`) son **inatajables** por diseño del kernel.

## Matriz

| Señal     | Nº | Default | ¿Trap? | ¿Ignorable? | Uso típico |
|-----------|----|---------|--------|-------------|------------|
| `SIGHUP`  | 1  | Term    | Sí     | Sí          | *reload* de configuración en demonios. |
| `SIGINT`  | 2  | Term    | Sí     | Sí          | `Ctrl-C`. Cancelación cortés desde teclado. |
| `SIGQUIT` | 3  | Core    | Sí     | Sí          | `Ctrl-\`. Core dump para post-mortem. |
| `SIGILL`  | 4  | Core    | Sí     | Sí          | Instrucción ilegal (bug del binario). |
| `SIGABRT` | 6  | Core    | Sí     | Sí          | `abort(3)`. Falla fatal interna. |
| `SIGFPE`  | 8  | Core    | Sí     | Sí          | Error aritmético (p.ej. `/0` en C). |
| `SIGKILL` | 9  | Term    | **No** | **No**      | Terminación forzosa. Último recurso. |
| `SIGUSR1` | 10 | Term    | Sí     | Sí          | A disposición de la app (p.ej. rotar logs). |
| `SIGSEGV` | 11 | Core    | Sí     | Sí          | Acceso inválido a memoria. |
| `SIGUSR2` | 12 | Term    | Sí     | Sí          | A disposición de la app. |
| `SIGPIPE` | 13 | Term    | Sí     | Sí          | Escribir en pipe sin lector. |
| `SIGALRM` | 14 | Term    | Sí     | Sí          | Temporizador vencido (`alarm(2)`). |
| `SIGTERM` | 15 | Term    | Sí     | Sí          | **Default de `kill`.** Petición cortés de terminar. |
| `SIGCHLD` | 17 | Ignore  | Sí     | Sí          | Un hijo cambió de estado. |
| `SIGCONT` | 18 | Cont    | Sí     | Sí          | Reanudar proceso parado. |
| `SIGSTOP` | 19 | Stop    | **No** | **No**      | Parada forzosa. |
| `SIGTSTP` | 20 | Stop    | Sí     | Sí          | `Ctrl-Z`. Parada desde teclado. |
| `SIGTTIN` | 21 | Stop    | Sí     | Sí          | Proceso background intenta leer de la TTY. |
| `SIGTTOU` | 22 | Stop    | Sí     | Sí          | Proceso background intenta escribir en la TTY. |

Fuente autoritativa: `man 7 signal` (sección `Standard signals`). Los números dependen de la arquitectura; los de la tabla son Linux x86_64.

## Verificación rápida

Enumera lo que tu sistema reconoce:

```bash
kill -l                      # lista todos los nombres
kill -l 9                    # nombre a partir de numero
kill -l KILL                 # numero a partir de nombre
```

Comprueba empíricamente que `KILL` y `STOP` no se pueden atrapar:

```bash
# Lanzar un sleep con trap "intentando" atrapar KILL
bash -c 'trap "echo atrapado" KILL 2>&1 || true; sleep 5' &
PID=$!
sleep 1
kill -KILL "$PID"
wait "$PID" 2>/dev/null || true
echo "exit: $?"
# bash avisara: "trap: SIGKILL: invalid signal specification"
# el sleep muere sin imprimir "atrapado".
```

## Códigos de salida por señal

Convención del shell: si un proceso muere por señal `N`, su exit code es `128 + N`.

| Exit | Causa típica |
|------|--------------|
| 130  | `SIGINT`  (`Ctrl-C`) |
| 137  | `SIGKILL` |
| 139  | `SIGSEGV` |
| 141  | `SIGPIPE` |
| 143  | `SIGTERM` |

## Interpretación operativa

- Si tu script falla con `137` tras cambios en el host → probablemente **OOM killer**: `dmesg | grep -i 'killed process'`.
- Si falla con `141` → el consumidor del pipe cerró antes (`head`, por ejemplo, es un sospechoso habitual).
- Si falla con `143` → alguien le mandó `TERM`, muy típico en Kubernetes al escalar/rolling.

## Relación con escenarios reales

- `nginx -s reload` envía `SIGHUP` al master.
- `logrotate` suele enviar `SIGUSR1` para que el daemon reabra el archivo de log.
- `systemd` envía `SIGTERM`, espera `TimeoutStopSec`, y escala a `SIGKILL`. Mismo patrón que el ejemplo 01.
