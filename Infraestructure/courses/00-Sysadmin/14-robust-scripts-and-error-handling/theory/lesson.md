# Lección sys-14 — Scripts robustos y manejo de errores

> "Un script no es robusto porque funcione cuando todo va bien. Es robusto porque **falla rápido, grita claro, y no deja basura** cuando algo va mal."

## 0. Contrato de este módulo

Al terminar deberías poder leer un script ajeno y, en < 60 segundos, decir:

- ¿Tiene `set -euo pipefail`? Si no, ¿por qué?
- ¿Hay `trap` de cleanup? ¿Qué cubre: solo `EXIT` o también `INT`/`TERM`?
- ¿Es idempotente? ¿Sobrevive a doble invocación?
- ¿Separa `stdout` (producto) de `stderr` (observación)?
- ¿Devuelve exit codes semánticos o solo `0`/`1`?

Y, si no cumple, poder arreglarlo sin romper otra cosa.

---

## 1. La trinidad: `set -euo pipefail`

Un script de bash arranca, por defecto, en el modo *best effort*: si un comando falla, el shell lo imprime y **continúa**. Para producción esto es inaceptable. Activamos tres modos:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

### 1.1 `set -e` (alias `set -o errexit`)

Si un comando "simple" devuelve exit code distinto de 0, el shell aborta.

```bash
set -e
cp fuente destino        # si falla, el script muere aquí
echo "no llego si cp falló"
```

Suena simple. **No lo es.** Ver §2.

### 1.2 `set -u` (alias `set -o nounset`)

Expandir una variable no definida es un error.

```bash
set -u
echo "Hola, $NOMBRE"     # si NOMBRE no está definida, aborta
```

Captura el bug clásico:

```bash
rm -rf "$PREFIX/cache"   # si PREFIX está vacío → rm -rf /cache
```

Con `-u` falla antes de ejecutar `rm`. Sin él, borras `/cache` del sistema.

Caveat útil: si quieres aceptar "undefined" como vacío en un sitio concreto, usa `${VAR:-}`:

```bash
echo "${DEBUG:-}"        # imprime vacío sin abortar
```

### 1.3 `set -o pipefail`

Por defecto, el exit code de un pipeline es el del **último** comando. Con `pipefail`, es el del **primer** comando que falle (o 0 si ninguno falla).

```bash
set -o pipefail
curl -sSf https://api.example.com/data | jq '.'
# sin pipefail: si curl falla pero jq procesa el string vacío, exit=0 → "éxito" silencioso
# con pipefail: exit=curl's exit → se detecta
```

### 1.4 `IFS=$'\n\t'`

El `IFS` por defecto es `espacio-tab-newline`, lo que hace que un `for f in $(ls)` se rompa con archivos con espacios. Restringirlo a `newline-tab` evita el split por espacios en expansiones no citadas y hace más seguros los iteradores sobre nombres de archivo.

Alternativa (y preferible siempre que se pueda): citar y usar arrays — `IFS` no te salva de todo.

### 1.5 `set -x` (debug on demand)

Imprime cada comando antes de ejecutarlo, prefijado por `+`. No se activa en producción; se activa cuando debugueas:

```bash
[[ "${DEBUG:-}" == "1" ]] && set -x
```

Patrón útil: `DEBUG=1 ./script.sh` para hacer trace sin tocar el código.

---

## 2. Lo que `set -e` **NO** cubre (gotchas)

Esta es la razón por la que BashFAQ 105 existe. `-e` **no aborta** cuando el comando cuyo exit code sería no cero aparece en estos contextos:

| # | Contexto | Comportamiento | Ejemplo |
|---|----------|----------------|---------|
| 1 | Condición de `if` / `elif` / `while` / `until` | El exit code se consume como booleano. No aborta. | `if grep x f; then …` |
| 2 | Operando de `&&` o `\|\|` (excepto el *último* de la cadena) | Se consume como control de flujo. | `cmd1 && cmd2`  → si `cmd1` falla, no aborta, va a lo que haya a la derecha. |
| 3 | Pipeline sin `pipefail` | Solo cuenta el exit del último comando. | `false \| true` → exit 0, no aborta. |
| 4 | Función invocada dentro de condicional | La función hereda la "inmunidad" del contexto. | `if mi_func; then …` — `-e` dentro de `mi_func` no la mata. |
| 5 | Subshell `(…)` o `$(…)` | El exit del subshell sí se evalúa, pero comandos **dentro** de un subshell inline en una asignación con `local` o `declare` se pierden. | `local out=$(cmd_que_falla)` → exit code del subshell se pierde porque `local` siempre devuelve 0 (ver `SC2155`). |
| 6 | `command \|\| true` explícito | Patrón intencional para "ignorar fallo". | `rm -f cache \|\| true` |
| 7 | Expansión de `$(…)` dentro de un string | El fallo se traga. | `echo "resultado: $(cmd_que_falla)"` |

