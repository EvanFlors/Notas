# Lección: Archivos Unix y filesystem

> **ID:** `sys-03-unix-files-and-filesystem` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `sys-01`, `sys-02`.

---

## 1. Introducción intuitiva

En Windows, un "archivo" es un bloque de bytes con nombre y, aparte, el sistema expone impresoras, discos y la red por APIs distintas. En Unix, en cambio, se tomó una decisión brutal: **todo es un archivo**. Un documento es un archivo. Un directorio es un archivo (que lista otros archivos). Un disco duro es un archivo (`/dev/sda`). La información del CPU es un archivo (`/proc/cpuinfo`). La pantalla de otra terminal es un archivo (`/dev/pts/3`). Un canal entre dos procesos es un archivo (FIFO). Un socket de red es un archivo.

Esto no es una metáfora pedagógica: es la realidad del kernel. El mismo *system call* (`open`, `read`, `write`, `close`) funciona para todos. Por eso puedes decir `cat /dev/urandom > /dev/dsp` y la tarjeta de sonido reproduce ruido; o `grep model /proc/cpuinfo` y el kernel sintetiza el "archivo" en el momento.

Este módulo construye la ontología correcta: los **tipos** de archivo, cómo el kernel los representa (inodos, dentries, VFS), dónde los coloca Linux (**FHS**), y cómo buscarlos sin pegarte un tiro en el pie (`find` seguro).

---

## 2. Los siete tipos de archivo

Cuando ejecutas `ls -l`, el primer carácter de cada línea codifica el **tipo**:

| Carácter | Tipo | Ejemplo típico |
|----------|------|----------------|
| `-` | Regular file | `/etc/hostname`, un `.py`, un binario |
| `d` | Directory | `/etc`, `/home/juan` |
| `l` | Symbolic link | `/usr/bin/python → python3.11` |
| `b` | Block device | `/dev/sda`, `/dev/nvme0n1` (acceso en bloques) |
| `c` | Character device | `/dev/tty`, `/dev/null`, `/dev/urandom` (byte a byte) |
| `p` | Named pipe (FIFO) | creado con `mkfifo` |
| `s` | Socket | sockets Unix (p. ej. `/var/run/docker.sock`) |

Herramientas para preguntar el tipo:

```bash
ls -l archivo              # primer carácter
stat -c '%F' archivo       # nombre humano: "regular file", "symbolic link"...
file archivo               # heurística sobre el CONTENIDO (no el tipo del inodo)
find /dev -type c | head   # filtrar por tipo con find
```

> `file` mira el contenido (ej.: "ELF 64-bit LSB executable"), mientras que `stat` y `ls -l` miran la metadata del inodo. Son preguntas distintas.

---

## 3. Inodos, dentries y el nombre del archivo

Un novato cree que un archivo "es" su nombre. En Unix, el nombre es solo una etiqueta en un cajón; el archivo real vive en otro lado.

### 3.1 El inodo

El **inodo** es la estructura del kernel que describe un archivo:

- Número único por filesystem (`ls -i`).
- Tipo (regular, directory, link, device...).
- Permisos y modo.
- Dueño (`uid`) y grupo (`gid`).
- Timestamps (`atime`, `mtime`, `ctime`).
- Tamaño.
- Puntero a los bloques de datos reales en disco.
- Contador de **enlaces duros** (nlink).

El inodo **no contiene el nombre**. Repítelo: el nombre no está en el inodo.

### 3.2 La dentry (directory entry)

Un directorio, visto por dentro, es una tabla:

```
nombre        → número de inodo
----          -------------------
"README.md"   → 1483201
"src"         → 1483455   (que es, a su vez, otro directorio)
".."          → 1480000   (el directorio padre)
"."           → 1483100   (yo mismo)
```

Cada entrada `(nombre, inodo)` es una **dentry**. "Borrar un archivo" con `rm` significa: quitar la dentry del directorio y decrementar `nlink`. Si `nlink` llega a 0 y nadie lo tiene abierto, el kernel libera los bloques. Si alguien lo tiene abierto, el inodo persiste en memoria hasta que cierre —de ahí viene el truco de borrar un archivo de log para liberar espacio y descubrir que `df` no cambia hasta que reinicias el servicio.

### 3.3 Diagrama

```
       /home/juan/
       ┌───────────────────────────────┐
       │ "notas.txt" ──► inodo 1483201 │ ──► bloques en disco: "hola\n..."
       │ "copia.txt"  ──► inodo 1483201│       (nlink = 2)
       └───────────────────────────────┘
                             ▲
                             │ dos nombres → UN inodo → UN contenido
```

