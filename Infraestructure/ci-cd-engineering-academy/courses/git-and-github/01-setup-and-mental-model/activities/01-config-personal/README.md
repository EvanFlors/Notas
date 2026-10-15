# Actividad 01 — Configuración global sana de Git

## 1. Identificación

- **ID:** `gh-01-01-config-personal`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-01-setup-and-mental-model`
- **Dificultad:** beginner
- **Duración estimada:** 20–30 min
- **Tipo:** guided-lab

## 2. Contexto

Un ingeniero senior configura su Git el día que recibe su laptop nueva. Esta decisión repercute en años de productividad y limpieza de historia. Un ingeniero junior lo hace cuando ya es tarde. Esta actividad te hace pasar por eso **ahora**, no después.

## 3. Objetivos

Al terminar deberías poder:

- Configurar identidad global y verificarla.
- Explicar por qué cada opción recomendada se recomienda.
- Elegir `core.autocrlf` correctamente para tu SO.
- Configurar un credential helper apropiado para tu SO.
- Validar la configuración ejecutando el test incluido.

## 4. Prerrequisitos

- Git ≥ 2.30 instalado (`git --version`).
- Permiso de escritura en `~/.gitconfig`.
- Un editor instalado (al menos `nano`; recomendado: `code` de VS Code, `vim`, o `emacs`).
- Opcional: cuenta de GitHub si vas a probar credential helper con un remote real (no obligatorio para esta actividad).

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Verificar instalación y versión

```bash
git --version
# >= 2.30 esperado. Si es < 2.30, actualiza antes de continuar.
```

### 5.2 Backup de tu `.gitconfig` actual (si existe)

```bash
if [ -f ~/.gitconfig ]; then
  cp ~/.gitconfig ~/.gitconfig.backup.$(date +%Y%m%d%H%M%S)
  echo "Backup creado en ~/.gitconfig.backup.*"
else
  echo "No hay ~/.gitconfig previo. Se creará uno nuevo."
fi
```

### 5.3 Aplicar configuración

Reemplaza los placeholders con tus datos reales.

```bash
# Identidad (OBLIGATORIO)
git config --global user.name "Tu Nombre"
git config --global user.email "tu-email@dominio.com"

# Default branch
git config --global init.defaultBranch main

# Pull con rebase (evita merge commits ruidosos)
git config --global pull.rebase true

# Push sencillo
git config --global push.default simple
git config --global push.autoSetupRemote true

# Line endings — ELIGE según tu SO:
#   macOS/Linux:
git config --global core.autocrlf input
#   Windows (PowerShell/Git Bash):
# git config --global core.autocrlf true

# Editor — ELIGE uno:
git config --global core.editor "nano"
# o: git config --global core.editor "code --wait"
# o: git config --global core.editor "vim"

# UX
git config --global color.ui auto
git config --global rebase.autoStash true

# Credential helper — ELIGE según tu SO:
#   macOS:
# git config --global credential.helper osxkeychain
#   Linux (gnome-libsecret recomendado si está instalado):
# git config --global credential.helper libsecret
#   Linux fallback:
# git config --global credential.helper 'cache --timeout=3600'
#   Windows:
# git config --global credential.helper manager
```

### 5.4 Validar

Ejecuta el test incluido (asume Bash):

```bash
bash tests/validate.sh
```

Debe terminar con `OK: configuración mínima correcta`.

Si algún check falla, el script te dirá qué configurar.

### 5.5 Inspeccionar el archivo generado

```bash
cat ~/.gitconfig
```

Deberías ver secciones `[user]`, `[init]`, `[pull]`, etc. Lee el archivo entero — es *tu* contrato con Git para los próximos años.

## 6. Resultado esperado

- `~/.gitconfig` existe y contiene al menos:
  - `[user]` con `name` y `email`.
  - `[init]` con `defaultBranch = main`.
  - `[pull]` con `rebase = true`.
  - `[core]` con `autocrlf` definido.
  - `[credential]` con `helper` definido.
- `tests/validate.sh` pasa con `OK`.
- Un `git init` en una carpeta nueva usa `main` como rama default (verificable con `git init /tmp/test-init && cat /tmp/test-init/.git/HEAD`).

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: identidad configurada, defaults aplicados.
- [ ] **Calidad**: valores sensatos (no email vacío, no `user.name "root"`).
- [ ] **Seguridad**: credential helper configurado para no cachear en texto plano.
- [ ] **Reproducibilidad**: `~/.gitconfig` se puede re-aplicar desde documentación.
- [ ] **Mantenibilidad**: cualquier colega podría leer `~/.gitconfig` y entender.

## 8. Validación

```bash
bash tests/validate.sh
```

El script verifica cada opción esperada y reporta las que faltan o están mal.

## 9. Preguntas de reflexión

Responde (puedes escribir en `starter/notes.md`):

1. ¿Por qué `pull.rebase=true` suele ser preferible a `pull.rebase=false` en equipos activos? Da un ejemplo concreto de qué pasa en la historia si usas uno u otro.
2. ¿Cuál es la diferencia entre `core.autocrlf input` y `core.autocrlf true`? ¿Qué pasaría si un dev Linux configura `true` y un dev Windows configura `input`?
3. ¿Cuál es la diferencia entre `--system`, `--global`, `--local` en `git config`? ¿Cuál gana si definen la misma clave?
4. ¿Qué pasa si no configuras `init.defaultBranch`? ¿Qué default usa tu versión de Git? (verifica con `git init /tmp/x && cat /tmp/x/.git/HEAD && rm -rf /tmp/x`).
5. ¿Por qué `credential.helper` nunca debe ser `store` en texto plano?

## 10. Extensiones (opcional)

- **E1** — Añade al menos 3 **aliases** útiles (`git config --global alias.co checkout`, `alias.st status`, `alias.lg "log --graph --oneline --all"`). Verifica con `git lg` en un repo con historia.
- **E2** — Configura **GPG** o **SSH signing** para firmar commits (se profundiza en `gh-13`, pero intenta ahora: `git config --global commit.gpgsign true` + llave).
- **E3** — Agrega una **plantilla de commit message** (`git config --global commit.template ~/.gitmessage.txt`) con la estructura de *Conventional Commits*.
- **E4** — Crea un pequeño script `~/.local/bin/git-sync` y descubre que Git lo reconoce como `git sync` automáticamente (sub-comandos custom).

## 11. Limpieza

Si quieres revertir completamente:

```bash
# Si guardaste backup
mv ~/.gitconfig.backup.<timestamp> ~/.gitconfig

# O eliminar todo lo configurado
rm ~/.gitconfig
```

Normalmente **no quieres limpiar** — esta configuración es permanente por diseño.
