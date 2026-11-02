# Ejemplo 02 — Cheatsheet de expansion de parametros

## Concepto que demuestra

Las cuatro formas canonicas de expansion de parametros con default lado-a-lado:

- `${var:-default}` — usa default **sin asignar**.
- `${var:=default}` — usa default **y asigna** a `var`.
- `${var:?error}` — **aborta** si vacia/no definida.
- `${var:+alt}` — expande a `alt` solo si `var` tiene valor.

## Contexto

Son el reemplazo idiomatico de patrones `if [ -z "$var" ]; then var=...; fi`. Mas cortas y expresan intencion.

## Objetivo

Al terminar podras elegir la forma correcta segun si quieres:

- Pasar un default una vez (`:-`).
- Hacer el default persistente (`:=`).
- Exigir que la variable exista (`:?`).
- Añadir un flag solo si la variable esta definida (`:+`).

## Prerrequisitos

- Bash ≥ 4.

## Ejecucion

```bash
bash files/demo.sh
```

Y luego, para ver el caso de `:?`:

```bash
bash files/demo.sh --test-abort
# Salida: aborta con mensaje por stderr y exit != 0
echo "exit code: $?"
```

## Resultado esperado

Impresión en 4 secciones, cada una mostrando el valor de `var` antes y despues de la expansion, y el resultado.

## Interpretacion

La tabla resumen:

| Forma                | var tiene valor | var vacia/no definida       |
|----------------------|-----------------|------------------------------|
| `${var:-default}`    | usa `$var`      | expande a `default`, NO asigna |
| `${var:=default}`    | usa `$var`      | expande a `default` Y asigna |
| `${var:?msg}`        | usa `$var`      | aborta con `msg` por stderr  |
| `${var:+alt}`        | expande a `alt` | expande a `""`               |

Diferencia `:-` vs `:=`: tras `:-` la variable sigue vacia; tras `:=` ya tiene valor para el resto del script.

## Errores frecuentes

- Intentar `${1:=default}` — no se puede asignar a parametros posicionales. Usa `${1:-default}` o re-asigna: `arg1="${1:-default}"`.
- Olvidar `set -u`: sin `nounset`, usar una variable no definida sin `:?` no aborta y produce bugs silenciosos.

## Relacion con escenarios reales

- Config de contenedores: `PORT="${PORT:-8080}"` para que el contenedor arranque con default razonable.
- Scripts que requieren secretos: `: "${API_KEY:?API_KEY no definida}"` falla rapido en vez de ir a la API con header vacio.
- Flags condicionales: `rsync ${VERBOSE:+-v} ...`.