`notas.txt` y `copia.txt` son **hardlinks**: dos dentries apuntando al mismo inodo. Borrar `notas.txt` deja `copia.txt` sano; el contenido vive mientras `nlink > 0`.

---

## 4. Hardlinks vs symlinks

| Aspecto | Hardlink | Symlink |
|---------|----------|---------|
| Qué es | Segunda dentry al mismo inodo | Archivo tipo `l` cuyo contenido es una **ruta** |
| Tipo en `ls -l` | `-` (regular, como el original) | `l` |
| Comparten inodo | Sí | No (son dos inodos distintos) |
| Funcionan entre filesystems | **No** | Sí |
| Pueden apuntar a directorios | No (excepto root y con cuidado) | Sí |
| Sobreviven al borrado del "original" | Sí (son iguales de "originales") | No, quedan colgando (`dangling`) |
| Comando | `ln origen destino` | `ln -s origen destino` |

Comandos de inspección:

```bash
ls -li archivo              # primera columna = inodo
stat archivo                # muestra Links: N (contador nlink)
readlink enlace             # imprime el TARGET literal del symlink
readlink -f enlace          # resuelve recursivamente, da ruta canónica
```

**Caso típico**: `/usr/bin/python` es un symlink a `python3`, que a su vez es un symlink a `python3.11`. Esto permite actualizar la versión sin romper rutas hardcodeadas.

**Trampa frecuente**: un symlink roto no es un error en sí; `ls -l` lo muestra en rojo, pero `stat enlace` falla con "No such file or directory" aunque el symlink exista. Para preguntar por el symlink mismo (no por el target), usa `stat -L` para seguirlo o `ls -l` para verlo.

---

## 5. Filesystem Hierarchy Standard (FHS 3.0)

El FHS define *dónde* van las cosas en un Linux sano. Ignorarlo produce sistemas que nadie puede mantener.

| Ruta | Qué vive aquí | Ejemplo | ¿Modificable? |
|------|---------------|---------|---------------|
| `/` | Raíz del árbol. Nada se guarda directo aquí. | — | — |
| `/bin`, `/sbin` | Binarios básicos (hoy casi siempre symlinks a `/usr/bin`, `/usr/sbin`). | `ls`, `cp`, `mount` | No a mano |
| `/boot` | Kernel, initramfs, bootloader. | `vmlinuz`, `grub/` | Con cuidado |
| `/dev` | Dispositivos (block, char). Lo puebla `udev`. | `/dev/sda`, `/dev/null` | No a mano |
| `/etc` | **Configuración del sistema**, texto plano. | `/etc/hostname`, `/etc/ssh/sshd_config` | Sí (editable) |
| `/home` | Directorios personales de usuarios normales. | `/home/juan` | Sí |
| `/root` | Home del usuario `root` (fuera de `/home` por si `/home` no monta). | — | Sí |
| `/lib`, `/lib64` | Bibliotecas compartidas necesarias para `/bin` y `/sbin` (hoy symlinks a `/usr/lib`). | `libc.so.6` | No a mano |
| `/media`, `/mnt` | Puntos de montaje temporales (USB, discos externos). | `/media/juan/USB` | Sí |
| `/opt` | Software de terceros auto-contenido, un árbol por producto. | `/opt/google/chrome/` | Sí |
| `/proc` | **Pseudo-FS**: estado del kernel y procesos. No gasta disco. | `/proc/cpuinfo`, `/proc/1234/status` | Algunas entradas, sí |
| `/sys` | **Pseudo-FS**: interfaz al modelo de dispositivos del kernel. | `/sys/class/net/eth0/mtu` | Algunas entradas, sí |
| `/run` | Estado volátil de servicios en memoria (`tmpfs`). | `/run/sshd.pid`, `/run/user/1000` | Sí (procesos lo manejan) |
| `/srv` | Datos servidos por el sistema (web, ftp). | `/srv/www/` | Sí |
| `/tmp` | Temporales. Puede limpiarse al reiniciar. | — | Sí |
| `/usr` | **"Secondary hierarchy"**: la mayor parte del SO. | ver abajo | Paquetes, no a mano |
| `/usr/bin`, `/usr/sbin` | Binarios del sistema (los del paquete). | `grep`, `systemctl` | No a mano |
| `/usr/lib` | Bibliotecas del sistema. | `/usr/lib/x86_64-linux-gnu/` | No a mano |
| `/usr/local/` | **Lo que instalas tú** compilando (no vía gestor de paquetes). | `/usr/local/bin/mi-script` | Sí |
| `/usr/share` | Datos independientes de arquitectura (iconos, docs, locales). | `/usr/share/man/` | No a mano |
| `/var` | **Estado variable** del sistema: logs, caches, colas, DBs. | `/var/log/`, `/var/cache/` | Sí |
| `/var/log` | Logs. | `/var/log/syslog`, `/var/log/journal/` | Lectura |
| `/var/lib` | Estado persistente de servicios. | `/var/lib/mysql/`, `/var/lib/dpkg/` | Servicios |