### 2.1 El caso traicionero: `local x=$(...)`

```bash
set -e
mi_func() {
    local resultado=$(cmd_que_falla)   # ¡no aborta!
    echo "resultado: $resultado"
}
```

`local` es un comando por derecho propio y **su** exit code es 0 (porque la declaración tuvo éxito). El exit code de `cmd_que_falla` se descarta. Solución: separar.

```bash
mi_func() {
    local resultado
    resultado=$(cmd_que_falla)         # ahora -e aborta si falla
    echo "resultado: $resultado"
}
```

Shellcheck grita `SC2155` por exactamente esto.

### 2.2 Chequeo explícito cuando `-e` no basta

Hay casos legítimos donde quieres control fino:

```bash
if ! cmd_crítico; then
    log_error "cmd_crítico falló; abortando con 70"
    exit 70   # EX_SOFTWARE
fi
```

o:

```bash
cmd_que_quizás_falla || status=$?
if (( ${status:-0} != 0 )); then
    …
fi
```

Moraleja: `-e` es un cinturón de seguridad por defecto, **no** una garantía de robustez.

---

## 3. `trap`: cleanup y señales

### 3.1 Modelo mental

`trap 'CMD' SIG` registra un handler: cuando el shell recibe `SIG`, ejecuta `CMD`. Las señales que importan en scripts:

| Señal | Cuándo llega | Qué hacer típicamente |
|-------|--------------|------------------------|
| `EXIT` | Siempre que el shell termina (sea por éxito, error, señal, o `exit`). | Cleanup (borrar tmpdir, soltar lock, cerrar fds). |
| `ERR` | Cuando un comando falla y `-e` dispara. | Logging con contexto (archivo, línea, exit code, comando). |
| `INT` (2) | `Ctrl-C` desde la terminal. | Salida limpia; opcionalmente propagar `kill -INT $$` tras limpiar. |
| `TERM` (15) | Terminación "amable" (p. ej. `systemctl stop`, `kill` sin número). | Igual que `INT`: cerrar, soltar, salir con `130` o `143` apropiados. |
| `HUP` (1) | Terminal cerrada; recarga de config en daemons. | Depende del rol. |

### 3.2 Patrón: cleanup incondicional en `EXIT`

```bash
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
```

Clave: `EXIT` dispara en **todos** los caminos de salida, así que el `rm -rf` corre incluso si:

- Un comando falla con `-e`.
- El usuario mata con `Ctrl-C`.
- El script hace `exit 70` explícito.

Alternativa frágil: `rm -rf "$tmpdir"` al final del script. No corre si el script muere a mitad.

### 3.3 Patrón: handler `ERR` con contexto (línea + comando)

```bash
on_err() {
    local exit_code=$?
    local line=${BASH_LINENO[0]}
    local cmd=${BASH_COMMAND}
    printf '[ERROR] línea %s: "%s" (exit %s)\n' "$line" "$cmd" "$exit_code" >&2
}
trap on_err ERR
```

Útil para que el log diga "falló en línea 47 el comando `curl -sSf …` con exit 22", no solo "falló".

### 3.4 Patrón: múltiples traps acumulativos

`trap … EXIT` reemplaza el anterior. Si necesitas registrar varios cleanups, acumula:

```bash
cleanup_cmds=()
on_exit() { for c in "${cleanup_cmds[@]}"; do eval "$c"; done; }
trap on_exit EXIT

tmpdir=$(mktemp -d);          cleanup_cmds+=("rm -rf '$tmpdir'")
lockfd=9; exec 9>"$LOCK";     cleanup_cmds+=("exec 9>&-")
```

### 3.5 Propagar la señal correctamente

Si capturaste `INT` para limpiar, el proceso padre no sabe que lo mataste con `Ctrl-C`. Convención Unix: salir con `128 + nº_señal` (`130` para `INT`, `143` para `TERM`).

