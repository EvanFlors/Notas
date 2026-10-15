# Example 02 — GitFlow timeline

> Reproduce un ciclo completo de GitFlow: `feature/*` → `develop` → `release/1.0.0` → `main` (tag `v1.0.0`) + un `hotfix/*` disparado desde `main` y mergeado de vuelta a ambas ramas largas.

## Qué vas a observar

- **Dos ramas largas**: `main` y `develop`.
- Dos `feature/*` mergean a `develop`.
- Una `release/1.0.0` ramifica de `develop`, recibe un *bugfix* de QA, y mergea a `main` **y** a `develop`. Tag `v1.0.0`.
- Un `hotfix/typo` ramifica de `main`, mergea a `main` **y** a `develop`. Tag `v1.0.1`.

Nota la cantidad de **doble merge**. Omitir uno es el error #1 de GitFlow.

## DAG esperado (simplificado)

```
*   (hotfix→develop)                                                     develop
|\
| \     *   (release→develop)                                            develop
|  \   /|\
|   \ / | \
|    *  |  *---*  (feature/payments)                                     develop
|   /|  | /
|  / |  |/
| /  |  *   (feature/auth)                                               develop
|/   |  |
*----|--*                                                                develop (init)
     | /
     |/
     *-------* (release/1.0.0 — bugfix in QA)                             release
    / \       \
   /   \       \
  /     *-------*  (merge release→main, tag v1.0.0)                       main
 /                 \
*                   *----*  (hotfix/typo, tag v1.0.1 on main)             main
```

(En texto no es trivial; después de ejecutar `files/run-demo.sh`, usa `git log --oneline --graph --all` para verlo bien.)

## Cómo ejecutar

```bash
bash files/run-demo.sh /tmp/gitflow-timeline
cd /tmp/gitflow-timeline
git log --oneline --graph --all --decorate
```

## Qué notar

1. **Ramas vivas simultáneamente** al terminar el ciclo (si no haces cleanup): `main`, `develop`, y las `release/*` o `hotfix/*` recientes. Siempre al menos 2 largas.
2. **Doble merge** en release y hotfix. En este script lo hacemos *manualmente*; en producción se usa `git-flow` CLI para no olvidar.
3. **Tags sobre `main`**: `v1.0.0` y `v1.0.1`. `develop` no se taggea.
4. **Latencia dev→usuario**: desde que empieza `feature/auth` hasta que `v1.0.0` sale son múltiples pasos obligatorios (feature → develop → release → QA → main → tag). Mide eso y comparalo con el ejemplo trunk-based.

## Limpieza

```bash
rm -rf /tmp/gitflow-timeline
```

## Siguiente

→ Compara con `examples/01-trunk-based-timeline/`. Mismo trabajo lógico; mucho más andamiaje aquí. Decide con datos cuándo esa inversión vale la pena (ver §6.5 de la lección).
