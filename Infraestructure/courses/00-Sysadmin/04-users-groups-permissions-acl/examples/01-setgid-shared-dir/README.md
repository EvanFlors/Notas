# Ejemplo 01 — Directorio compartido con setgid + ACL default

## Qué muestra

Cómo construir `/srv/team` para que los miembros del grupo `developers`:

- Puedan leer y escribir todo lo del directorio.
- Vean que los archivos **nuevos** heredan el grupo `developers` (gracias al bit **setgid** en el directorio).
- Vean que los archivos **nuevos** también heredan permisos `rw-` para el grupo (gracias a una **default ACL**), sin depender del `umask` de cada usuario.

Es el patrón canónico de un directorio de trabajo compartido en Unix.

## Requisitos

- VM Linux descartable (no lo pruebes en tu máquina de trabajo: crea usuarios/grupos).
- `acl` instalado (`apt install acl` / `dnf install acl`).
- Acceso `sudo` o shell root.

## Ejecutar

```bash
cd files/
sudo bash setup.sh
```

El script:

1. Crea el grupo `developers` si no existe.
2. Crea usuarios de prueba `ana` y `diego` (sin contraseña, shell `/bin/bash`), los mete en el grupo.
3. Crea `/srv/team` con dueño `root:developers`, modo `2770` (setgid + rwx para grupo).
4. Aplica una default ACL: `g:developers:rwx` para que los archivos nuevos la hereden.
5. Prueba creando un archivo como `ana` y muestra sus permisos.

## Qué observar

Al final de la ejecución:

```
drwxrws---+ 2 root developers 4096 ... /srv/team
```

- La `s` donde iba la `x` del grupo → setgid activo.
- El `+` al final → hay ACL extendida.

```
-rw-rw----+ 1 ana developers 0 ... /srv/team/hola.txt
```

- Grupo `developers` heredado del directorio (no `ana`).
- `rw` para el grupo heredado de la default ACL (no del `umask 0022` del sistema).

## Limpiar

```bash
sudo rm -rf /srv/team
sudo userdel -r ana  2>/dev/null || true
sudo userdel -r diego 2>/dev/null || true
sudo groupdel developers 2>/dev/null || true
```

## Variación: sin setgid

Reproduce el script quitando el `2` del `chmod` (deja `0770`). Verás que `hola.txt` queda con grupo `ana`, y `diego` no puede escribirlo. Esa es la razón de ser del bit setgid en directorios.
