# Actividad 02 — Quoting dojo

## 1. Identificacion

- **ID:** `sys-13-02-quoting-dojo`
- **Tecnologia:** `00-Sysadmin`
- **Modulo:** `sys-13-bash-scripting-fundamentals`
- **Dificultad:** intermediate
- **Duracion estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Recibes un script `broken.sh` escrito por un compañero que "funciona en mi maquina". El script se supone que:

1. Toma un **directorio origen**, un **directorio destino** y un **patron literal** (ej. `*.log`).
2. Copia todos los archivos del origen (recursivo) que matchean el patron hacia el destino.
3. Imprime cuantos archivos copio.

Fallos reales en el `broken.sh`:

- Explota si el directorio origen tiene **espacios** en el nombre.
- Explota si el patron (`*.log`) se **expande en el CWD del script** antes de que `find` lo vea.
- Explota si algun archivo tiene **newlines en el nombre** (si, es legal en POSIX).
- Explota si no se pasan todos los argumentos (sin mensaje util).
- `shellcheck` escupe media docena de warnings.

Tu tarea: dejarlo correcto, robusto y limpio.

## 3. Objetivos

Al terminar deberias:

- Reconocer las tres clases de bug: word splitting, globbing accidental, iteracion sobre `$(find ...)`.
- Elegir **el patron idiomatico** para iterar archivos de `find` preservando toda la informacion (`find ... -print0 | while IFS= read -r -d '' ...`).
- Entrecomillar correctamente **todas** las interpolaciones.
- Dejar el script `shellcheck`-clean.

## 4. Prerrequisitos

- Actividad `01-first-parameterized-script` completada.
- `shellcheck` instalado.
- Lectura previa de `theory/lesson.md` seccion 6 (quoting) y 8 (interpolacion segura).

## 5. Instrucciones

### 5.1 Preparar

```bash
cp starter/broken.sh /tmp/fixed.sh
chmod +x /tmp/fixed.sh
```

Lee `/tmp/fixed.sh`. Identifica (sin modificar aun) las lineas donde ves posibles bugs. Toma nota.

### 5.2 Ver el fallo en vivo

Crea un sandbox con fixtures hostiles:

```bash
TMP="$(mktemp -d)"
SRC="$TMP/mi carpeta"      # con espacio a proposito
DST="$TMP/dst"
mkdir -p "$SRC" "$DST"

touch "$SRC/normal.log"
touch "$SRC/con espacio.log"
touch "$SRC/no-matching.txt"
printf 'bad\nname.log' | xargs -0 -I{} touch "$SRC/{}" 2>/dev/null || \
  touch "$SRC/$(printf 'bad\nname.log')"

ls -la "$SRC"
```

Ejecuta el script roto:

```bash
/tmp/fixed.sh "$SRC" "$DST" '*.log' || echo "fallo con exit $?"
ls -la "$DST"
```

Observa cuales de los 3 archivos `.log` llegaron al destino. Casi seguro, no los 3.

### 5.3 Reparar

Ahora edita `/tmp/fixed.sh` y aplica los principios de la leccion:

- Validar argumentos obligatorios con `${var:?...}`.
- Entrecomillar **toda** interpolacion: `"${var}"`.
- Pasar el patron a `find` con comillas para que no se expanda.
- Iterar la salida de `find` con `-print0` + `while IFS= read -r -d ''` en vez de `for f in $(find ...)`.
- Usar `printf '%s\n'` en vez de `echo` para formato.
- Reemplazar `cp $f $dst` por `cp -- "$f" "$dst/"` (el `--` protege nombres que empiezan por `-`).

Sugerencia de forma final (si te quedas atascado, mira `solution/fixed.sh` **al final**, no al principio).

### 5.4 Verificar manualmente

Re-ejecuta en el sandbox:

```bash
rm -rf "$DST" && mkdir "$DST"
/tmp/fixed.sh "$SRC" "$DST" '*.log'
# Copiados 3 archivos
ls -la "$DST"
```

Deberias ver los tres `.log` incluido el que tiene newline y el que tiene espacio.

### 5.5 `shellcheck`

```bash
shellcheck /tmp/fixed.sh
```

Debe salir sin output. Si hay warnings, lee cada uno y corrige — no uses `# shellcheck disable=` para taparlos.

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/fixed.sh
```

Debe terminar con `OK: actividad completada correctamente.`.

## 6. Resultado esperado

- `/tmp/fixed.sh` ejecuta correctamente contra el sandbox:
  - Copia los 3 archivos `.log`, incluidos los que tienen espacio o newline en el nombre.
  - Imprime `Copiados 3 archivos`.
  - Aborta con mensaje util si faltan argumentos.
- `shellcheck` limpio.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptacion

- [ ] Funcionalidad: los 3 archivos target llegan al destino en todas las fixtures.
- [ ] Robustez: funciona con espacios en directorio, con pattern no expandido y con newlines en nombre.
- [ ] Calidad: `shellcheck` limpio **sin** `disable` taparlas.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/fixed.sh
```

El validador genera un sandbox efimero, invoca el script y verifica conteos exactos y shellcheck.

## 9. Preguntas de reflexion

1. Explica por que `for f in $(find . -name "*.log")` esta mal, incluso con comillas alrededor de `"*.log"`.
2. ¿Que hace exactamente `-print0` en `find` y por que necesita `read -r -d ''` del otro lado?
3. Si en vez de `cp -- "$f" "$dst/"` escribes `cp "$f" "$dst/"`, ¿que archivo seria capaz de romperte el script?
4. ¿Por que no basta con `shellcheck` para capturar el bug del newline? ¿Que tipo de bug es?
5. Si tu script debe aceptar que el usuario pase `*.log` **sin** entrecomillar en la invocacion, ¿que validacion deberia hacer el script para alertar?

## 10. Extensiones (opcional)

- **E1** — Añade un flag `--dry-run` que imprime que haria sin copiar.
- **E2** — Preserva timestamps y permisos (`cp -p`).
- **E3** — Soporta multiples patrones (`*.log *.gz`). Pista: investiga `-o` en `find`.

## 11. Limpieza

```bash
rm /tmp/fixed.sh
rm -rf /tmp/tmp.*   # ten cuidado si tienes otros sandboxes
```
