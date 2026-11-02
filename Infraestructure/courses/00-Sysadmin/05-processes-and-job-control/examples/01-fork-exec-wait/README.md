# Ejemplo 01 — fork / exec / wait con `trap` y hijo en background

## Concepto que demuestra

Cómo bash hace `fork` + `exec` para lanzar un hijo, cómo `wait` cosecha su exit status, y cómo un `trap` del padre convierte una señal del terminal en un *graceful shutdown*.

## Contexto

Es el prototipo mínimo del patrón de *supervisor + worker* que usarás en scripts de arranque, batch jobs y runners de CI.

## Objetivo

Al terminar podrás responder:

- ¿Qué `PID` tiene el hijo y cómo se relaciona con `$$`?
- ¿Qué pasa si no haces `wait`?
- ¿Qué secuencia de señales entrega el shell cuando pulsas `Ctrl-C` sobre el padre?

## Prerrequisitos

- Bash ≥ 4.
- `ps`, `kill` disponibles (vienen con cualquier distro Linux o macOS).
- Un terminal interactivo (para `Ctrl-C`).

## Ejecución

```bash
# 1. Lanzar el demo en una terminal
bash files/demo.sh

# 2. En OTRA terminal, mira el árbol
pstree -p "$(pgrep -f demo.sh | head -1)"

# 3. Prueba cada escenario (uno por ejecución):
#    a) deja que termine solo (10 iteraciones del worker).
#    b) pulsa Ctrl-C en el padre → verás graceful shutdown.
#    c) desde otra terminal: kill -TERM <PID_padre>
#    d) desde otra terminal: kill -KILL <PID_padre>
#       (observa que el worker queda huérfano y lo adopta PID 1)
```

## Resultado esperado

- El padre imprime `supervisor PID=X worker PID=Y`.
- El worker imprime `tick N` cada segundo durante 10 s.
- Con `Ctrl-C`: el padre dice `received signal, draining...`, da 5 s, luego `exit`.
- Con `kill -9` al padre: el worker se vuelve huérfano, `PPID` cambia a `1`.

## Interpretación

- `demo.sh` hace `fork` cuando ejecuta `( worker ) &`. El shell devuelve inmediatamente el `PID` del hijo en `$!`.
- El `trap` del padre marca una bandera. El bucle principal la mira cada segundo. Cuando se dispara, envía `TERM` al worker y espera.
- Si el padre muere sin `wait`, no genera zombie en ese momento: lo adopta `init` (PID 1) y lo cosecha.
- `set -euo pipefail` NO desactiva al `trap`; ambos cooperan. El `|| true` tras `kill` evita que la señal "exitosa" pero sin pid vivo rompa `-e`.

## Errores frecuentes

- **Dejar el handler haciendo trabajo pesado**: una segunda señal durante el handler puede dejar al proceso inconsistente. El handler solo cambia la bandera.
- **Olvidar `wait`**: el hijo queda zombie hasta que el padre muera. En un supervisor de larga duración, esto se acumula.
- **No usar `|| true` tras `kill`**: con `set -e`, si el worker ya murió, `kill` falla con `No such process` y rompe el script.

## Relación con escenarios reales

- Scripts de *entrypoint* en contenedores Docker (PID 1 debe cosechar hijos y reenviar señales).
- Jobs de CI que lanzan sub-procesos y deben terminar limpio al pulsar "cancel".
- Supervisores ad hoc antes de pasar a `systemd`.

## Limpieza

Nada que limpiar. El demo no escribe a disco.
