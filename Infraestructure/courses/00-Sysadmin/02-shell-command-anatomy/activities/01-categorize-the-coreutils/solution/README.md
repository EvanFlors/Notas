# Solución de referencia — `sys-02-01-categorize-the-coreutils`

> Una clasificación posible y defendible. Varias asignaciones admiten alternativa (ver "Notas de frontera" al final).

| Comando | Categoría | Uso típico (una línea) |
|---------|-----------|-------------------------|
| ls | Navegación / FS | `ls -la ~/` lista el home con detalles y ocultos. |
| cp | Manipulación | `cp -av src/ dst/` copia preservando atributos. |
| rm | Manipulación | `rm -rf tmpdir/` elimina recursivamente (peligroso). |
| find | Búsqueda | `find . -name '*.log' -mtime -1` busca `.log` modificados hoy. |
| grep | Búsqueda | `grep -rni error logs/` busca "error" recursivo, con nº de línea, case-insensitive. |
| sed | Edición | `sed 's/foo/bar/g' file` sustituye `foo` por `bar`. |
| awk | Edición | `awk -F: '{print $1}' /etc/passwd` imprime los usernames. |
| cut | Edición | `cut -d: -f1 /etc/passwd` idéntico pero más rígido. |
| sort | Edición | `sort -u names.txt` ordena y deduplica. |
| uniq | Edición | `sort x \| uniq -c` cuenta ocurrencias ya ordenadas. |
| wc | Edición | `wc -l file` cuenta líneas. |
| head | Lectura | `head -n 20 file` primeras 20 líneas. |
| tail | Lectura | `tail -F /var/log/syslog` sigue el log en vivo. |
| cat | Lectura | `cat file` vuelca a stdout. |
| less | Lectura | `less +G file` abre al final del archivo. |
| xxd | Lectura | `xxd file \| head` ve el archivo en hex. |
| ps | Procesos | `ps auxf` snapshot de procesos con jerarquía. |
| top | Procesos | `top` live view de uso CPU/mem. |
| kill | Procesos | `kill -TERM 1234` pide salida ordenada al PID. |
| nice | Procesos | `nice -n 10 ./heavy.sh` baja prioridad. |
| ss | Red | `ss -tulpn` lista sockets TCP/UDP escuchando con PID. |
| ip | Red | `ip -br a` resumen de interfaces y direcciones. |
| curl | Red | `curl -fsSL https://host/path -o out` descarga silenciosa con error en 4xx/5xx. |
| dig | Red | `dig +short example.com` resolución DNS corta. |
| chmod | Usuarios | `chmod 0644 file` fija permisos rw-r--r--. |
| chown | Usuarios | `chown user:group file` cambia dueño/grupo. |
| sudo | Usuarios | `sudo apt update` ejecuta como root tras autenticación. |
| id | Usuarios | `id` imprime UID, GID y grupos. |
| apt | Paquetes | `sudo apt install -y nginx` instala sin preguntar. |
| dnf | Paquetes | `sudo dnf upgrade --refresh` actualiza con refresh de metadatos. |
| systemctl | Servicios | `systemctl status nginx` estado del servicio. |
| journalctl | Servicios | `journalctl -u nginx -f` sigue el log del servicio. |
| df | Disco | `df -h` uso de FS en humano. |
| du | Disco | `du -sh *` tamaño por entrada del cwd. |
| lsblk | Disco | `lsblk -f` discos/particiones con FS y UUID. |
| tar | Archivadores | `tar -czf x.tgz src/` empaqueta y comprime. |
| gzip | Archivadores | `gzip -9 file` comprime maximizando ratio. |
| sha256sum | Checksums | `sha256sum -c SUMS` verifica archivos contra SUMS. |
| gpg | Checksums | `gpg --verify file.sig file` verifica firma. |
| type | Meta | `type -a ls` muestra todas las resoluciones del nombre. |

## Preguntas (respuestas de referencia)

1. **`find` ¿Búsqueda o Navegación/FS?** → **Búsqueda** como categoría primaria: su verbo central es *encontrar* según criterios (`-name`, `-mtime`, `-size`), y su acción puede ser arbitraria vía `-exec`. Encaja también en Navegación/FS porque recorre el árbol — pero esa es su *mecánica*, no su *propósito*.

2. **`sudo`** → En la tabla canónica cae en **Usuarios / permisos** porque modela "con qué identidad y privilegios ejecuto X". Técnicamente *lanza procesos*, pero su valor está en el modelo de autorización (sudoers, `NOPASSWD`, logging). No es un gestor de procesos.

3. **`rsync`** → **Manipulación de archivos** (sync local o remoto). Comparte frontera con Red cuando opera sobre SSH, pero su núcleo semántico es "copiar/sincronizar árboles".

4. **Dos builtins de Meta**: `type` y `command` lo son (verificables con `type -a type`, `type -a command`). `which` **no** lo es (es externo). `alias` sí lo es (builtin).

5. (Respuesta libre; depende del alumno.)

## Notas de frontera

- `cat` lo pusimos en **Lectura**; algunos lo ponen en Edición cuando se usa para concatenar (`cat a b > c`). Ambas defensas son válidas.
- `wc` suele ponerse en Edición porque forma pipelines; también cabe como Lectura/estadística.
- `kill` es verbo de Procesos aunque internamente envíe **señales**; profundizaremos en `sys-05`.
- `tar` lo ponemos en Archivadores; algunos lo meten en Manipulación por su `--extract` + `-C`. Preferimos la primera porque *empaquetar* es su esencia.
