# Solución de referencia — `01-config-personal`

> **No consultes este directorio hasta haber intentado la actividad.**

El script `apply-config.sh` aplica una configuración mínima sana por SO.

## Uso

```bash
./apply-config.sh "Tu Nombre" "tu@email.com"
# Opcional:
EDITOR_CMD="code --wait" ./apply-config.sh "Tu Nombre" "tu@email.com"
```

## Decisiones y justificación

| Opción | Valor | Por qué |
|--------|-------|---------|
| `user.name` / `user.email` | tus datos reales | Obligatorio para crear commits atribuibles. |
| `init.defaultBranch` | `main` | Default moderno; evita `master`. |
| `pull.rebase` | `true` | Evita merge commits ruidosos; historia lineal más legible. |
| `push.default` | `simple` | Push solo la rama actual; sin sorpresas. |
| `push.autoSetupRemote` | `true` | Primer push a una rama nueva no requiere `-u`. |
| `rebase.autoStash` | `true` | `pull --rebase` no falla si hay cambios locales. |
| `color.ui` | `auto` | Mejor UX en terminal interactiva. |
| `core.editor` | `nano` (ajustable) | Editor por default para mensajes de commit. |
| `core.autocrlf` | `input` (Linux/mac) / `true` (Windows) | Normaliza line endings entre OS. |
| `credential.helper` | nativo del SO | Evita almacenar tokens en texto plano. |

## Respuestas a reflexión

**P1 (pull.rebase true vs false).** Con `false`, cada `pull` cuando hay cambios locales + remotos crea un `Merge branch 'main' of ...`. En equipos activos, la historia se llena de merges automáticos sin aporte semántico. Con `true`, tus cambios locales se rebasan encima del remoto — historia lineal, legible. Para proyectos muy jerárquicos (p. ej. GitFlow estricto) algunos equipos prefieren `false` por trazabilidad explícita; es una decisión *de equipo*.

**P2 (core.autocrlf).** `input`: al commit convierte CRLF → LF, al checkout deja LF. `true`: al commit convierte CRLF → LF, al checkout convierte LF → CRLF (para Windows). Si un dev Linux usa `true`, está pidiendo CRLF al checkout — introduce basura. Si un dev Windows usa `input`, mantendrá LF en el working tree (editores Windows modernos lo manejan). La vía más robusta a nivel equipo es un `.gitattributes` del repo con `* text=auto` y pins específicos.

**P3 (scopes).** `--system` (todo usuario del host, `/etc/gitconfig`), `--global` (todo repo del usuario actual, `~/.gitconfig`), `--local` (solo el repo actual, `.git/config`). Precedence: `local > global > system`. `--worktree` existe como nivel adicional.

**P4 (init.defaultBranch default).** Depende de la versión de Git. Hasta cierto momento era `master`; a partir de ~2.28 Git comenzó a sugerir configurarlo explícitamente; en entornos nuevos muchas distros ya traen `main` por default, pero no todas. **Explícito > implícito**.

**P5 (credential.helper store).** `store` escribe tokens en `~/.git-credentials` en texto plano. Cualquier proceso con acceso al home puede leerlos. En múltiples incidentes históricos, backups de HOME expusieron tokens. Siempre preferir keystore nativo (osxkeychain, libsecret, Windows Credential Manager) o al menos `cache` con TTL corto.
