# 15 escenarios — elegir operador y wrapper

Rellena `operator:` y `wrapper:` en cada escenario. No ejecutes nada.

---

## 1

Comprobar si `/etc/passwd` existe y es un archivo regular (no directorio ni symlink).

- operator:
- wrapper:

## 2

Comprobar si la variable `$RESPUESTA` está vacía.

- operator:
- wrapper:

## 3

Comprobar que un número entero contenido en `$CODE` es igual a `0`.

- operator:
- wrapper:

## 4

Comprobar si el nombre de archivo en `$f` termina en `.log` (sin usar regex).

- operator:
- wrapper:

## 5

Comprobar si la línea en `$linea` empieza por `ERROR:` seguido de cualquier cosa, capturando el resto en un grupo.

- operator:
- wrapper:

## 6

Comprobar si el usuario puede escribir en el directorio `/var/log/myapp/`.

- operator:
- wrapper:

## 7

Comprobar si el porcentaje entero `$uso` es mayor o igual a 90.

- operator:
- wrapper:

## 8

Comprobar si `$ARCHIVO_A` es más nuevo que `$ARCHIVO_B` por fecha de modificación.

- operator:
- wrapper:

## 9

Comprobar si `$ENV` tiene exactamente el string `"prod"`.

- operator:
- wrapper:

## 10

Comprobar si el archivo en `$f` existe y tiene tamaño mayor a cero.

- operator:
- wrapper:

## 11

Comprobar si el string `$version` es distinto de `"1.0.0"`.

- operator:
- wrapper:

## 12

Comprobar si `$path` es un enlace simbólico (resuelto o roto).

- operator:
- wrapper:

## 13

Comprobar si el entero `$pid` es diferente de cero usando sintaxis aritmética idiomática (no `-ne`).

- operator:
- wrapper:

## 14

Comprobar que `$input` sólo contenga dígitos.

- operator:
- wrapper:

## 15

Script `#!/bin/sh` POSIX puro: comprobar que `$HOME` existe como directorio.

- operator:
- wrapper:
