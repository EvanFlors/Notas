# Ejemplo 01 — Las trampas de `set -e`

## Concepto que demuestra

`set -e` **no** aborta en 5 contextos típicos. Cada script en `files/` muestra uno. Si crees que `-e` te cubre siempre, estos ejemplos te quitan la ilusión.

## Contexto

BashFAQ 105 enumera las trampas; aquí las *ejecutas* para que la intuición quede fijada.

## Objetivo

Al terminar podrás, al leer un script, detectar sin ejecutarlo los sitios donde `-e` no te está salvando.

## Prerrequisitos

- `bash` ≥ 4.0.
- Directorio escribible (los scripts no mutan nada fuera de su propio PID).

## Ejecución

Desde este directorio:

```bash
for f in files/*.sh; do
    echo "===== $f ====="
    bash "$f"
    echo "exit code: $?"
    echo
done
```

Lee **cada** exit code. Compara con lo que esperarías ingenuamente.

## Casos cubiertos

| Archivo | Contexto donde `-e` no aborta |
|---------|-------------------------------|
| `01-condition-of-if.sh`      | Comando en la condición de un `if`. |
| `02-left-of-and.sh`          | Operando izquierdo de `&&` falla. |
| `03-pipeline-without-pipefail.sh` | Pipeline con fallo en el medio. |
| `04-local-assignment.sh`     | `local x=$(cmd_que_falla)` traga el exit code. |
| `05-command-substitution-in-string.sh` | `$(...)` dentro de un string. |

## Resultado esperado

Todos los scripts terminan con **exit 0** (o imprimen "no debería imprimirse pero se imprime"). Si crees que `-e` debería haber matado el script antes, ese es exactamente el punto.

## Interpretación

- Contextos 1, 2, 4: el exit code se consume como *control de flujo*, no como *fallo*.
- Contexto 3: sin `pipefail`, solo cuenta el último comando del pipeline.
- Contexto 5: `local`, `declare`, `readonly` tienen su propio exit code (0); el del `$(…)` se descarta.

## Errores frecuentes

- Añadir `set -e` y creer que ya está. Hay que añadir también `pipefail` y, para funciones, separar `local` de la asignación.
- Confundir "exit code 0" con "todo salió bien"; aquí lo demostramos: exit 0 no implica semánticamente éxito.

## Relación con escenarios reales

- Un deploy que llama `local digest=$(docker image inspect ... | jq -r .Id)` y continúa con `digest` vacío porque `docker image inspect` falló.
- Un script que descarga configuración vía `curl -s URL | jq` y produce config vacía porque la red falló (sin `-f` en `curl` ni `pipefail`).

## Cómo arreglar cada caso

Ver `theory/lesson.md` §2. Resumen:

- Casos 1, 2: chequeo explícito con `if ! cmd` o separar.
- Caso 3: añadir `set -o pipefail`.
- Caso 4: `local x; x=$(cmd)` en dos líneas.
- Caso 5: capturar en variable antes de interpolar.

## Limpieza

Los scripts no dejan basura; no requieren cleanup.
