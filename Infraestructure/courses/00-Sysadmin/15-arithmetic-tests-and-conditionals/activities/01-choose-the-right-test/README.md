# Actividad 01 — Elegir el operador de test correcto

## Objetivo

Dado un enunciado en lenguaje natural, elegir qué operador de test aplica (`-f`, `-d`, `-z`, `-eq`, `=`, `=~`, etc.) y en qué construcción (`[[ ]]`, `[ ]`, `(( ))`). Se trata de decidir, no de ejecutar: entrenas el instinto.

## Formato

- 15 escenarios en `starter/questions.md`.
- Cada escenario tiene campo `operator:` y `wrapper:` que debes rellenar.
- Entregas tu versión como `starter/questions.md` modificado o copiado a `my-answers.md`.

## Reglas

- `operator`: el operador concreto, p. ej. `-f`, `-eq`, `==`, `=~`, `-z`.
- `wrapper`: una de `[[ ]]`, `[ ]`, `(( ))`.
- Si la mejor respuesta es "ninguno de los operadores pedidos, usa X", escríbelo literalmente.
- Prefiere `[[ ]]` sobre `[ ]` salvo que el enunciado hable de portabilidad POSIX.

## Validación

Automática contra `solution/answers.md`:

```bash
bash tests/validate.sh starter/questions.md
```

Pasa si cada bloque numerado contiene las dos líneas `operator:` y `wrapper:` exactamente iguales a la solución, ignorando espacios en blanco. 15/15 requerido para `OK`.

## Tiempo estimado

45 minutos. No ejecutes nada: léelo, decide, anota.
