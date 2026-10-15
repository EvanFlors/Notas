# Example 01 — Trunk-based timeline

> Reproduce un día típico de trunk-based: `main` siempre deployable, dos features cortas detrás de feature flags apagados, ambas integradas antes de que termine el día.

## Qué vas a observar

- Una sola rama larga: `main`.
- Dos ramas efímeras (`feat/new-checkout`, `feat/dark-mode`) nacen, hacen 1–2 commits, mergean a `main` y se eliminan.
- Un archivo `flags.py` con *toggles* apagados por default: el código nuevo convive en `main` sin exponerse a usuarios.

## DAG esperado (resultado final)

```
*   d4e5f6 (HEAD -> main) merge: feat/dark-mode behind flag (off)
|\
| * c3d4e5 feat(ui): dark mode scaffolding behind flag
|/
*   b2c3d4 merge: feat/new-checkout behind flag (off)
|\
| * a1b2c3 feat(checkout): new flow scaffolding behind flag
|/
* 9f8e7d chore: raise flag entry for dark_mode (off)
* 8e7d6c chore: raise flag entry for new_checkout (off)
* 7d6c5b init: scaffold flags.py + legacy app
```

Variante trunk-based "lineal" (squash & merge): el DAG colapsa a una sola columna sin merge commits. Igual de válido.

## Cómo ejecutar

```bash
bash files/run-demo.sh /tmp/tbd-timeline
cd /tmp/tbd-timeline
git log --oneline --graph --all
```

## Qué notar

1. En ningún momento `main` queda rota: cada merge llega con tests pasando y flags apagados.
2. Las ramas se borran al mergear. **Esto es parte del contrato**: una rama "zombie" un mes después = tentación de hacerla crecer = merge hell.
3. El código del feature está en `main` desde el día 1. Activarlo mañana es cambiar `False` → `True` en `flags.py` y re-deploy (o, mejor, un cambio en el *flag service* sin re-deploy).

## Limpieza

```bash
rm -rf /tmp/tbd-timeline
```

## Siguiente

→ Compara con `examples/02-gitflow-timeline/` para ver cuántas ramas largas y cuántos merges requiere el mismo trabajo en GitFlow.
