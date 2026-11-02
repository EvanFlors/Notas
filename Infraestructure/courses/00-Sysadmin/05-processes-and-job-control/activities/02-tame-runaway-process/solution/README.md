# Solución — Domar el runaway

## Guion correcto

```bash
# 1. Localizar
pgrep -af runaway.sh

# 2. Pedir cortesia
pkill -TERM -f runaway.sh
# El log mostrara: "received SIGTERM — IGNORING". El proceso sigue vivo.

# 3. Grace period explicito (5s)
for _ in {1..5}; do
  pkill -0 -f runaway.sh || break
  sleep 1
done

# 4. Si sigue, escalar a KILL
if pkill -0 -f runaway.sh; then
  pkill -KILL -f runaway.sh
fi

# 5. Verificar
pgrep -af runaway.sh                              # vacio
ps -eo pid,ppid,stat,comm | grep -E 'Z|defunct'   # sin zombies del script
tail /tmp/runaway.log                             # evidencia del intento TERM
```

## Por qué este orden

- **TERM primero** porque es la única forma de dar al proceso la oportunidad de drenar trabajo, cerrar sockets y volcar buffers. En un servicio real, saltarse este paso corta transacciones a la mitad.
- **Grace period explícito** porque "5 segundos" es una decisión tuya, no del shell. Documenta tus números: en producción los SLOs lo definen.
- **KILL último** porque es la única señal que el kernel garantiza. Pero perder el `TERM` previo = perder la posibilidad de un apagado limpio.

## Patrón reutilizable

```bash
graceful_kill() {
  local pattern="$1" grace="${2:-10}"
  pkill -TERM -f "$pattern" || return 0
  for ((i=0; i<grace; i++)); do
    pkill -0 -f "$pattern" || return 0
    sleep 1
  done
  pkill -KILL -f "$pattern" || true
}
```

Es exactamente lo que hace `systemctl stop <unit>` con `TimeoutStopSec`, y lo que hace Kubernetes con `terminationGracePeriodSeconds`.

## Antipatrones a evitar

- `killall -9 bash`: mata **todos** los bash del host. Nunca.
- `pkill -9 -f runaway`: pierdes la señal de cortesía y la evidencia en el log.
- Loops de `kill` sin `kill -0` antes: envías señales a PIDs que ya no existen y, peor, puedes acertar a un PID reciclado.
