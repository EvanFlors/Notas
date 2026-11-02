# Scripts interactivos: `read`, `select`, `dialog`/`whiptail`, `zenity`

> Esta lección es la frontera entre "scripts que se ejecutan solos" y "scripts que negocian con un humano". Casi todos los bugs operacionales graves ocurren en esa frontera: un script interactivo invocado desde cron que se queda esperando `read`, un instalador GTK ejecutado por SSH sin `DISPLAY`, un `rm -rf` detrás de un `read` que nadie leyó.

## Índice

1. ¿Cuándo un script debe ser interactivo?
2. El builtin `read`: la base de todo
3. El builtin `select`: menús TUI sin dependencias
4. `dialog` y `whiptail`: TUIs ncurses "serias"
5. `zenity`: GUIs GTK para contexto desktop
6. Matriz de selección de herramienta
7. Detección de contexto: TTY, pipe, cron, SSH, CI
8. El patrón **dual-mode**: flags cuando se puede, prompt cuando no
9. Confirmaciones defensivas y accesibilidad
10. Antipatrones y preguntas de evaluación

---

## 1. ¿Cuándo un script debe ser interactivo?

La regla operacional de este curso:

> Un script de producción **no pregunta nada**. Un runbook de operador **pregunta todo lo que no puede inferir con seguridad**. Un script instalador **pregunta solo si se ejecuta a mano y faltan datos**.

Tres contextos típicos:

| Contexto | ¿Puede preguntar? | Por qué |
|----------|-------------------|---------|
| CI / CD (GitHub Actions, GitLab, Jenkins) | No | No hay TTY; `read` cuelga indefinidamente o devuelve EOF al primer intento. |
| `cron` / `systemd timer` | No | Igual que CI: no hay stdin interactivo. Además, no hay nadie para contestar. |
| SSH no interactivo (`ssh host "comando"`) | No | Mismo caso, pero más peligroso: a veces hay un pseudo-TTY, a veces no, según flags (`-t`, `-tt`, `-T`). |
| Sesión interactiva local o `ssh -t` | Sí | TTY presente, humano frente al teclado. |
| Doble clic en entorno gráfico (poco común en sysadmin) | Sí, GUI | No hay terminal; solo tiene sentido GUI (`zenity`, `kdialog`). |

Un script bien hecho **detecta el contexto** (sección 7) y actúa en consecuencia, en lugar de asumir.

---

## 2. El builtin `read`: la base de todo

`read` es un builtin de Bash (no un programa externo). Lee una línea de stdin, la divide por `IFS` y la asigna a variables. Es la base de **todo** input interactivo en shell.

### 2.1 Forma mínima

```bash
read -r nombre
echo "Hola, $nombre"
```

**Regla #1: usa siempre `-r`.** Sin `-r`, `read` interpreta `\` como escape y come backslashes legítimos. No hay caso realista en que quieras ese comportamiento.

### 2.2 Prompt en la misma línea: `-p`

```bash
read -r -p "Nombre: " nombre
```

Evita el `echo -n "Nombre: "; read -r nombre` manual. El prompt se escribe a stderr, no a stdout: compatible con pipes.

### 2.3 Contraseñas: `-s`

```bash
read -r -s -p "Password: " pass
echo    # salto de línea manual, porque -s suprime el eco incluido el Enter
```

Nunca uses `-p` sin `-s` para secretos. Y nunca pases secretos como argumento (`./script.sh --password=X`): quedan en `ps`, en el historial y en logs. Pide por stdin o lee de un archivo con permisos `0600`.

### 2.4 Timeout: `-t`

```bash
if read -r -t 10 -p "¿Continuar en 10 s (y/N)? " ans; then
  :
else
  echo "Timeout: asumiendo 'no'"
  ans="n"
fi
```

Si el usuario no responde en `N` segundos, `read` retorna un exit code > 128 y la variable queda vacía. Útil para "si nadie contesta, asumir default seguro".

