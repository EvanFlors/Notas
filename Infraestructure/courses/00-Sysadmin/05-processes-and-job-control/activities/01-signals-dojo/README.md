# Actividad 01 — Signals dojo

## Tipo

Guided-lab · 45 min · nivel intermedio.

## Objetivo

Instalar los `trap`s correctos sobre un script que recibirá distintas señales, y validar que la respuesta sea la esperada en cada caso. Trabajarás sobre un script esqueleto (`starter/trap-me.sh`) que **no** maneja señales todavía.

Al terminar deberías ser capaz de:

- Instalar un handler único para varias señales con una sola línea de `trap`.
- Diferenciar un handler que termina del que *reload*ea config.
- Dejar `EXIT` como *always-run cleanup*.
- Saber que `KILL` y `STOP` nunca entran al handler.

## Prerrequisitos

- Haber leído `theory/lesson.md` secciones 6, 7 y 9.
- Haber ejecutado `examples/01-fork-exec-wait/`.

## Escenario

Vas a convertir `starter/trap-me.sh` en un *mini-daemon* que:

1. En `SIGTERM`, `SIGINT`, `SIGHUP` ejecute un *graceful shutdown* (imprime `SHUTDOWN: <SIGNAL>` y sale con código 0).
2. En `SIGUSR1` recargue config: imprime `RELOAD: config` y **sigue corriendo**.
3. En `SIGUSR2` imprima el estado interno (variable `TICKS`) sin salir.
4. En `EXIT` (del propio shell) imprima `CLEANUP: tempdir=<ruta>` **siempre**, haya salida limpia o por señal.
5. Mientras corre, imprime `tick N` cada segundo e incrementa `TICKS`.

El script debe aceptar un argumento opcional `--pid-file RUTA` donde escriba su PID, útil para la validación.

## Pasos sugeridos

1. Copia `starter/trap-me.sh` a `/tmp/trap-me.sh` y hazlo ejecutable.
2. Añade `trap` para `TERM INT HUP` que llame a una función `graceful_shutdown`.
3. Añade `trap` para `USR1` → `reload_config`.
4. Añade `trap` para `USR2` → `print_status`.
5. Añade `trap` para `EXIT` → `cleanup`.
6. Prueba manualmente:
   ```bash
   /tmp/trap-me.sh --pid-file /tmp/trap-me.pid &
   PID=$(cat /tmp/trap-me.pid)
   kill -USR1 "$PID"   # debe imprimir RELOAD: config y seguir
   kill -USR2 "$PID"   # debe imprimir STATUS: ticks=N
   kill -TERM "$PID"   # debe imprimir SHUTDOWN: TERM y luego CLEANUP: ...
   ```
7. Compara con `solution/trap-me.sh` solo si te atascas.

## Validación

```bash
bash tests/validate.sh /tmp/trap-me.sh
```

El test lanza el script, le envía las señales en orden y comprueba la salida y el exit code.

## Entregable

- `/tmp/trap-me.sh` con tus `trap`s instalados.
- Un `exit 0` del validador.

## Pistas (sin spoilers)

- `trap FUNC SIG1 SIG2 SIG3` instala el mismo handler para varias señales.
- Para el *graceful shutdown*, usa `exit 0` dentro del handler, pero recuerda que `trap - TERM INT HUP` dentro del handler evita re-entradas si llega una segunda señal.
- El handler de `EXIT` corre **siempre**, incluso al salir por señal, porque bash sintetiza `EXIT` al final.
- No uses `sleep 60` dentro del handler. Los handlers deben ser rápidos.
