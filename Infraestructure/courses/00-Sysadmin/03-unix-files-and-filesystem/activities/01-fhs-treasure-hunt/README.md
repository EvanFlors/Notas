# Actividad 01 — FHS treasure hunt

## 1. Identificación

- **ID:** `sys-03-01-fhs-treasure-hunt`
- **Tecnología:** `linux-sysadmin`
- **Módulo:** `sys-03-unix-files-and-filesystem`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a recorrer un sistema Linux real respondiendo preguntas concretas sobre dónde vive cada cosa, qué tipo de archivo hay en cada punto, y qué expone el kernel. La idea no es memorizar el FHS: es que cuando mañana debas localizar la config de `sshd` o encontrar el log de un servicio, lo hagas sin googlear.

> **Importante**: necesitas un **sistema Linux** (laptop con Linux, VM, WSL2, o contenedor con `--privileged`). En macOS puro, muchas rutas (`/proc`, `/sys`, `/etc/os-release`) no existen o son distintas.

## 3. Objetivos

Al terminar deberías poder:

- Localizar sin consultar: config de un servicio, logs, binarios instalados por paquetes vs locales.
- Diferenciar operativamente `/etc` de `/var/lib`, `/tmp` de `/run`, `/usr/bin` de `/usr/local/bin`.
- Leer y entender la salida de `mount`, `findmnt`, `df -hT`.
- Explicar por qué `/proc` y `/sys` no gastan disco.

## 4. Prerrequisitos

- Lectura previa de `theory/lesson.md` (secciones 5, 6 y 7).
- Linux con `coreutils`, `findutils`, `util-linux`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
cp starter/questions.md /tmp/fhs-answers.md
$EDITOR /tmp/fhs-answers.md   # ve respondiendo a medida que exploras
```

### 5.2 Responder

Abre `/tmp/fhs-answers.md` y rellena una respuesta por pregunta. Cada respuesta debe incluir:

- La **ruta** o el **comando** que te llevó a la respuesta.
- Una línea de interpretación propia.

Hay 15 preguntas, agrupadas en bloques (FHS básico, pseudo-FS, mounts, find).

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/fhs-answers.md
```

El test comprueba **estructura**: que respondiste todas las preguntas, mencionaste rutas obligatorias y usaste comandos esperados en al menos algunas respuestas. **No** evalúa semántica — eso lo haces comparando con `solution/answers.md`.

## 6. Resultado esperado

- `/tmp/fhs-answers.md` con 15 respuestas estructuradas.
- `tests/validate.sh` pasa.
- Al comparar con `solution/answers.md`, al menos 12/15 respuestas coinciden en lo esencial.

## 7. Criterios de aceptación

- [ ] Las 15 preguntas respondidas.
- [ ] Al menos 3 respuestas incluyen una llamada a `stat`, `file`, `ls -l` o `readlink`.
- [ ] Al menos 2 respuestas tocan `/proc` o `/sys`.
- [ ] La respuesta sobre dónde colocar un binario propio **no** menciona `/usr/bin/`.
- [ ] El test `tests/validate.sh` reporta OK.

## 8. Validación

```bash
bash tests/validate.sh /tmp/fhs-answers.md
```

## 9. Preguntas de reflexión

1. Si tu distro usa `systemd`, ¿dónde están los *units* de los servicios? Compara con `/etc/init.d/` (SysV). ¿Qué cambió filosóficamente?
2. En tu laptop, ¿`/bin` es un directorio o un symlink a `/usr/bin`? ¿Por qué muchas distros tomaron esa decisión en los últimos años (`usrmerge`)?
3. ¿Qué entradas de `/proc/self/` son symlinks y a dónde apuntan?

## 10. Extensiones (opcional)

- **E1** — Lee `/etc/os-release` y escribe un one-liner que imprima solo `NAME` y `VERSION`.
- **E2** — Encuentra todos los sockets Unix activos: `find /var/run /run -type s 2>/dev/null`.
- **E3** — Compara `du -sh /usr /var /home` y explica por qué `/var` crece con el tiempo mientras `/usr` casi no.

## 11. Limpieza

```bash
rm -f /tmp/fhs-answers.md
```
