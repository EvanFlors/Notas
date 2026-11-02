# Ejemplo 02 — Matriz de redirección

## Concepto que demuestra

Todos los operadores de redirección de Bash en una sola tabla, con una demo verificable para cada uno. Material de **referencia** para consultar durante la actividad `02-io-redirection-dojo` y el día a día.

## Contexto

La redirección es la operación más densa semánticamente de Bash. El orden de evaluación importa, hay operadores Bash-only y hay sutilezas (buffering, SIGPIPE) que solo se entienden ejecutando.

## Objetivo

Al terminar podrás:
- Identificar de un vistazo qué hace cada operador.
- Elegir correctamente entre `&>` y `> file 2>&1` según portabilidad.
- Escribir pipelines con `pipefail` y auditarlos con `tee`.

## Matriz completa

| Operador | Significado | POSIX | Demo |
|----------|-------------|:-----:|------|
| `>` file | fd 1 → file, trunca | sí | `echo hola > /tmp/a; cat /tmp/a` |
| `>>` file | fd 1 → file, append | sí | `echo mundo >> /tmp/a; cat /tmp/a` |
| `<` file | fd 0 ← file | sí | `wc -l < /etc/hosts` |
| `2>` file | fd 2 → file, trunca | sí | `ls /nope 2> /tmp/err; cat /tmp/err` |
| `2>>` file | fd 2 → file, append | sí | `ls /nope2 2>> /tmp/err` |
| `2>&1` | fd 2 duplica el destino actual de fd 1 | sí | `ls /tmp /nope > /tmp/all 2>&1` |
| `&>` file | fd 1 + fd 2 → file, trunca | **no** | `ls /tmp /nope &> /tmp/all` |
| `&>>` file | fd 1 + fd 2 → file, append | **no** | `ls /nope3 &>> /tmp/all` |
| `>&-` | cierra fd 1 | sí | `echo oops >&-` (silencio) |
| `n> file` | redirige fd arbitrario `n` | sí | `exec 3> /tmp/log3; echo hi >&3` |
| `<<<` "s" | here-string: pasa "s" como stdin | **no (Bash)** | `tr a-z A-Z <<< hola` |
| `<<EOF` | here-doc con expansión | sí | ver §Here-doc |
| `<<'EOF'` | here-doc **sin** expansión | sí | ver §Here-doc |
| `<<-EOF` | here-doc, elimina tabs iniciales | sí | ver §Here-doc |
| `\|` | pipe stdout de A a stdin de B | sí | `ls \| wc -l` |
| `\|&` | pipe stdout+stderr | **no (Bash)** | `make \|& tee build.log` |

## Ejecución (recorrido)

```bash
# Preparar
mkdir -p /tmp/redir-demo && cd /tmp/redir-demo
rm -f *.log *.out

# 1. Truncar vs append
echo "linea 1" > out.txt
echo "linea 2" > out.txt    # TRUNCA, solo queda la 2
cat out.txt
echo "linea 3" >> out.txt   # APPEND
cat out.txt

# 2. stderr y combinación (orden crítico)
ls /tmp /no-existe > both.log 2>&1   # correcto: ambos a both.log
cat both.log
ls /tmp /no-existe 2>&1 > bad.log    # BUG: stderr sigue en terminal
cat bad.log

# 3. &> (Bash)
ls /tmp /no-existe &> all.log
cat all.log

# 4. Separar streams
ls /tmp /no-existe > ok.log 2> err.log
echo "--- OK ---"; cat ok.log
echo "--- ERR ---"; cat err.log

# 5. Here-string
tr a-z A-Z <<< "hola mundo"

# 6. Here-doc con / sin expansión
NAME=Evan
cat <<EOF
Hola $NAME
EOF

cat <<'EOF'
Literal: $NAME se queda tal cual
EOF

# 7. Here-doc indentado con tabs (ojo: TABS reales, no espacios)
cat <<-EOF
	indentado
	con tabs
EOF

# 8. fd arbitrario
exec 3> /tmp/log3        # abre fd 3
echo "a log 3" >&3
echo "otra" >&3
exec 3>&-                # cierra fd 3
cat /tmp/log3

# 9. Pipe + pipefail
set +o pipefail
false | true; echo "sin pipefail: $?"
set -o pipefail
false | true; echo "con pipefail: $?"
echo "PIPESTATUS: ${PIPESTATUS[*]}"

# 10. tee: ver y guardar a la vez
ls /tmp | tee listado.log | wc -l
cat listado.log | head -3

# 11. tee -a (append) y proceso múltiple
seq 1 5 | tee -a listado.log >/dev/null
tail -3 listado.log

# 12. Combinar stdout+stderr y logear con tee
{ echo "ok"; echo "err" >&2; } |& tee combo.log
cat combo.log
```

## Interpretación

- **El orden de las redirecciones en la línea importa.** Bash las procesa de izquierda a derecha. `>out 2>&1` manda ambos a `out`; `2>&1 >out` no.
- **`&>` es Bash-only.** En un script `#!/bin/sh` que corra bajo dash, usa `> out 2>&1`.
- **Here-string (`<<<`) evita un `fork` extra** respecto a `echo "s" | cmd`. Útil en loops ajustados.
- **Here-doc con comillas (`<<'EOF'`)** desactiva *toda* expansión — útil cuando el bloque contiene `$`, `` ` ``, `!` o templates para otro lenguaje.
- **`tee` es *T* en un pipe:** split del stream. `-a` para append; `>(cmd)` (process substitution) para enviar a comandos en vez de archivos.

## Errores frecuentes

- **`cmd 2>&1 | grep ...`** combina stderr con stdout *antes* del pipe — correcto, es el patrón habitual.
- **Pensar que `|` solo pasa stdout, pero necesito stderr** — usa `|&` o `2>&1 |`.
- **`>` sobrescribe por accidente** — activa `set -o noclobber` y fuerza con `>|` cuando quieras sobrescribir.
- **Here-doc `<<-` con espacios en lugar de tabs** — no quita la indentación; relee con `cat -A`.
- **Buffering raro con `cmd | less`** — usa `stdbuf -oL cmd | less` o `script -q /dev/null`.

## Relación con escenarios reales

- **CI logs:** `./build.sh 2>&1 | tee -a build.log` es el patrón universal.
- **Depuración de pipelines fallidos:** `${PIPESTATUS[@]}` revela qué eslabón falló.
- **Separar errores para alertas:** `cmd > app.log 2> app.err` facilita que un `fluentd` enrute `app.err` a un canal distinto.
- **Scripts idempotentes:** `>>` para logs persistentes, `>` para artefactos regenerables.

## Limpieza

```bash
rm -rf /tmp/redir-demo /tmp/log3
```