### 2.5 Un solo carácter: `-n 1`

```bash
read -r -n 1 -p "¿Continuar (y/N)? " ans
echo
```

No requiere Enter: el usuario pulsa `y` y el script sigue. Combínalo con `-s` para capturas tipo "pulsa cualquier tecla".

### 2.6 Arrays: `-a`

```bash
read -r -a servers -p "Lista de hosts separados por espacio: "
for s in "${servers[@]}"; do ssh "$s" uptime; done
```

Separa por `IFS` (espacio/tab/newline por defecto). Si quieres separar por coma, cambia `IFS` localmente:

```bash
IFS=',' read -r -a servers <<< "web1,web2,web3"
```

### 2.7 Leer de un archivo línea a línea

El idiom canónico, con todas las defensas activadas:

```bash
while IFS= read -r line; do
  printf '%s\n' "$line"
done < input.txt
```

- `IFS=` evita que se recorten espacios iniciales/finales.
- `-r` evita interpretar backslashes.
- `printf` en vez de `echo` evita problemas con líneas que empiezan por `-`.

### 2.8 Trampas comunes

- `read -p "x" var | foo` ejecuta `read` en un **subshell** por el pipe → `var` queda vacía en el shell padre. Reestructura con process substitution: `read -p "x" var < <(something)`.
- `cat file | while read -r line; do …; done` tiene el mismo problema con cualquier variable que modifiques en el loop. Prefiere `while read -r line; do …; done < file`.
- Si el stdin ya está consumido (ej. `curl … | bash`), `read` leerá del pipe, no del teclado. Redirige explícitamente: `read -r ans < /dev/tty`.

---

## 3. El builtin `select`: menús TUI sin dependencias

`select` es un builtin olvidado pero poderoso. Dibuja un menú numerado y vuelve a mostrarlo hasta que el usuario sale del loop (`break`) o `read` recibe EOF.

### 3.1 Esqueleto

```bash
PS3="Elige una opción> "
options=("Estado" "Logs" "Reiniciar" "Salir")
select opt in "${options[@]}"; do
  case "$REPLY" in
    1) systemctl status nginx ;;
    2) journalctl -u nginx -n 50 ;;
    3) sudo systemctl restart nginx ;;
    4) break ;;
    *) echo "Opción inválida: $REPLY" ;;
  esac
done
```

- `PS3` es el prompt del menú (no `PS1`).
- `$REPLY` tiene el número tecleado literal; `$opt` tiene el string correspondiente (vacío si inválido).
- Si el usuario pulsa Enter sin escribir nada, `select` **repinta** el menú (útil).

### 3.2 Ventajas y límites

**Ventajas:** cero dependencias, portable, funciona por SSH, legible.

**Límites:** no hay checklists, radios ni gauges. Si necesitas más de un menú lineal, es momento de `dialog`/`whiptail`.

---

## 4. `dialog` y `whiptail`: TUIs ncurses "serias"

Ambas dibujan diálogos ncurses sobre el terminal y devuelven la respuesta por **stderr** (o por el exit code). Son casi intercambiables; `whiptail` viene con `newt` (Debian/Ubuntu base, muy ligero), `dialog` tiene más widgets.

### 4.1 El idiom que resuelve todo

```bash
answer=$(dialog --stdout --inputbox "Directorio destino:" 8 50 "/opt/app")
```

- `--stdout` redirige la respuesta a stdout (más fácil de capturar que `3>&1 1>&2 2>&3`).
- Exit code: `0` = OK, `1` = Cancel, `255` = Esc.

Siempre comprueba el exit code **antes** de usar la respuesta:

```bash
if ! answer=$(dialog --stdout --inputbox "Dir:" 8 50 "/opt/app"); then
  echo "Cancelado por el usuario."; exit 1
fi
```

### 4.2 Widgets más útiles