```bash
on_int() {
    rm -rf "$tmpdir"
    trap - INT          # desarma el handler para no re-entrar
    kill -INT $$        # re-emite SIGINT a este mismo proceso
}
trap on_int INT
```

---

## 4. Idempotencia

Un script es **idempotente** si ejecutarlo *N* veces produce el mismo estado final que ejecutarlo 1 vez.

### Reglas prácticas

- **Crear sin fallar si ya existe:** `mkdir -p dir`, `ln -sfn target link`, `install -D -m 0644 src dst`.
- **Borrar sin fallar si no existe:** `rm -f file`, `rm -rf dir`.
- **Chequear antes de mutar** cuando no haya flag `-p`/`-f`: `[[ -L /etc/foo ]] || ln -s …`.
- **Operaciones de red:** usar `curl -fL --retry 3 --retry-delay 2` o descargar a `.part` y mover atómicamente (`mv foo.part foo`).
- **Transacciones a sistemas con estado** (DB, APIs): preferir "upsert" sobre "insert"; usar claves naturales; versionar schemas.

Idempotencia **no** es lo mismo que **exclusión mutua** (§5). Idempotencia dice "no hace daño volver a correrlo"; exclusión mutua dice "solo uno a la vez". Puedes necesitar ambas.

---

## 5. Lock files: `flock -n`

Problema: dos invocaciones concurrentes del mismo script (p. ej. un cron que se retrasa y dispara dos veces). Soluciones malas y la buena:

### 5.1 Mal patrón: test-and-create

```bash
# ANTIPATRÓN — carrera entre test y touch
if [[ ! -f /var/run/myjob.lock ]]; then
    touch /var/run/myjob.lock
    # … trabajo …
    rm -f /var/run/myjob.lock
fi
```

Entre el `[[ -f ]]` y el `touch` hay una ventana de carrera. Dos procesos pueden pasar el test ambos.

### 5.2 Patrón OK: `mkdir` como primitiva atómica

`mkdir` es atómico: o crea el directorio o falla con `EEXIST`.

```bash
LOCK=/var/run/myjob.lock.d
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "otra instancia corriendo; saliendo." >&2
    exit 75    # EX_TEMPFAIL
fi
trap 'rmdir "$LOCK"' EXIT
```

Problema: si el proceso muere con `SIGKILL` (9), el `trap` no corre y el lock queda "stale".

### 5.3 Patrón bueno: `flock -n`

`flock(2)` es un lock advisory del kernel asociado a un file descriptor. Cuando el proceso muere (por cualquier razón, incluyendo `SIGKILL`), el kernel libera el lock. Sin cleanup manual.

```bash
LOCK=/var/run/myjob.lock
exec 9>"$LOCK"              # abrir fd 9 apuntando al archivo
if ! flock -n 9; then
    echo "otra instancia corriendo; saliendo." >&2
    exit 75                 # EX_TEMPFAIL
fi
# … desde aquí tenemos exclusividad; el lock se libera al cerrar fd 9 ...
# ... que pasa automáticamente al terminar el shell.
```

Flags útiles:

- `-n` / `--nonblock`: fallar inmediatamente si no se puede adquirir (en vez de esperar).
- `-w SEG`: esperar hasta SEG segundos antes de rendirse.
- `-s`: lock compartido (lectura); por defecto es exclusivo.

Variante "self-wrap" (idiom clásico de un solo archivo):

```bash
#!/usr/bin/env bash
set -euo pipefail
[ "${FLOCKER:-}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@"
# … script real …
```

El propio script re-ejecuta `flock` sobre sí mismo. Elegante, confuso al primer encuentro.

---

## 6. Logging: canales y niveles

### 6.1 stdout vs stderr

- **stdout:** el *producto* del script (datos pensados para pipearse).
- **stderr:** *observación* del script (lo que un humano o un sistema de monitoreo lee para saber qué pasó).

Ejemplo correcto:

```bash
list_users() {
    log_info "consultando /etc/passwd"       # a stderr
    awk -F: '{print $1}' /etc/passwd         # a stdout
}
list_users | sort > users.txt                # el pipe recibe solo nombres
```

Si logs y datos se mezclan en stdout, `| sort` ordena el log junto a los datos. Error clásico de scripts "nuevos".

### 6.2 Librería mínima de logging

```bash
_log() {
    local level=$1; shift
    printf '[%s] %s %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$level" "$*" >&2
}
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }
```

Opcional: silenciar `INFO` por nivel configurable:

