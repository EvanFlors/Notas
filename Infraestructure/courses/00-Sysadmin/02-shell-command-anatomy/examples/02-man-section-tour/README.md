# Ejemplo 02 — Tour por las secciones de `man`

## Concepto que demuestra

Un mismo **nombre** puede existir en varias **secciones** de `man`. Elegir la sección correcta es parte de "saber leer la documentación".

Vamos a visitar:

- `man 1 printf` — el **comando** de shell.
- `man 3 printf` — la **función** de la biblioteca C.
- `man 5 passwd` — el **formato** del archivo `/etc/passwd` (no el comando `passwd`).

## Contexto

El sistema de manpages se divide en 8 secciones numeradas (sección 1 = comandos de usuario, 2 = syscalls, 3 = libc, 4 = devices, 5 = formatos, 6 = juegos, 7 = misc, 8 = admin). Cuando ejecutas `man foo` sin número, `man` devuelve la **primera** sección donde encuentra `foo`, que normalmente es la 1.

## Objetivo

Al terminar, podrás:

- Pedir una sección específica (`man 5 passwd`).
- Listar todas las secciones donde aparece un nombre (`man -k ^passwd$`, `whatis passwd`).
- Reconocer la diferencia estructural entre una página de comando (sección 1) y una página de formato de archivo (sección 5).

## Prerrequisitos

- `man` y `man-db` instalados.
- `whatis` / `apropos` funcionales. Si en Debian/Ubuntu no funcionan recién instalado el sistema, ejecuta `sudo mandb` una vez.
- `printf` y `passwd` presentes en el sistema (lo están en cualquier Linux básico).

## Ejecución

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. ¿En qué secciones vive "printf"?
whatis printf
# Salida típica (varía por distro):
#   printf (1)  - format and print data
#   printf (3)  - formatted output conversion

# 2. Sección 1 — el COMANDO de shell.
#    Léelo con /format para localizar la sintaxis de la cadena.
man 1 printf
# Dentro del pager:
#   /FORMAT   buscar
#   n         siguiente
#   q         salir

# 3. Sección 3 — la FUNCIÓN de la biblioteca C.
#    Observa el SYNOPSIS: incluye el header "#include <stdio.h>" y la firma.
man 3 printf

# 4. ¿Y "passwd"?
whatis passwd
# Salida típica:
#   passwd (1)        - change user password
#   passwd (5)        - the password file
#   passwd (1ssl)     - compute password hashes (si tienes openssl-doc)

# 5. Sección 1 — el COMANDO interactivo que cambia tu contraseña.
man 1 passwd

# 6. Sección 5 — el FORMATO del archivo /etc/passwd.
#    Nota: aquí NO hay SYNOPSIS de comando; hay un formato de línea.
man 5 passwd

# 7. Cuando dudes qué sección usar:
apropos "password file"
# Lista todas las páginas cuyo título menciona "password file".
```

## Resultado esperado

- `whatis printf` imprime dos líneas (secciones 1 y 3).
- `man 1 printf` y `man 3 printf` muestran contenidos distintos: uno habla de "escribe a stdout", el otro habla de "escribe a FILE* `stdout`" y menciona `<stdio.h>`.
- `man 5 passwd` describe el **archivo** con sus 7 campos separados por `:` — no menciona cómo cambiar tu contraseña.
- `apropos "password file"` lista al menos `passwd (5)` entre los resultados.

## Interpretación

- **Sección 1** describe un **ejecutable** que invocas desde una shell: tiene `SYNOPSIS` con flags y argumentos.
- **Sección 3** describe una **función C**: `SYNOPSIS` con `#include` y prototipo. Útil cuando programas en C y no quieres asumir cómo se comporta `printf("%d\n", x)`.
- **Sección 5** describe un **formato de datos**: no se "ejecuta". Documenta cómo está estructurado un archivo del sistema (`/etc/passwd`, `/etc/fstab`, `/etc/hosts`, `crontab`).

Esta distinción explica errores clásicos:

- Un developer buscando "cómo funciona `printf` en bash" lee la sección 3 y se confunde con `va_list`. Debía haber pedido la sección 1.
- Un sysadmin editando `/etc/passwd` lee `man passwd` (que es `man 1 passwd`) y encuentra `chfn`, `-l`, `-u`… nada sobre los 7 campos. Debía haber pedido `man 5 passwd`.

## Errores frecuentes

- **No especificar sección**: `man passwd` dará *una* página; si quieres la otra, nómbrala.
- **`man` dice "No manual entry for X"**: la base `mandb` puede no estar actualizada. Prueba `sudo mandb` o `sudo apt install manpages-dev` (secciones 2 y 3).
- **Páginas de sección 2/3 ausentes** en imágenes Docker mínimas o Alpine: instala `manpages-dev` (Debian) o `man-pages-posix` (Alpine).

## Relación con escenarios reales

- Al debuggear un script que invoca `/usr/bin/printf` en lugar del builtin de Bash, `man 1 printf` te dice cómo responde el binario externo (que **no** es exactamente igual al builtin).
- Al escribir un `.service` de systemd o un `fstab`, buscar `man 5 systemd.service` o `man 5 fstab` es la forma correcta de aprender el formato.
- Al leer código C de terceros, `man 2 open` vs `man 3 fopen` te aclara si estás viendo una syscall o un wrapper libc.

## Comando bonus: lista de todas las secciones donde algo aparece

```bash
for s in 1 2 3 4 5 6 7 8; do
  man -w -s "$s" open 2>/dev/null && echo "  (sección $s)"
done
```

`man -w` imprime la **ruta** de la página sin abrirla; útil para scripts.

## Limpieza

Nada que limpiar: no creamos archivos.