| Widget | Caso de uso |
|--------|-------------|
| `--yesno "Texto" H W` | Confirmación. Exit code 0=Sí, 1=No. |
| `--inputbox "Texto" H W [default]` | Texto libre. |
| `--passwordbox "Texto" H W` | Contraseña (sin eco). |
| `--menu "Texto" H W menuH tag item ...` | Menú lineal. |
| `--checklist "Texto" H W listH tag item status ...` | Selección múltiple. |
| `--radiolist ...` | Selección única con radios. |
| `--gauge "Texto" H W [percent]` | Barra de progreso: lee porcentajes por stdin. |
| `--infobox "Texto" H W` | Mensaje sin botones, no bloquea. |
| `--msgbox "Texto" H W` | Mensaje con botón OK. |

### 4.3 Barra de progreso con `--gauge`

```bash
(
  echo 10; sleep 1
  echo 40; sleep 1
  echo 80; sleep 1
  echo 100
) | dialog --gauge "Instalando..." 7 60 0
```

Cada número por stdin actualiza el porcentaje. Opcionalmente, líneas `XXX\nN\nmensaje\nXXX` cambian también el texto.

### 4.4 `dialog` vs `whiptail`: diferencias prácticas

| Rasgo | `dialog` | `whiptail` |
|-------|----------|------------|
| Paquete típico | `dialog` | `whiptail` (en `newt`) |
| Peso | Más grande, más widgets | Mínimo |
| Flag canónico para salida | `--stdout` o `3>&1 1>&2 2>&3` | `3>&1 1>&2 2>&3` |
| Soporte de `--gauge` | Sí, completo | Sí, básico |
| Soporte de `--form` | Sí | No |
| Colores por defecto | Azul clásico | Rojo/gris |

Para portabilidad, muchos scripts hacen:

```bash
if command -v whiptail >/dev/null; then DIALOG=whiptail
elif command -v dialog >/dev/null; then DIALOG=dialog
else DIALOG=""
fi
```

y usan `$DIALOG` como abstracción (asumiendo subset común). Para widgets avanzados (`--form`, `--editbox`), elige `dialog` y declara la dependencia.

---

## 5. `zenity`: GUIs GTK para contexto desktop

`zenity` abre ventanas GTK reales. Útil cuando el script lo ejecuta un usuario en entorno gráfico (ej. un técnico de soporte con un ícono en el escritorio), **inútil** en servidores headless.

```bash
dir=$(zenity --file-selection --directory --title="Elige destino")
zenity --question --text="¿Instalar en $dir?" || exit 1
(
  for i in 10 40 70 100; do echo "$i"; sleep 1; done
) | zenity --progress --title="Instalando" --auto-close
```

Reglas:

- Requiere `DISPLAY` o `WAYLAND_DISPLAY`. Comprueba antes:

  ```bash
  if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "No hay sesión gráfica; usando prompts de texto." >&2
    use_zenity=0
  fi
  ```

- En SSH requiere `-X` o `-Y` + `xauth` configurado.
- No lo uses como UI principal en scripts de sysadmin "normales". Reserva para `kdialog`/`zenity` cuando el entregable es un `.desktop` o un launcher.

---

## 6. Matriz de selección de herramienta

| Necesidad | Elige | Por qué |
|-----------|-------|---------|
| Un prompt simple ("¿seguro?") en script sysadmin | `read -r -p` | Cero dependencias, portable incluso en `sh`. |
| Menú lineal de 3–10 opciones, SSH friendly | `select` | Builtin, sin dependencias, legible. |
| Checklist, radios, gauge, forms sobre terminal | `dialog` | Widget set más completo; `whiptail` como fallback si `dialog` falta. |
| Menú ncurses mínimo donde `dialog` no está disponible (Debian netinst, Alpine) | `whiptail` | Mínimo, suele venir de serie. |
| Script invocado desde escritorio gráfico, sin terminal | `zenity` | GUI nativa, UX decente para operadores no-técnicos. |
| Contraseñas | `read -r -s` (o `dialog --passwordbox`) | Nunca por `--flag=`. |
| Script invocado por cron, CI o pipe | **Ningún prompt** | Falla rápido con mensaje claro si falta un dato obligatorio. |

