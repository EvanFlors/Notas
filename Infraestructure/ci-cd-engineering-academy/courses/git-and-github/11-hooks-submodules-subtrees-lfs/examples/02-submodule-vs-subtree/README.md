# Ejemplo 02 — Submodule vs Subtree lado a lado

## Concepto que demuestra

Integrar el **mismo repo upstream** en un consumidor usando las dos estrategias:

1. **Submodule**: el consumidor guarda un **gitlink** (SHA + URL) al upstream.
2. **Subtree**: el consumidor guarda **el contenido** del upstream en un subdirectorio.

Luego inspeccionamos cómo se ve cada uno con `git ls-tree`, `git log`, y `.gitmodules`.

## Contexto

Caso real: tu equipo mantiene `super-app`. Hay una librería interna `libgreet` publicada en un repo aparte. Puedes vendorizarla como submodule o como subtree.

## Objetivo

Al terminar:
- Observas la diferencia en `git ls-tree HEAD` (mode `160000` para submodule vs mode `040000` para subtree).
- Observas `.gitmodules` en submodule y su ausencia en subtree.
- Observas cómo `git log` del super ve (o no ve) la historia del upstream.
- Entiendes por qué `git clone` sin flags **no trae** el contenido del submódulo.

## Prerrequisitos

- Git ≥ 2.30 con `git subtree` (viene por default en instalaciones recientes; en algunos Linux es paquete separado `git-subtree`).

## Ejecución

```bash
bash files/run-example.sh
```

### Qué hace el script

1. Crea un repo "upstream" (`/tmp/sm-vs-st/upstream`) con `libgreet` (una función y 3 commits).
2. Crea `super-sub/` que integra `libgreet` como **submódulo** en `vendor/libgreet`.
3. Crea `super-tree/` que integra `libgreet` como **subtree** en `vendor/libgreet`.
4. Para cada uno, imprime:
   - `git ls-tree HEAD vendor/` → verás `160000 commit` vs `040000 tree`.
   - `cat .gitmodules` → existe en sub, no existe en tree.
   - `git log --oneline` → el subtree incluye los commits del upstream (si no se usó `--squash`); el submódulo no.
   - `git clone` del super a `/tmp/sm-vs-st/reclone-*` sin flags → el submódulo queda **vacío**, el subtree trae todo.

## Resultado esperado (resumen)

```
=== super-sub (SUBMODULE) ===
git ls-tree HEAD vendor/
  160000 commit <sha>    libgreet       ← gitlink, mode 160000

.gitmodules:
  [submodule "vendor/libgreet"]
          path = vendor/libgreet
          url = /tmp/sm-vs-st/upstream

Reclone without --recurse-submodules:
  vendor/libgreet/ exists but is EMPTY.

=== super-tree (SUBTREE) ===
git ls-tree HEAD vendor/
  040000 tree <sha>      libgreet       ← tree normal

.gitmodules: (no existe)

Reclone (sin flags): vendor/libgreet/ tiene todos los archivos.
```

## Interpretación

- El **gitlink** (`160000`) es el ADN del submódulo. No es un blob, no es un tree — es "mi tree tiene aquí un *commit externo*".
- Un subtree es un tree normal: la operación `git subtree add` básicamente hizo un merge del upstream dentro de un prefijo.
- Por eso, cambios en el upstream **no se propagan automáticamente** a ninguno de los dos: en submódulo, haces `git submodule update --remote` + actualizas el gitlink; en subtree, `git subtree pull`.
- El reviewer del PR del super ve diffs distintos:
  - Submodule: ve "gitlink cambió de SHA A a SHA B" — opaco sin ir al otro repo.
  - Subtree: ve el diff real del contenido.

## Trade-offs observados

| Aspecto | Submodule | Subtree |
|---|---|---|
| `git clone <super>` trae el contenido | ❌ (requiere `--recurse-submodules`) | ✅ |
| Diff legible en PRs del super | ❌ (solo gitlink) | ✅ |
| Pin exacto a un SHA del upstream | ✅ (es el modelo) | ⚠️ (manual) |
| `.gitmodules` tracked | sí | n/a |
| Historia del upstream mezclada | no | sí (salvo `--squash`) |
| Peso del clon del super | mínimo | mayor |

## Errores frecuentes

- Olvidar `--recurse-submodules` al clonar → carpetas vacías.
- Modificar el submódulo sin actualizar el gitlink en el super → `git status` del super reporta "modified content".
- Hacer `git subtree pull` sin `--squash` cuando antes se usó `--squash` → conflictos inesperados por historia divergente.
- Confundir `git subtree add --prefix=X <repo>` (añade por primera vez) con `git subtree pull --prefix=X <repo>` (actualiza).

## Relación con escenarios reales

- Teams con **upstream estable y crítico** → submodule.
- Teams que **modifican con frecuencia** la lib compartida → subtree o monorepo.
- Decidir temprano: migrar entre modelos requiere reescribir historia o perderla.

## Limpieza

```bash
rm -rf /tmp/sm-vs-st
```