```bash
LOG_LEVEL=${LOG_LEVEL:-INFO}  # DEBUG < INFO < WARN < ERROR
# … implementación con un `case` que filtra …
```

Para scripts que corren bajo `systemd`, basta escribir a stderr y el `journal` captura con la unidad; no necesitas `logger` adicional.

---

## 7. Exit codes semánticos

El exit code es la **API primaria** de un script frente a su orquestador (cron, systemd, Make, un supervisor). Un `exit 1` para todo es renunciar a comunicar.

### 7.1 Convenciones base

| Code | Significado práctico |
|------|----------------------|
| `0` | Éxito. |
| `1` | Error genérico (último recurso). |
| `2` | Uso incorrecto (argumentos malos). Convención común en herramientas (`getopt`, muchos CLIs). |
| `126` | Comando encontrado pero no ejecutable (permisos). |
| `127` | Comando no encontrado. |
| `128+N` | Terminado por señal N (`130` = `128+2`/INT, `143` = `128+15`/TERM). |

### 7.2 `sysexits.h` (BSD, rango 64–78)

Convención antigua pero sólida para distinguir *tipos* de fallo:

| Code | Nombre | Cuándo usarlo |
|------|--------|---------------|
| 64 | EX_USAGE | Línea de comandos inválida. |
| 65 | EX_DATAERR | Datos de entrada inválidos (archivo malformado). |
| 66 | EX_NOINPUT | Falta input (archivo no existe, no legible). |
| 67 | EX_NOUSER | Usuario no existe (contexto `useradd`, mail). |
| 68 | EX_NOHOST | Host no existe. |
| 69 | EX_UNAVAILABLE | Un servicio del que dependemos no está disponible. |
| 70 | EX_SOFTWARE | Error interno del propio script (bug). |
| 71 | EX_OSERR | Error del sistema (fork, memoria). |
| 72 | EX_OSFILE | Un archivo de sistema está mal. |
| 73 | EX_CANTCREAT | No se pudo crear archivo de salida. |
| 74 | EX_IOERR | Error de I/O durante operación. |
| 75 | EX_TEMPFAIL | Fallo temporal; reintentar luego tiene sentido. ★ útil para "ya corre otra instancia". |
| 76 | EX_PROTOCOL | Error de protocolo (respuesta no esperada de un peer). |
| 77 | EX_NOPERM | Permiso denegado. |
| 78 | EX_CONFIG | Error de configuración. |

Un orquestador puede entonces decidir: `75` → reintentar en 5 min; `78` → avisar al operador, no reintentar; `70` → levantar incident.

Patrón al final del script: constantes.

```bash
readonly EX_USAGE=64
readonly EX_TEMPFAIL=75
readonly EX_CONFIG=78
```

---

## 8. shellcheck como gate de calidad

### 8.1 Qué es

Linter estático para shell: parsea el script y marca errores reales y pitfalls comunes. Cero dependencias en runtime.

```bash
shellcheck -S warning mi_script.sh
```

Niveles: `error`, `warning`, `info`, `style`. Para scripts nuevos, `warning` es el mínimo saludable; para scripts críticos, `style`.

### 8.2 Códigos a reconocer de memoria

| Código | Problema |
|--------|----------|
| `SC2086` | Expansión sin comillas; puede splittearse por `IFS` o expandirse como glob. |
| `SC2155` | `local x=$(cmd)` traga el exit code de `cmd`. |
| `SC2164` | `cd foo` sin `|| exit`; si falla sigues en la carpeta mala. |
| `SC2181` | Usar `$?` en vez de chequear el comando directamente. |
| `SC1091` | `source` de archivo que shellcheck no puede ver (silenciable con `# shellcheck source=…`). |
| `SC2034` | Variable asignada y nunca usada. |
| `SC2046` | Expansión sin comillas en `$(…)`. |

### 8.3 Silenciar con criterio

```bash
# shellcheck disable=SC2016  # queremos literales de $VAR en este awk
awk '{print $VAR}' file
```

**Regla:** cada `disable` lleva un comentario explicando por qué. Sin justificación, el `disable` es deuda.

### 8.4 Integración

- Pre-commit hook: `shellcheck` sobre `*.sh` modificados.
- CI: `find . -name '*.sh' -print0 | xargs -0 shellcheck -S warning`.
- Editor: plugins para VSCode / vim / emacs.

---

## 9. Plantilla de referencia (unificando todo)

