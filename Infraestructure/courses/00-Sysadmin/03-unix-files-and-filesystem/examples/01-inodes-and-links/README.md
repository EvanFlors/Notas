# Ejemplo 01 — Inodos, hardlinks y symlinks

## Concepto que demuestra

Que un hardlink es **una segunda dentry al mismo inodo** (y por tanto comparte número de inodo, contador `nlink` y contenido), mientras que un symlink es **un archivo distinto cuyo contenido es una ruta** y se rompe si el target desaparece.

## Objetivo

Al terminar podrás responder:

- ¿Qué número de inodo tienen el original y el hardlink? ¿Son iguales?
- Si borras el "original", ¿qué pasa con el hardlink? ¿Y con el symlink?
- ¿Cómo distingues un hardlink de un symlink en `ls -l`?

## Prerrequisitos

- Shell bash o compatible.
- Directorio escribible (usaremos `/tmp/`).

## Ejecución

```bash
bash files/demo.sh
```

El script es idempotente: borra y recrea `/tmp/links-demo` cada vez.

## Lee la salida esperada

Verás, en orden:

1. Un archivo original `original.txt` creado con contenido conocido.
2. Un hardlink `hardlink.txt` creado con `ln`. `ls -li` muestra que **comparten inodo** y que la columna `nlink` pasó a `2`.
3. Un symlink `symlink.txt` creado con `ln -s`. `ls -li` muestra **otro inodo**, tipo `l` y el target entre flechas.
4. Edición vía el hardlink: el cambio es visible desde cualquier nombre (es el mismo contenido).
5. Borrado del original: el hardlink **sigue funcionando** (nlink pasa de 2 a 1); el symlink **queda roto** (dangling).
6. `readlink` sobre el symlink muestra el target literal, aunque ya no exista.

## Interpretación

- Hardlinks hacen imposible saber cuál era "el original" — son todos iguales. El sistema de archivos cuenta cuántos nombres apuntan al inodo; libera el espacio cuando el último desaparece.
- Symlinks son solo una ruta guardada en el inodo tipo `l`. Si el target cambia de nombre o desaparece, el symlink no se entera.
- Un symlink puede apuntar a algo que todavía no existe (y empezar a funcionar cuando aparezca). Un hardlink no.

## Errores frecuentes

- Intentar hacer un hardlink a un directorio (`ln dir1 dir2`): falla por diseño. Usa symlink.
- Intentar un hardlink entre filesystems distintos: `ln: failed to create hard link ...: Invalid cross-device link`. Usa symlink o copia.
- Usar `ls -l` esperando ver el inodo: la columna de inodo solo aparece con `-i`. Usa `ls -li`.

## Relación con escenarios reales

- Los backups incrementales de `rsync --link-dest` y herramientas tipo `restic`/`borg` usan hardlinks masivamente para no duplicar bytes entre snapshots.
- `/usr/bin/python3` → `python3.11` es un symlink: te permite actualizar la versión menor sin romper scripts que invocan `python3`.
- Si `du` reporta "más" que `df` o viceversa, muchas veces es por hardlinks contados varias veces.

## Limpieza

```bash
rm -rf /tmp/links-demo
```
