# FHS treasure hunt — respuestas

> Rellena **cada respuesta** incluyendo:
> - El **comando** que usaste para encontrar la respuesta.
> - La **ruta** concreta en tu sistema.
> - Una línea de **interpretación** propia (qué significa que esté ahí).

---

## Bloque A — FHS básico

### 1. Config de SSH servidor

¿Dónde vive el fichero de configuración principal del demonio SSH?

- Comando:
- Ruta:
- Interpretación:

### 2. Logs del sistema

¿Dónde se guardan los logs tradicionales de texto plano? (`syslog`, `auth.log`, `messages`...)

- Comando:
- Ruta:
- Interpretación:

### 3. Logs binarios de systemd

Si tu distro usa systemd-journald, ¿dónde vive el journal binario?

- Comando:
- Ruta:
- Interpretación:

### 4. Binario del shell

¿Qué ruta reporta `which bash`? ¿Es un archivo regular, un symlink o un hardlink?

- Comando:
- Ruta:
- Tipo:
- Interpretación:

### 5. Instalación local de un binario tuyo

Compilas un pequeño programa `holamundo`. ¿Dónde lo colocas para que esté en el `PATH` sin pisar paquetes del sistema? Justifica.

- Ruta elegida:
- Justificación (NO debe mencionar `/usr/bin`):

### 6. Software de terceros embotellado

Instalas Chrome (de Google, no del repo). ¿Dónde vive típicamente su árbol?

- Ruta:
- Interpretación:

### 7. Estado persistente de servicios

¿Dónde guardan los paquetes `.deb` su base de datos de paquetes instalados? ¿Y PostgreSQL sus datos?

- Ruta `dpkg`:
- Ruta PostgreSQL (si aplica, estándar):
- Interpretación:

### 8. Volátil en memoria

¿Qué tipo de filesystem monta `/run`? ¿Qué pasa con su contenido al reiniciar?

- Comando usado para inspeccionar:
- Tipo FS:
- Interpretación:

---

## Bloque B — Pseudo-filesystems

### 9. CPU del sistema

Imprime el modelo del CPU **sin** usar `lscpu`.

- Comando:
- Interpretación (por qué funciona esto sin ocupar disco):

### 10. `/proc/self`

Ejecuta `readlink /proc/self` varias veces desde la misma shell. ¿El valor es el mismo? Explica.

- Comando:
- Observación:
- Interpretación:

### 11. Descriptores abiertos de un proceso

Lanza `sleep 300 &`, apunta el PID, y lista `/proc/<pid>/fd/`. ¿A qué apuntan `0`, `1`, `2`?

- PID:
- `fd/0`:
- `fd/1`:
- `fd/2`:

### 12. Un atributo de red vía `/sys`

¿Cuál es la MAC de tu interfaz principal leyendo directamente `/sys`? ¿Y la MTU?

- Comando:
- Interfaz:
- MAC:
- MTU:

---

## Bloque C — Mounts

### 13. Montajes actuales

Lista todos los mounts con tipo y uso. ¿Cuál es el filesystem raíz? ¿Qué tipo es?

- Comando:
- FS raíz:
- Tipo:

### 14. ¿Por qué un hardlink no cruza mounts?

En tu sistema, elige dos directorios en mounts distintos (p. ej. `/tmp` si es tmpfs y `/home`). Intenta `ln /tmp/X /home/<tu-user>/X`. Reporta error y explica.

- Comando intentado:
- Error:
- Explicación:

---

## Bloque D — find seguro

### 15. Top 5 archivos más grandes bajo tu HOME

Escribe un pipeline con `find` que imprima los 5 archivos más grandes bajo `$HOME`, **sin cruzar mount points** y **sin romperse ante nombres con espacios o saltos de línea**.

- Comando:
- Primera línea del output:
- Interpretación (qué hace cada parte del pipeline):