**Regla práctica**:

- Vas a editar config → `/etc/`.
- Vas a instalar algo tuyo compilado → `/usr/local/`.
- Vas a dejar un producto embotellado de terceros → `/opt/<producto>/`.
- Vas a dejar algo solo para tu usuario → `~/.local/bin/` y `~/.config/`.
- Nunca escribas a `/usr/bin/` a mano: lo rompe el próximo `apt upgrade`.

---

## 6. Pseudo-filesystems: `/proc` y `/sys`

Ni `/proc` ni `/sys` existen en disco. Son interfaces que el kernel **sintetiza** cuando los lees. Esa es la elegancia última de "todo es un archivo": consultar al kernel es `cat`.

### 6.1 `/proc` (procfs)

Expuesto en Linux desde los 90. Dos cosas conviven:

**(a) Info global del sistema:**

```bash
cat /proc/cpuinfo        # CPU: modelo, cores, flags
cat /proc/meminfo        # memoria: total, libre, cache, swap
cat /proc/loadavg        # 1/5/15 min + procesos
cat /proc/uptime         # segundos encendido / segundos idle
cat /proc/mounts         # montajes vivos (equivalente a `mount` sin args)
cat /proc/version        # versión del kernel
```

**(b) Un directorio por proceso (`/proc/<pid>/`):**

```bash
ls /proc/self/           # 'self' es un symlink al PID del proceso lector
cat /proc/self/status    # estado, UIDs, memoria, etc.
cat /proc/self/cmdline   # argv (bytes separados por NUL)
readlink /proc/self/exe  # ruta del binario
ls /proc/self/fd/        # descriptores de archivo abiertos (son symlinks)
cat /proc/self/maps      # mapeo de memoria del proceso
```

Trucos útiles:

```bash
# Qué archivos tiene abiertos un proceso
ls -l /proc/<pid>/fd/

# Reconstruir CWD de un proceso
readlink /proc/<pid>/cwd

# Qué binario está corriendo realmente (incluso si el ejecutable fue borrado)
readlink /proc/<pid>/exe
# Si acaba en " (deleted)", el proceso corre un binario fantasma — típico tras upgrade.
```

### 6.2 `/sys` (sysfs)

Introducido en 2.6. Expone el **modelo de dispositivos** del kernel: cada dispositivo es un directorio con atributos legibles/escribibles.

```bash
cat /sys/class/net/eth0/address   # MAC
cat /sys/class/net/eth0/mtu       # MTU actual
echo 9000 > /sys/class/net/eth0/mtu  # (como root) cambia la MTU
cat /sys/block/sda/size           # tamaño en sectores de 512B
```

**Regla**: para preguntar al kernel por *procesos*, `/proc`. Para preguntar por *hardware y drivers*, `/sys`.

---

## 7. VFS, montajes y filesystems

### 7.1 VFS (Virtual File System)

El kernel no sabe de ext4, xfs, btrfs, nfs... directamente: habla con una capa de abstracción, **VFS**, que define las operaciones ("open", "read", "readdir") y despacha a drivers concretos. Esa es la razón por la que puedes `cp` de un `ext4` a un `btrfs` montado sobre un disco remoto por `nfs` sin saber nada: VFS unifica la API.

### 7.2 Mount points

Un **mount point** es un directorio donde se "cuelga" otro filesystem. El directorio original queda tapado mientras el mount esté activo.

```bash
mount                # lista montajes (lee /proc/mounts)
findmnt              # vista en árbol
df -hT               # uso por filesystem con tipo
```

Un detalle sutil: los inodos de distintos filesystems **colisionan en número**. Por eso un hardlink no puede cruzar un mount: el inodo 12345 de `ext4` no es el mismo que el 12345 de `xfs`.

### 7.3 Superblock

Cada filesystem persistente tiene un **superblock**: la metadata global (tamaño total, cuántos inodos, estado "clean/dirty", UUID). Si se corrompe, nada se puede leer; por eso ext4 guarda copias de respaldo (`dumpe2fs -h`).

### 7.4 Panorama de filesystems

| FS | Año | Características clave | Cuándo elegirlo |
|----|-----|-----------------------|-----------------|
| **ext4** | 2008 | Journaling, maduro, defaults sanos. | Default seguro para servidores Linux. |
| **xfs** | 1994 (SGI, portado a Linux 2001) | Grandes files/FS, muy bueno en workloads paralelos. | Datos grandes, almacenamiento pesado. |
| **btrfs** | 2009 | CoW, snapshots, subvolúmenes, checksums, RAID interno. | Workstations, snapshots, backups diferenciales. |
| **zfs** | (fuera de kernel por licencia) | Como btrfs, más maduro operacionalmente. | NAS, almacenamiento serio (con módulo OpenZFS). |
| **tmpfs** | — | En memoria. | `/tmp`, `/run`. Se pierde al reiniciar. |

---

## 8. `find`: la herramienta pesada

`find` recorre un árbol aplicando pruebas y acciones. Su lógica es declarativa: cada argumento es una expresión que, para cada ruta, se evalúa.

### 8.1 Pruebas comunes

```bash
find . -type f                     # solo regulares
find . -type d                     # solo directorios
find . -type l                     # solo symlinks
find /dev -type c                  # character devices
find . -name '*.log'               # patrón de glob sobre el basename
find . -iname '*.LOG'              # case-insensitive
find . -mtime -7                   # modificados en los últimos 7 días
find . -mtime +30                  # modificados hace MÁS de 30 días
find . -size +100M                 # mayores a 100 MiB
find . -size -1k                   # menores a 1 KiB
find . -user juan -group juan      # dueño/grupo
find . -perm -u+x                  # ejecutable por el dueño
find . -empty                      # vacíos (file o dir)
find . -newer /tmp/ref             # más recientes que un fichero referencia
```

### 8.2 Acciones y combinaciones

```bash
find . -name '*.pyc' -delete
find . -name '*.log' -mtime +30 -print
find . -type f -name '*.sh' -exec chmod +x {} \;
find . -type f -name '*.sh' -exec chmod +x {} +   # agrupa en 1 llamada
```

Entre pruebas, el operador implícito es `-a` (AND). Para OR: `\( A -o B \)`.

```bash
find . \( -name '*.log' -o -name '*.tmp' \) -delete
```

### 8.3 Recetas útiles

```bash
# 10 archivos más grandes bajo /var
find /var -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head

# Archivos modificados en la última hora
find /etc -type f -mmin -60

# Directorios enormes (profundidad 1, para echar un vistazo)
du -h --max-depth=1 /var 2>/dev/null | sort -h

# Buscar un string en archivos .conf de /etc, siguiendo pequeños y seguros
find /etc -type f -name '*.conf' -print0 | xargs -0 grep -l 'Listen'
```

`-xdev` evita cruzar mount points (no entrar a `/proc`, `/sys`, discos externos). Casi siempre lo quieres.

---

## 9. Nombres hostiles y la idiomática `-print0 | xargs -0`

Un nombre de archivo en Unix puede contener **casi cualquier byte** excepto `/` y `\0`. Esto incluye:

- Espacios: `mi archivo.txt`.
- Saltos de línea: `foo\nbar.txt` (sí, es legal).
- Comillas y backticks: `it's.txt`, `` `rm -rf`.sh ``.
- Guiones iniciales: `-rf` (que luego parece una flag).
- Unicode y bytes "inválidos".

Un bucle ingenuo rompe:

```bash
# MAL: se rompe con espacios y newlines
for f in $(find . -name '*.log'); do rm "$f"; done

# MAL: idem
find . -name '*.log' | xargs rm
```

El modo correcto usa el separador **NUL** (`\0`), el único byte que un nombre no puede contener:

```bash
# BIEN
find . -name '*.log' -print0 | xargs -0 rm --
```

- `find ... -print0` separa resultados con `\0` en lugar de newline.
- `xargs -0` lee tokens separados por `\0`.
- `--` evita que un nombre que empieza con `-` sea tratado como opción.

Alternativa aún más segura (sin `xargs`):