Jerarquía mental: **`read`/`select` → `whiptail` → `dialog` → `zenity`**, de menos a más dependencias de entorno. Sube un nivel solo cuando el anterior no alcanza.

---

## 7. Detección de contexto: TTY, pipe, cron, SSH, CI

Antes de preguntar nada, pregúntate si puedes.

### 7.1 ¿Hay un TTY?

```bash
if [[ -t 0 ]]; then
  echo "stdin es un TTY; puedo pedir input."
else
  echo "stdin no es TTY (pipe, cron, CI...)."
fi
```

- `[[ -t 0 ]]` → stdin es TTY.
- `[[ -t 1 ]]` → stdout es TTY (útil para decidir si usar colores).
- `[[ -t 2 ]]` → stderr es TTY.

### 7.2 ¿Hay un display gráfico?

```bash
[[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && have_gui=1 || have_gui=0
```

### 7.3 ¿Estamos en CI?

Convención: la mayoría de proveedores exportan `CI=true`. Chequea también `GITHUB_ACTIONS`, `GITLAB_CI`, `JENKINS_URL` si quieres ser específico.

```bash
if [[ "${CI:-}" == "true" ]]; then
  INTERACTIVE=0
fi
```

### 7.4 Receta canónica

```bash
is_interactive() {
  [[ -t 0 && -t 1 ]] && [[ "${CI:-}" != "true" ]]
}

if is_interactive; then
  read -r -p "Nombre: " nombre
else
  : "${NOMBRE:?NOMBRE no definido y stdin no es interactivo}"
  nombre="$NOMBRE"
fi
```

Si no hay humano y falta un dato, **falla rápido** con mensaje claro. No cuelgues esperando lo imposible.

---

## 8. El patrón **dual-mode**: flags cuando se puede, prompt cuando no

Un buen script sysadmin es **dos UIs sobre la misma lógica**:

1. CLI con flags → automatizable, scriptable, CI-friendly.
2. Prompt interactivo → humano-friendly, rellena los huecos.

Esqueleto:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Uso: $0 [--target DIR] [--components a,b,c] [--yes] [--non-interactive]
EOF
}

target=""
components=""
assume_yes=0
non_interactive=0

while (($#)); do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --components) components="$2"; shift 2 ;;
    --yes|-y) assume_yes=1; shift ;;
    --non-interactive) non_interactive=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconocido: $1" >&2; usage; exit 2 ;;
  esac
done

is_interactive() { [[ -t 0 && -t 1 && "${CI:-}" != "true" && $non_interactive -eq 0 ]]; }

# Rellenar huecos
if [[ -z "$target" ]]; then
  if is_interactive; then
    read -r -p "Directorio destino [/opt/app]: " target
    target="${target:-/opt/app}"
  else
    echo "Falta --target y no hay TTY" >&2; exit 2
  fi
fi

# Confirmar
if (( assume_yes == 0 )); then
  if is_interactive; then
    read -r -n 1 -p "Instalar en $target (y/N)? " ans; echo
    [[ "$ans" =~ ^[yY]$ ]] || { echo "Cancelado."; exit 1; }
  else
    echo "No hay TTY y no se pasó --yes; abortando." >&2; exit 2
  fi
fi

echo "Instalando en $target ..."
```

Características del patrón:

- Flags siempre ganan a prompts.
- Falta un dato + no hay TTY → **error, nunca cuelgue**.
- `--yes` existe explícitamente; nada se asume en CI.
- Mensajes de error apuntan al flag que faltó, no a "ingrese el valor".

---

## 9. Confirmaciones defensivas y accesibilidad

### 9.1 El default siempre es "no"

Para toda acción destructiva (borrar, sobrescribir, apagar, reiniciar), el `Enter` del usuario debe equivaler a **no**:

```bash
read -r -p "¿Borrar /var/data (y/N)? " ans
case "${ans,,}" in
  y|yes) : ;;
  *) echo "Cancelado."; exit 0 ;;
