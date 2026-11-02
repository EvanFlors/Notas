# Ejemplo 02 — El mismo menú en `dialog`, `whiptail` y `zenity`

Tres implementaciones del **mismo** menú de 3 opciones (`Estado`, `Logs`, `Reiniciar`), para que compares API, salida y requisitos lado a lado.

## Archivos

| Archivo | Backend | Dependencia | Contexto típico |
|---------|---------|-------------|-----------------|
| `files/dialog-menu.sh` | `dialog` | paquete `dialog` | Servidor con terminal, SSH, container con TUI. |
| `files/whiptail-menu.sh` | `whiptail` | paquete `whiptail` (Debian/Ubuntu de serie) | Instaladores netinst, Alpine, entornos mínimos. |
| `files/zenity-menu.sh` | `zenity` | paquete `zenity` + `$DISPLAY` | Desktop GTK, operadores con sesión gráfica. |

## Qué comparar al leerlos

1. **Captura de la respuesta.** `dialog --stdout` vs. el truco clásico `3>&1 1>&2 2>&3` vs. `zenity` que ya devuelve en stdout.
2. **Exit codes.** Los tres distinguen OK (0), Cancel (1) y Esc (255 en dialog/whiptail; 1 en zenity).
3. **Verificación de dependencia.** Todos empiezan con `command -v BACKEND >/dev/null || exit 2`.
4. **Verificación de contexto.** Solo `zenity-menu.sh` chequea `$DISPLAY`/`$WAYLAND_DISPLAY` — los otros chequean `[[ -t 1 ]]`.

## Ejecutarlos

Si no tienes alguno instalado, instala el paquete homónimo (o lee el script sin ejecutarlo):

```bash
# Debian/Ubuntu
sudo apt install dialog whiptail zenity

# Fedora/RHEL
sudo dnf install dialog newt zenity

# Alpine
sudo apk add dialog newt zenity
```

Luego:

```bash
bash files/dialog-menu.sh
bash files/whiptail-menu.sh
bash files/zenity-menu.sh    # requiere sesión gráfica
```

## Conclusión práctica

- `dialog` es la elección por defecto para TUIs ncurses "serias".
- `whiptail` es el fallback cuando `dialog` no está disponible y necesitas algo mejor que `select`.
- `zenity` es un nicho (desktop); en servidores suele ser antipatrón.
