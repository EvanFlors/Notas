# Ejemplo 02 — `dnf history` y rollback de una transacción

## Concepto que demuestra

El historial transaccional de `dnf` y cómo deshacer una transacción concreta con `dnf history undo`. Es el superpoder operativo de la familia RHEL frente a Debian.

## Contexto

Un paquete acabamos de instalar/actualizar y queremos **volver atrás exactamente al estado anterior**, no "más o menos atrás".

## Objetivo

Al terminar, podrás responder:

- ¿Qué guarda realmente `dnf history`?
- ¿Qué hace `dnf history undo <id>` paso a paso?
- ¿En qué casos puede fallar el undo?

## Prerrequisitos

- **VM o contenedor Rocky 9 / Alma 9 / Fedora 41+** con `sudo`. **No en producción.**
  - Contenedor rápido: `docker run --rm -it rockylinux:9 bash`.
- Comandos: `dnf` (o `dnf5` en Fedora reciente), `rpm`.
- Red con acceso a los repos oficiales.

## Ejecución

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Ver el historial actual (en una VM fresca saldrán 1-2 transacciones de instalación base)
sudo dnf history

# 2. Instalar un paquete pequeño e inocuo (zsh)
sudo dnf install -y zsh

# 3. Ver el historial de nuevo: aparece una nueva entrada
sudo dnf history | head -5

# 4. Mirar los detalles de la última transacción
LAST_ID=$(sudo dnf history | awk 'NR==3 {print $1}')
echo "Última transacción: ID=${LAST_ID}"
sudo dnf history info "${LAST_ID}"
# Muestra: Command Line, qué paquetes se añadieron/subieron, usuario,
# RPMDB versions antes/después.

# 5. Verificar que zsh está presente
rpm -q zsh
which zsh

# 6. Deshacer la transacción
sudo dnf history undo -y "${LAST_ID}"

# 7. Confirmar que zsh ya no está
rpm -q zsh || echo "zsh ya no está instalado — rollback OK"

# 8. El historial conserva el registro, y además añade la nueva entrada "Undo"
sudo dnf history | head -5
```

## Qué deberías observar

- `dnf history info N` muestra con precisión qué paquetes y versiones movió la transacción.
- Tras `undo`, el estado es equivalente al de antes de la transacción (dentro de las limitaciones: ver más abajo).
- El propio `undo` queda registrado como una nueva transacción. Puedes "undo del undo".

## Limitaciones del rollback

`dnf history undo` **puede fallar** si:

1. **El paquete anterior ya no existe en los repos.** `undo` necesita *reinstalar* la versión que había antes de un upgrade; si el repo solo guarda la última, no hay dónde sacarla.
   - Mitigación: mirror interno que preserve versiones, o caché local (`keepcache=True` en `/etc/dnf/dnf.conf`).
2. **Dependencias nuevas que llegaron después hacen imposible volver.** Si entre tanto instalaste otro paquete que depende de la versión *nueva*, bajarla rompería ese otro paquete. dnf te lo dirá; tendrás que decidir.
3. **Scripts post-install irreversibles** (migraciones de BD, por ejemplo). dnf devuelve el binario a la versión anterior, pero si el paquete nuevo migró el esquema de datos, ese cambio no se revierte por bajar el RPM.

Por eso en producción el patrón es `dnf history undo` **más** snapshot de filesystem (btrfs/LVM/ZFS). dnf cubre el 90% de casos; el snapshot cubre el 10% restante y el escenario catastrófico "ni siquiera arranca".

## Dónde vive el historial

```bash
sudo ls -la /var/lib/dnf/history/
# Son SQLite databases: puedes abrirlas con sqlite3 si tienes curiosidad.
```

En Fedora 41+ con `dnf5` la ruta cambia a `/var/lib/dnf5/`, pero el modelo es el mismo.

## Enlaces

- `dnf history` reference: <https://dnf.readthedocs.io/en/latest/command_ref.html#history-command-label>
- `dnf5` docs: <https://dnf5.readthedocs.io/>
