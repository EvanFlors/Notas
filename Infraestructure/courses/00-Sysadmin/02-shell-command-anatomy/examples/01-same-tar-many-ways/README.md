# Ejemplo 01 — El mismo `tar` escrito de tres formas

## Concepto que demuestra

Las opciones **cortas agrupadas**, **cortas separadas** y **largas** son tres sintaxis distintas para una *misma* invocación. El binario `tar` recibe exactamente la misma lista de argumentos efectivos y produce exactamente el mismo resultado.

## Contexto

`tar` es el ejemplo canónico porque arrastra convenciones de **tres eras**:

- Estilo BSD histórico sin guion (`tar xzf`).
- Estilo POSIX con guion (`tar -xzf`).
- Estilo GNU largo (`tar --extract --gzip --file=`).

Las tres conviven. Las tres funcionan. Esto confunde a principiantes porque parecen comandos distintos.

## Objetivo

Al terminar, podrás responder:

- ¿Qué significa cada letra en `-xzvf`?
- ¿Por qué `-f` debe ir **al final** del grupo?
- ¿Por qué los tres comandos producen el mismo output byte a byte?

## Prerrequisitos

- `tar` instalado (`tar --version`).
- `gzip` instalado.
- Directorio escribible (usaremos `/tmp/`).

## Ejecución

Copia-pega este bloque en una terminal. **Lee la salida de cada comando antes de ejecutar el siguiente.**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Preparar: creamos un .tar.gz de referencia con 3 archivos.
WORK=/tmp/tar-anatomy
rm -rf "$WORK" && mkdir -p "$WORK/src"
cd "$WORK/src"
printf 'a\n' > a.txt
printf 'b\n' > b.txt
printf 'c\n' > c.txt
cd "$WORK"
tar -czf payload.tgz -C src .
ls -la payload.tgz
# -> payload.tgz existe. Es nuestro "input" para las tres extracciones.

# Forma 1 — BSD histórica, sin guion, flags pegados al comando.
rm -rf out1 && mkdir out1
tar xzf payload.tgz -C out1
ls out1
# -> a.txt b.txt c.txt

# Forma 2 — POSIX con guion, flags cortos agrupados.
rm -rf out2 && mkdir out2
tar -xzf payload.tgz -C out2
ls out2
# -> a.txt b.txt c.txt

# Forma 3 — GNU largo, auto-documentada.
rm -rf out3 && mkdir out3
tar --extract --gzip --file=payload.tgz --directory=out3
ls out3
# -> a.txt b.txt c.txt

# Verificación: los tres directorios son idénticos.
diff -r out1 out2 && echo "out1 == out2"
diff -r out2 out3 && echo "out2 == out3"
```

## Resultado esperado

- `out1`, `out2`, `out3` contienen `a.txt`, `b.txt`, `c.txt` con el mismo contenido.
- Los `diff -r` imprimen sólo las líneas `out1 == out2` y `out2 == out3`.

## Interpretación

Las tres formas se traducen al **mismo** vector de argumentos efectivo que recibe tar internamente:

```
operation = extract
compress  = gzip
file      = payload.tgz
chdir     = out{1,2,3}
```

El parser de tar simplemente acepta varios dialectos para la misma operación. En **formas cortas**:

- `-x` eXtract.
- `-z` filtro gZip.
- `-f FILE` lee de FILE (necesita valor; por eso va **al final** del grupo).
- `-v` sería verbose (no lo usamos aquí).
- `-C DIR` hace `cd DIR` antes de operar.

En la **forma larga**, cada flag tiene nombre completo (`--extract`, `--gzip`, `--file=`, `--directory=`).

## Errores frecuentes

- **`-f` no al final del grupo**: `tar -fxz payload.tgz` falla porque `-f` tomaría `x` como su valor.
- **Pensar que `tar xzf` sin guion es "mal estilo"**: funciona por compatibilidad y es la forma más vieja. Para scripts prefiere `-xzf`.
- **Mezclar `--file payload.tgz` (sin `=`) con `tar` muy antiguos**: GNU moderno acepta ambos; algunos clones BSD no. El `=` es más portable.
- **Olvidar `-C` y preguntarse por qué se extrajo en el cwd**: `tar` extrae en el directorio actual por default.

## Relación con escenarios reales

- En **Dockerfiles** y scripts de CI, se usa la forma larga para que un revisor entienda sin consultar `man tar`.
- En **comandos de un solo uso en producción**, se usa la forma corta para teclear menos.
- En **tutoriales viejos de Internet** verás `tar xzf` sin guion — ya sabes que es la misma cosa.

## Limpieza

```bash
rm -rf /tmp/tar-anatomy
```
