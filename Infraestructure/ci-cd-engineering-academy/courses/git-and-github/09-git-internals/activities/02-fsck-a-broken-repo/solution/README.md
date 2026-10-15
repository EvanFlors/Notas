# Solución — gh-09-02-fsck-a-broken-repo

> **No consultes esta solución antes de intentar la actividad.**

Script: [`solve.sh`](./solve.sh). Ejecuta `bash solve.sh /tmp/fsck-lab`.

## Idea

1. **Diagnóstico** con `git fsck --full` sobre `broken/` → identifica el objeto `missing` y el `broken link`.
2. **Reparar temporalmente**: añadir `backup/.git/objects` como alternate.
3. **Consolidar**: `git repack -ad` empaqueta todos los objetos alcanzables (incluyendo los del alternate) en un pack dentro de `broken/`.
4. **Desactivar el alternate**: borrar `.git/objects/info/alternates`.
5. **Verificar**: `fsck` sigue limpio y el blob original ya es parte de `broken/`.

## Flujo exacto

```bash
# 1) Diagnóstico
git -C /tmp/fsck-lab/broken fsck --full
#   → missing blob <hash>
#   → broken link from commit <X> to blob <hash>

# 2) Alternate
echo /tmp/fsck-lab/backup/.git/objects \
  > /tmp/fsck-lab/broken/.git/objects/info/alternates

# 3) Confirmar que ahora fsck está limpio
git -C /tmp/fsck-lab/broken fsck --full
#   → sin missing

# 4) Consolidar
git -C /tmp/fsck-lab/broken repack -ad

# 5) Quitar el alternate
rm /tmp/fsck-lab/broken/.git/objects/info/alternates

# 6) Verificación final
git -C /tmp/fsck-lab/broken fsck --full   # debe seguir limpio
git -C /tmp/fsck-lab/broken cat-file -e <hash> && echo "OK: blob local"
```

## Alternativas

- **Opción manual (sin alternate)**: `git -C backup cat-file blob <hash> | git -C broken hash-object --stdin -w` — recrea el blob desde su contenido. Más laborioso si hay muchos faltantes.
- **Opción con pack directo**: copiar `backup/.git/objects/pack/*` a `broken/.git/objects/pack/`. Solo funciona si el backup ya tiene packs; además, mezcla historia que quizá no quieras (overkill).
- **Opción vía fetch**: si el remote tiene el objeto, `git -C broken fetch origin` puede completar la historia faltante.

## Qué hace exactamente `repack -ad`

- `-a` (`--all`): empaqueta **todos** los objetos alcanzables desde refs.
- `-d` (`--delete-pack-files`): borra los packs viejos tras crear el nuevo.
- Con un alternate presente, los objetos alcanzables incluyen los del alternate → se copian al pack local.

## Lecciones

- `fsck` **no modifica** nada; solo reporta. Siempre es seguro ejecutarlo.
- `alternates` es una herramienta **frágil pero potente**: ideal para recuperaciones puntuales, mala idea como dependencia permanente.
- `repack -ad` es lo que convierte un "estoy leyendo del alternate" en "ya tengo todo lo mío".