```bash
find . -name '*.log' -exec rm -- {} +
```

Para bucles en bash:

```bash
while IFS= read -r -d '' f; do
  printf 'borrando: %q\n' "$f"
  rm -- "$f"
done < <(find . -name '*.log' -print0)
```

**Regla**: cualquier script "de producción" que itere nombres de archivo DEBE usar `-print0` y `-0` (o `-exec ... +`). No es paranoia; es que los nombres hostiles aparecen —adjuntos de email, nombres pegados desde Windows, exploits deliberados.

---

## 10. `locate` / `mlocate`: el índice complementario

`find` recorre el árbol en vivo: exacto pero lento. `locate` consulta un **índice** actualizado periódicamente (habitualmente por `updatedb` desde cron o systemd timer): rapidísimo pero posiblemente desactualizado unas horas.

```bash
sudo updatedb              # reconstruye el índice
locate sshd_config         # búsquedas instantáneas por nombre
locate -i README           # case-insensitive
locate -e config.yaml      # verifica que el archivo exista aún
```

Úsalo cuando sabes el nombre pero no la ruta. Usa `find` cuando necesitas filtrar por tiempo, tamaño, permisos o tipo.

---

## 11. Observación y diagnóstico — comandos de referencia

```bash
# Metadata completa de un archivo
stat archivo
stat -c '%A %U:%G %s %n' archivo    # formato personalizado

# Tipo del contenido vs tipo del inodo
file archivo
file -i archivo             # con mime-type

# Resolver un symlink
readlink archivo            # target literal
readlink -f archivo         # ruta canónica

# Listar devices
ls -l /dev/sda /dev/null /dev/tty

# Crear tipos no triviales
touch regular.txt
mkdir dir
ln original hardlink
ln -s original symlink
mkfifo canal.fifo

# Preguntar al kernel
cat /proc/cpuinfo | grep -c '^processor'   # cores lógicos
cat /proc/mounts                           # igual que mount
ls /proc/self/fd/                          # tus propios FDs
```

---

## 12. Errores frecuentes

- **"Borré el log pero `df` no cambia"**: algún proceso lo tiene abierto. Encuéntralo con `lsof | grep deleted` y reinícialo (o `truncate -s 0`).
- **"El symlink no funciona"**: `ls -l` muestra el target *literal*. Si es relativo, es relativo al **directorio donde vive el symlink**, no a tu CWD. Verifica con `readlink -f`.
- **"`find` tarda años"**: olvidaste `-xdev` y entraste a `/proc` o un NFS caído. Añádelo.
- **"Mi script falla con un archivo llamado `-foo`"**: faltó el `--` en `rm`, `grep`, `cp`...
- **"Puse mi binario en `/usr/bin/` y desapareció"**: `apt upgrade` reemplazó el paquete que ocupaba esa ruta. Usa `/usr/local/bin/`.
- **"Hard link entre `/home` y `/mnt/ext`": no se puede** — son filesystems distintos. Usa symlink.
- **"`stat enlace` dice No such file or directory"**: el symlink está roto. `ls -l enlace` sí te muestra el target.

---

## 13. Preguntas de evaluación

Responde sin consultar la lección:

1. ¿Qué es exactamente un inodo y por qué el nombre del archivo no vive en él?
2. ¿En qué caso un `rm` **no** libera espacio en disco inmediatamente? ¿Cómo lo arreglas?
3. Diferencia operativa entre hardlink y symlink en: (a) borrar el original, (b) cruzar mount points, (c) apuntar a un directorio.
4. ¿Por qué `/proc/cpuinfo` no ocupa espacio en disco? ¿Qué pasa cuando le haces `cat`?
5. Instalas un binario propio compilado desde fuentes. ¿Dónde lo pones y por qué no en `/usr/bin/`?
6. Escribe un `find` que borre archivos `.tmp` modificados hace más de 7 días, sin romperse ante nombres con espacios o newlines, y sin salir del filesystem actual.
7. ¿Qué diferencia hay entre `readlink enlace` y `readlink -f enlace`?
8. ¿Qué expone `/sys` que no expone `/proc`?
9. ¿Por qué un hardlink no puede cruzar entre `/home` (en `/dev/sda2`, `ext4`) y `/mnt/data` (en `/dev/sdb1`, `xfs`)?
10. En tu propio proceso bash, ¿qué contiene `/proc/self/fd/0`? ¿Y `/proc/self/fd/1`?