esac
```

- `${ans,,}` normaliza a minúsculas (Bash 4+).
- Enter vacío → no entra en `y|yes` → cancela.

Nunca escribas `(Y/n)` para una acción destructiva. "Yes por defecto" es un cuchillo con el filo hacia dentro.

### 9.2 Mensajes claros, sin jerga

- Mal: `Proceed? (y/n)`.
- Bien: `¿Borrar 42 archivos en /var/backups anteriores a 2024-01-01? (y/N):`.

El usuario tiene que saber **qué va a pasar** antes de pulsar `y`.

### 9.3 Accesibilidad

- Soporta `NO_COLOR=1`: desactiva colores si está exportada ([no-color.org](https://no-color.org)).
- Respeta `LANG`/`LC_MESSAGES`: no fuerces español si el entorno es inglés (en este curso los textos son españoles por decisión del autor; en producción, i18n).
- Para `dialog`/`whiptail`, el usuario puede tabular entre botones y usar Esc; no reasignes esas teclas.

### 9.4 Timeouts para operaciones peligrosas

```bash
if ! read -r -t 15 -p "Reiniciar en 15s. Enter cancela: " _; then
  echo "Timeout; reiniciando."; reboot
fi
```

Patrón `read -t` + default seguro: la ausencia del humano no debe producir el peor resultado.

---

## 10. Antipatrones y preguntas de evaluación

### 10.1 Antipatrones frecuentes

- **`read` sin `-r`.** Siempre bug latente.
- **`read` sin `-s` para contraseñas.** Secreto en pantalla y buffer de scroll.
- **Preguntas en scripts invocados por cron.** Cuelgue silencioso o fallo misterioso.
- **`zenity` sin fallback.** Script muere en un servidor headless.
- **`dialog`/`whiptail` sin exit code chequeado.** El usuario pulsa Cancel y el script usa un string vacío como "respuesta".
- **Default `Yes` en operaciones destructivas.** Enter → desastre.
- **Flags Y preguntas inconsistentes.** `--target /opt` y aún así pregunta "¿Dónde instalo?". Flags ganan.
- **Secretos como flags.** `./deploy.sh --password=X` → `ps aux`, history, logs.

### 10.2 Preguntas de evaluación

Responde sin consultar la lección:

1. ¿Qué devuelve `read -t 5 var` si pasan 5 s sin respuesta? ¿Cómo lo distingues de "respuesta vacía"?
2. ¿Por qué `cat file | while read -r l; do N=$((N+1)); done; echo $N` suele imprimir `0`?
3. Diseña una comprobación de 3 líneas que decida entre `dialog`, `whiptail` y `select` según lo disponible.
4. Un script instala una app en `/opt/app`. Debe correr en CI y a mano. Lista los **flags mínimos** que necesita para ser 100% no-interactivo.
5. ¿Por qué `zenity` sin comprobar `$DISPLAY` es un bug?
6. ¿Qué diferencia hay entre `[[ -t 0 ]]` y `[[ -t 1 ]]` y cuándo usarías cada uno?
7. Diseña una confirmación con timeout 10s que si no responde **no** haga la acción destructiva.
8. ¿Cuándo preferirías `whiptail` sobre `dialog`?

### 10.3 Lectura siguiente

- `sys-18-arguments-functions-and-arrays` — parseo robusto de los flags que aquí introducimos, y funciones reutilizables para prompts (`confirm`, `ask`, `pick`).
- `resources/links.md` — `dialog(1)`, `whiptail(1)`, `zenity(1)`, Bash manual.
