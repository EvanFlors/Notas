# Ejemplo 02 — Tour por `/proc`

## Concepto que demuestra

Que `/proc` es un **pseudo-filesystem**: cada "archivo" es una ventana al kernel que se sintetiza al leerlo. No ocupa disco. Se exploran dos vertientes: la **global** (`/proc/cpuinfo`, `/proc/meminfo`, ...) y la **por proceso** (`/proc/<pid>/...`).

> Nota: este ejemplo asume **Linux**. En macOS no existe `/proc` nativo; usa una VM Linux o un contenedor.

## Objetivo

Al terminar podrás responder:

- ¿Qué es `/proc/self` y por qué su contenido depende de **quién** lo lee?
- ¿Qué contiene `/proc/<pid>/status`? ¿Y `/proc/<pid>/fd/`?
- ¿Cómo encuentras el binario que está corriendo un PID, incluso si fue borrado del disco?

## Prerrequisitos

- Linux.
- Shell bash.

## Ejecución

Ejecuta los bloques siguientes **en orden**, leyendo la salida de cada uno antes de pasar al próximo.

### 1. Global: info del sistema

```bash
# CPU: modelo, cores lógicos, flags
head -20 /proc/cpuinfo
grep -c '^processor' /proc/cpuinfo       # número de cores lógicos

# Memoria
head -5 /proc/meminfo

# Carga y uptime
cat /proc/loadavg
cat /proc/uptime

# Montajes (equivalente a `mount` sin argumentos)
head /proc/mounts

# Kernel
cat /proc/version
```

Observa: ninguno de estos "archivos" tiene tamaño en disco. `ls -l /proc/cpuinfo` muestra `0` bytes, y aun así `cat` imprime contenido. Lo genera el kernel al vuelo.

### 2. `/proc/self`: el proceso que lee

```bash
# 'self' es un SYMLINK dependiente del lector:
ls -l /proc/self
readlink /proc/self
# El número apunta al PID del proceso que ejecutó el readlink.
# Si lo haces en bash, es el PID del bash; via subshell, del subshell.

# Comparación:
echo "mi PID shell: $$"
readlink /proc/self        # será un PID distinto: el del propio readlink
```

### 3. Un proceso en vivo

En una **segunda terminal**, lanza:

```bash
sleep 1000 &
echo "PID de sleep: $!"
```

Y en la primera, usa ese PID:

```bash
PID=<pega-el-pid>

# Estado detallado
cat /proc/$PID/status | head -20

# Argumentos del proceso (bytes separados por NUL)
tr '\0' ' ' < /proc/$PID/cmdline; echo

# Binario que ejecutó
readlink /proc/$PID/exe

# Directorio de trabajo
readlink /proc/$PID/cwd

# Descriptores de archivo abiertos (son symlinks al target real)
ls -l /proc/$PID/fd/
```

Para `sleep`, deberías ver típicamente:

- `fd/0` → `/dev/pts/<N>` (stdin, la terminal).
- `fd/1` → `/dev/pts/<N>` (stdout, la misma terminal).
- `fd/2` → `/dev/pts/<N>` (stderr).

### 4. El truco del binario borrado

Útil cuando debuggeas por qué un servicio "no agarra" el update:

```bash
# Imaginemos que /usr/bin/foo fue reemplazado o borrado.
# Un proceso lanzado ANTES sigue corriendo la versión vieja.
readlink /proc/$PID/exe
# Si acaba en " (deleted)", el proceso está ejecutando bytes
# que ya no están en el filesystem. Hay que reiniciar el servicio.
```

### 5. Limpiar

```bash
kill $PID
```

## Interpretación

- `/proc` es la API "legible por humanos" al estado del kernel. Herramientas como `ps`, `top`, `free`, `uptime` solo son parseadores bonitos sobre esto.
- `/proc/self` resuelve "quién soy yo" sin que el proceso tenga que preguntar su PID.
- `/proc/<pid>/fd/` es oro para debugging: dice qué archivos, sockets o pipes tiene abiertos un servicio.

## Relación con escenarios reales

- Debugging de servicios que "no liberan memoria" tras un upgrade: `readlink /proc/<pid>/exe` revela si corren un binario borrado.
- Localizar un socket Unix que un contenedor tiene abierto: `ls -l /proc/<pid>/fd/`.
- Monitoreo barato de carga sin instalar nada: `watch -n1 cat /proc/loadavg`.
