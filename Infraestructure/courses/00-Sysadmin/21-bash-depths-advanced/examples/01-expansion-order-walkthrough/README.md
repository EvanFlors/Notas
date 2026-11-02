# Ejemplo 01 — Walkthrough del orden de expansión

Este ejemplo materializa el diagrama de la lección. `files/demo.sh` imprime, para una misma línea cruda, **qué queda después de cada etapa** de expansión.

## Qué observar

Al ejecutar:

```bash
cd files
bash demo.sh
```

El script:

1. Crea un árbol temporal con `a/one.txt`, `a/two.txt`, `b/three.txt`.
2. Toma la línea `echo {a,b}/*.txt > >(tee out.log) 2>&1`.
3. **Simula** paso a paso cada etapa de expansión usando `set -x` selectivo y comandos auxiliares que materializan lo que haría Bash internamente.
4. Al final, ejecuta la línea de verdad para que compares.

## Qué deberías ver

- Tras **brace expansion**: dos tokens `a/*.txt` y `b/*.txt`.
- Tras **globbing**: tres tokens finales (`a/one.txt a/two.txt b/three.txt`).
- Tras ejecutar: `out.log` contiene lo que `echo` imprimió.

## Preguntas de autoevaluación

1. Si borras `a/two.txt` y vuelves a correr, ¿cuántos tokens quedan tras globbing?
2. Si cambias `*.txt` por `*.md` (que no matchea nada) **sin** `nullglob`, ¿qué recibe `echo`?
3. ¿Qué cambia si envuelves la ruta en comillas: `"{a,b}/*.txt"`?
