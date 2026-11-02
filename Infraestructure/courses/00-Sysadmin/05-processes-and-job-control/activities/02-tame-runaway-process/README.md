# Actividad 02 — Domar un proceso *runaway*

## Tipo

Debug · 45 min · nivel intermedio.

## Escenario

Un compañero dejó corriendo `starter/runaway.sh`. El proceso:

- Ignora `SIGTERM` (lo atrapa y lo descarta).
- Consume CPU en un bucle apretado.
- Si lo matas con `SIGKILL` **sin más**, el log queda a medias y se pierde el estado parcial.

Tu misión como SRE de guardia es **escalarlo correctamente**, no empezar por `kill -9`.

Objetivo operativo: terminarlo con el **mínimo daño colateral** siguiendo el patrón `TERM → grace → KILL`, y dejar evidencia en un log para el post-mortem.

## Objetivo pedagógico

- Localizar un proceso por nombre/patrón.
- Enviar `SIGTERM` y comprobar si colaboró.
- Esperar un *grace period* explícito.
- Escalar a `SIGKILL` solo si fue necesario.
- Verificar al final que:
  - El proceso ya no existe.
  - No quedó un zombie.
  - El exit code refleja la señal real que lo mató (si fue `KILL`, exit `137`).

## Prerrequisitos

- `theory/lesson.md` secciones 6 y 7 leídas.
- `ps`, `pkill`, `kill`, `pgrep` disponibles.

## Pasos

1. Lanza el proceso *runaway* en background:
   ```bash
   bash activities/02-tame-runaway-process/starter/runaway.sh \
     --log /tmp/runaway.log &
   disown
   ```
2. Confírmalo vivo:
   ```bash
   pgrep -af runaway.sh
   ```
3. Pídele que se vaya cortésmente (**no uses `-9` todavía**):
   ```bash
   pkill -TERM -f runaway.sh
   ```
4. Observa: ¿sigue vivo? Debería, porque atrapa e ignora `TERM`. Mira `/tmp/runaway.log`.
5. Da un *grace period* de 5 s. Vuelve a comprobar.
6. Escala a `KILL`:
   ```bash
   pkill -KILL -f runaway.sh
   ```
7. Verifica:
   - `pgrep -af runaway.sh` no devuelve nada.
   - `ps -eo pid,ppid,stat,comm | grep -i defunct` no muestra zombies de este script.
   - `/tmp/runaway.log` contiene el intento de `TERM` ignorado y la línea final `killed by signal`.

Opcional: automatiza el escalado en un pequeño script `tame.sh` tuyo y úsalo para repetir la operación.

## Validación

```bash
bash tests/validate.sh
```

El validador:

- Arranca `runaway.sh`.
- Envía `TERM`, espera 2 s.
- Comprueba que **sigue vivo** (prueba de que el proceso ignora `TERM`).
- Envía `KILL`.
- Comprueba que ya no está.
- Comprueba que no hay zombies con ese nombre.
- Comprueba que el log registró ambos eventos.

## Pistas

- `pkill -0 -f runaway.sh` devuelve 0 si al menos un proceso coincide (sin enviar nada).
- `kill -0 <pid>` lo mismo pero por PID.
- Un script bash puede atrapar `TERM` pero **no** `KILL`. Esa es la razón por la que `KILL` existe.
- No uses `killall -9` como primer recurso en un host compartido: si hay múltiples instancias, matas a todos a la vez y pierdes información diagnóstica.

## Solución

Ver `solution/README.md` para el guion correcto y la explicación de cada paso.