```bash
#!/usr/bin/env bash
# job.sh — descripción corta.
# Uso: job.sh [--flag …] [arg …]
# Exit: 0 ok | 64 usage | 70 bug | 75 ya hay otra instancia | 78 config
set -euo pipefail
IFS=$'\n\t'

# ---- constantes ----
readonly SCRIPT_NAME=${0##*/}
readonly LOCK_FILE="/var/lock/${SCRIPT_NAME}.lock"
readonly EX_USAGE=64
readonly EX_SOFTWARE=70
readonly EX_TEMPFAIL=75
readonly EX_CONFIG=78

# ---- logging ----
_log() { printf '[%s] %s %s\n' "$(date +'%FT%T%z')" "$1" "${*:2}" >&2; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# ---- cleanup ----
tmpdir=""
cleanup() {
    local rc=$?
    [[ -n "$tmpdir" && -d "$tmpdir" ]] && rm -rf "$tmpdir"
    exit "$rc"
}
on_err() {
    local rc=$? line=${BASH_LINENO[0]} cmd=${BASH_COMMAND}
    log_error "línea $line: \"$cmd\" (exit $rc)"
}
trap cleanup EXIT
trap on_err  ERR
trap 'log_warn "SIGINT"; exit 130' INT
trap 'log_warn "SIGTERM"; exit 143' TERM

# ---- lock ----
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log_warn "otra instancia corriendo; saliendo."
    exit "$EX_TEMPFAIL"
fi

# ---- cuerpo ----
tmpdir=$(mktemp -d)
log_info "trabajando en $tmpdir"
# … tu lógica aquí …

log_info "done"
exit 0
```

Esta plantilla cubre: fallos tempranos, cleanup garantizado, bitácora limpia, concurrencia controlada, exit codes útiles, y pasa `shellcheck -S warning`.

---

## 10. Depuración (cuando algo falla igual)

- `bash -n script.sh` — chequeo sintáctico sin ejecutar.
- `bash -x script.sh` — traza equivalente a `set -x` desde el arranque.
- `BASH_XTRACEFD=5 ./script.sh 5>trace.log` — redirige la traza fuera de stderr para no mezclar.
- `set -o functrace` + `trap … DEBUG` — handler ante *cada* comando (lento, pero poderoso).
- `PS4='+${BASH_SOURCE}:${LINENO}: '` antes de `set -x` para que la traza incluya archivo y línea.

---

## 11. Checklist de revisión (úsalo en code review)

- [ ] `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`.
- [ ] Toda expansión de variable va entre comillas (salvo que haya razón explícita).
- [ ] `local x; x=$(cmd)` cuando se asigna de un subcomando dentro de función.
- [ ] `trap … EXIT` para cleanup; `trap … ERR` para contexto de fallo si el script es largo.
- [ ] Lock con `flock -n` si no debe correr en paralelo consigo mismo.
- [ ] Logs a stderr; datos a stdout.
- [ ] Exit codes semánticos (0, 64, 75, 78 según corresponda).
- [ ] `shellcheck -S warning` pasa sin findings (o con `disable` justificados).
- [ ] Reejecutar el script no destruye estado válido (idempotencia).

---

## 12. Preguntas de reflexión (responde sin consultar)

1. Explica, con un ejemplo, por qué `set -e` **no** aborta en `cmd1 && cmd2`. ¿Cómo lo arreglas si quieres que aborte?
2. Un script tiene `local tmp=$(mktemp -d)`; `mktemp` falla por disco lleno. ¿Qué pasa con `-e`? ¿Qué línea cambiarías?
3. Diferencia entre `trap 'rm -rf $tmp' EXIT` y poner `rm -rf $tmp` al final del script. Describe un escenario donde la segunda forma falla y la primera no.
4. Tienes un cron que a veces se retrasa y dispara dos veces. Comparas tres soluciones: (a) `touch /tmp/lock`, (b) `mkdir /tmp/lock.d`, (c) `flock -n`. ¿Por qué (c) es superior a (b), y (b) a (a)?
5. ¿Qué exit code elegirías para "la API externa devolvió 503"? ¿Por qué?
6. Un script hace `curl http://api | jq '.data[]' > out.json`. `curl` responde con un 404 (cuerpo vacío) pero el script termina con exit 0. ¿Qué dos flags cambian eso?
7. Diseña (sin escribir código) la combinación mínima que garantiza: "si matan el script con `kill -9`, el lock no queda stale". ¿`flock` basta? ¿`mkdir` basta? Justifica.
