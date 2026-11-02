# Actividad 02 — I/O redirection dojo

## 1. Identificación

- **ID:** `sys-01-02-io-redirection-dojo`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-01-bash-cli-foundations`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Fijar la redirección y las variables de entorno como reflejos. Ocho ejercicios producen artefactos concretos (archivos en `/tmp/dojo/`) que un validador comprueba. Sin paso a paso: te damos el *qué*, descubres el *cómo* con la lección y los ejemplos a mano.

## 3. Objetivos

Al terminar deberías poder:

- Redirigir stdout y stderr a destinos separados o combinados sin bugs de orden.
- Usar `>>`, `2>>` y `&>>` correctamente.
- Construir here-docs y here-strings.
- Encadenar comandos con `|`, auditar con `tee`, propagar fallos con `pipefail` y leer `PIPESTATUS`.
- Diferenciar en la práctica shell variable vs variable exportada.
- Modificar `PATH` sin romperlo.

## 4. Prerrequisitos

- Haber completado `01-cli-tour` (recomendado).
- Lección `theory/lesson.md` leída.
- Bash ≥ 4.
- `shellcheck` instalado para auto-revisión (opcional pero recomendado).

**Costos:** ninguno.

## 5. Instrucciones

Crea `/tmp/dojo/` (`mkdir -p /tmp/dojo`) y produce ahí los artefactos pedidos. Cuando termines ejecuta `bash tests/validate.sh`.

Puedes resolver cada ejercicio con un comando o escribir un script `solve.sh` que haga todo. Si usas script: `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`, y debe pasar `shellcheck`.

### Ex 1 — stdout a archivo

Produce `/tmp/dojo/01-stdout.txt` que contenga **exactamente** la salida de `uname -a`.

### Ex 2 — stderr separado

Ejecuta `ls /tmp /no-existe-xyz` de forma que:

- stdout vaya a `/tmp/dojo/02-ok.txt`
- stderr vaya a `/tmp/dojo/02-err.txt`

Ambos archivos deben existir y ser **no vacíos**.

### Ex 3 — ambos combinados (POSIX)

Ejecuta `ls /tmp /no-existe-xyz` combinando stdout y stderr en `/tmp/dojo/03-combo.txt`. Usa la forma **POSIX** (sin `&>`).

### Ex 4 — append sin sobrescribir

Crea `/tmp/dojo/04-log.txt` con **al menos 3 líneas**, añadidas con `>>` en comandos separados. La primera línea debe empezar con `inicio:`, la última con `fin:`.

### Ex 5 — here-doc sin expansión

Genera `/tmp/dojo/05-template.txt` con exactamente este contenido (incluyendo las comillas `$VAR` literales — no expandir):

```
# Template
usuario: $USER
home: $HOME
```

### Ex 6 — pipeline con pipefail

Produce `/tmp/dojo/06-pipeline.txt` con el **exit code real** (no 0) de la pipeline:

```
false | sort | uniq
```

Es decir, el archivo debe contener en una línea un número entero != 0 (el exit code de `false`, propagado por `pipefail`).

### Ex 7 — tee con auditoría

Lista los primeros 5 nombres de archivo de `/etc`, duplicando la salida: ir a terminal **y** a `/tmp/dojo/07-tee.txt`. Pista: `ls /etc | head -5 | tee ...`.

### Ex 8 — entorno vs shell

En `/tmp/dojo/08-env.txt` deja la salida de ejecutar `bash -c 'echo "DOJO_VAR=${DOJO_VAR:-UNSET}"'` con `DOJO_VAR=exported` **exportado** antes.

El archivo debe contener literalmente:

```
DOJO_VAR=exported
```

Y en `/tmp/dojo/08-shell.txt` deja la salida de ejecutar lo mismo con `DOJO_VAR=shellonly` asignado **sin exportar**. El archivo debe contener:

```
DOJO_VAR=UNSET
```

### Validación

```bash
bash tests/validate.sh
```

Debe terminar en `OK`.

## 6. Resultado esperado

En `/tmp/dojo/`:

- `01-stdout.txt`, `02-ok.txt`, `02-err.txt`, `03-combo.txt`, `04-log.txt`,
  `05-template.txt`, `06-pipeline.txt`, `07-tee.txt`, `08-env.txt`, `08-shell.txt`.
- Cada uno con el contenido descrito.

## 7. Criterios de aceptación

- [ ] Funcionalidad: `tests/validate.sh` pasa.
- [ ] Calidad: si usaste un script, `shellcheck solve.sh` no reporta warnings.
- [ ] Comprensión: puedes explicar por qué `08-env.txt` y `08-shell.txt` difieren.
- [ ] Seguridad: no hubo `rm -rf` sobre rutas no absolutas.

## 8. Validación

```bash
bash tests/validate.sh
```

Comprueba existencia y contenido mínimo de cada artefacto.

## 9. Preguntas de reflexión

1. ¿Por qué `false | sort | uniq` sin `pipefail` devuelve 0? ¿Qué comando reportó ese 0?
2. En Ex 5, si usaras `<<EOF` (sin comillas), ¿qué contendría el archivo? Pruébalo.
3. ¿Qué diferencia hay entre `tee archivo` y `cat > archivo`?
4. Explica el bug: `cmd 2>&1 > out.txt`.
5. ¿Qué pasa si en Ex 8 defines `DOJO_VAR` sin exportar y luego llamas `bash -c '...'` precedido por `env -i`?

## 10. Extensiones (opcional)

- **E1** — Repite Ex 6 usando `PIPESTATUS` para extraer el exit code sin `pipefail`.
- **E2** — Usa process substitution: `diff <(ls /etc) <(ls /tmp)` y guarda el resultado.
- **E3** — Añade al `~/.bashrc` del `01-cli-tour` una función `logrun() { "$@" 2>&1 | tee -a ~/last-run.log; }` y pruébala.
- **E4** — Modifica `PATH` para prepend `~/bin`, verifica con `type -a` y restaura.

## 11. Limpieza

```bash
rm -rf /tmp/dojo
```
