# Escenario — Rollback de un upgrade

## Setup

Estás en una VM/contenedor Rocky/Alma/Fedora recién creada. Vas a:

1. Instalar `zsh` (lo usamos como *stand-in* del "paquete problemático"; es inocuo).
2. Ver el historial para localizar la transacción.
3. Revertirla con `dnf history undo`.
4. Confirmar que `zsh` ya no está instalado.

En producción real, el "paquete problemático" sería tu motor de BD, tu servidor web, tu agente de monitorización, etc. El procedimiento es idéntico.

## Pasos

### 1. Verificar entorno

```bash
. /etc/os-release && echo "${PRETTY_NAME}"
sudo -v
command -v dnf
```

### 2. Estado inicial del historial

```bash
sudo dnf history | head -10
```

Fíjate en el formato de columnas: `ID | Command line | Date and time | Action(s) | Altered`.

### 3. Reproducir el "cambio problemático"

```bash
sudo dnf install -y zsh
rpm -q zsh
which zsh
```

### 4. Localizar la transacción

```bash
sudo dnf history | head -5
```

Anota el `ID` de la transacción recién creada (la primera después de la cabecera).

### 5. Inspeccionarla

```bash
sudo dnf history info <ID>
```

Observa:

- `Command Line`: `install -y zsh` (así es como quedó registrado tu comando).
- `Packages Altered`: línea tipo `Install zsh-<version>.<arch>`.
- `RPMDB versions`: hashes antes/después (snapshot lógico de la BD de rpm).

### 6. Decidir si `undo` es viable

Pregúntate:

- ¿El repo todavía ofrece la versión anterior? (Para una *instalación*, "versión anterior" = ninguna, así que el undo simplemente desinstala. Trivial.)
- ¿Hay dependencias nuevas que lleguen a estar en uso? (En este laboratorio no, pero en producción piensa qué más instalaste después).

### 7. Aplicar el `undo`

```bash
sudo dnf history undo -y <ID>
```

### 8. Validar

```bash
rpm -q zsh || echo "OK: zsh ya no está instalado"
sudo dnf history | head -5
# La nueva entrada arriba será tipo "history undo <ID>" con Action(s) incluyendo "Removed".
```

### 9. Test automático

```bash
bash tests/validate.sh
```

## Reflexión obligatoria

Antes de dar por cerrada la actividad, responde en una línea (en tus notas):

> **¿En qué condición concreta `dnf history undo` fallaría, y qué harías entonces?**

Pista: piensa en un upgrade de 2.0 → 3.0 donde el repo solo publica 3.0 desde hace un mes.
