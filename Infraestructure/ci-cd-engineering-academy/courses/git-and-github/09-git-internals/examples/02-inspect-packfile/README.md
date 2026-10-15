# Ejemplo 02 — Inspeccionar un packfile

## Concepto que demuestra

Cómo Git **empaqueta** objetos sueltos en `.pack` + `.idx`, cómo leer su contenido con `git verify-pack`, y cómo observar la **delta compression** en acción.

## Contexto

Un repo con muchos commits y pequeñas variaciones de los mismos archivos acumula miles de blobs similares. En *loose* son miles de archivos pequeños — mal para el filesystem, mal para I/O. `git gc` los junta en un packfile con zlib + deltas.

## Objetivo

Al terminar:
- Reconoces los artefactos `pack-<sha>.pack` y `pack-<sha>.idx` dentro de `.git/objects/pack/`.
- Lees el contenido con `git verify-pack -v`.
- Observas qué objetos son `blob`, `tree`, `commit`, y cuáles aparecen marcados como `delta` (y qué objeto es su `base`).

## Prerrequisitos

- Git ≥ 2.30.
- `files/run-example.sh` o reproducir los pasos a mano.

## Ejecución

```bash
# 0) Scratch
rm -rf /tmp/pack-demo && mkdir /tmp/pack-demo && cd /tmp/pack-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# 1) Generar un repo con un archivo que crece gradualmente — buen candidato
#    para delta compression (cada versión es parecida a la anterior).
for i in $(seq 1 30); do
  printf 'line %02d\n' $i >> growing.txt
  git add growing.txt
  git -c commit.gpgsign=false commit -q -m "add line $i"
done

# 2) Antes del gc: todos los objetos están 'loose'
find .git/objects -type f | grep -v '^\.git/objects/info\|^\.git/objects/pack' | wc -l
# → cerca de 90 (30 blobs + 30 trees + 30 commits), todos sueltos

ls .git/objects/pack/ 2>/dev/null
# → vacío (todavía no hay packfile)

# 3) Empaquetar
git gc --quiet
ls .git/objects/pack/
# pack-<sha>.pack
# pack-<sha>.idx
# (opcional: pack-<sha>.rev, pack-<sha>.mtimes según versión)

# 4) ¿Cuántos loose quedan?
find .git/objects -type f | grep -v '/pack/\|/info/' | wc -l
# → 0 (o muy pocos); todos ya están en el pack

# 5) Inspeccionar el pack
IDX=$(ls .git/objects/pack/pack-*.idx | head -1)
git verify-pack -v "$IDX" | head -40
```

La salida de `verify-pack -v` tiene este formato por objeto:

```
<hash> <type> <size> <size-in-packfile> <offset-in-packfile> [<depth> <base-hash>]
```

Ejemplo real que verás:

```
abcdef0123... blob 10 20 1234
fedcba9876... blob 10 15 1256 1 abcdef0123...
```

- La **primera línea** es un blob almacenado completo (sin delta).
- La **segunda** es un blob delta: `depth=1`, `base=abcdef0123...`. En vez de guardar los 10 bytes de contenido, guarda **las diferencias** respecto a la base (muchas veces mucho menos que 10 bytes para contenidos muy parecidos).

Al final, `verify-pack` imprime estadísticas:

```
non delta: N objects
chain length = 1: M objects
chain length = 2: K objects
...
pack-<sha>.pack: ok
```

## Observaciones típicas

- Los **blobs del archivo que crece** se almacenan mayormente como deltas (todos derivan del "largest").
- Los **commits y trees** suelen quedar como non-delta (son pequeños y únicos).
- La reducción total de tamaño vs loose es grande (fácilmente 5–10×, más en repos con churn).

## Comandos complementarios

```bash
# ¿Qué objeto está en qué pack?
git rev-parse HEAD | xargs -I{} git cat-file -t {}
# blob/tree/commit

# ¿Está en loose o en pack?
HASH=$(git rev-parse HEAD)
test -f ".git/objects/${HASH:0:2}/${HASH:2}" && echo loose || echo packed

# Listar todos los objetos en el pack ordenados por tamaño on-disk
git verify-pack -v "$IDX" | awk 'NF>=4 && $2!~/^(ok)/ {print $4, $1, $2}' | sort -rn | head

# Repack más agresivo (window = 250 por default, delta search mejor)
git repack -ad --window=250 --depth=50
```

## Resultado esperado

Comprender visualmente:
- La **estructura** `pack` + `idx`.
- Cómo cada objeto queda etiquetado como non-delta o delta (con su base y profundidad).
- Que **lectura de un objeto delta** implica reconstruirlo encadenando parches desde su base. Por eso Git limita `depth`.

## Errores frecuentes

- **"No encuentro `.pack` ni después de `git commit`"**: `gc` no se dispara en cada commit; corre según `gc.auto` (default: cada ~6700 loose objects o ~50 packs sueltos). Fuerza con `git gc` o `git repack -ad`.
- **"`verify-pack` me da `error`"**: el pack está corrupto. `git fsck` confirmará. Puedes borrar el pack si tienes los objetos elsewhere, o restaurar de backup.
- **"Modifiqué el `.pack` a mano"**: no lo hagas; el `.idx` quedará desincronizado. Reconstruye con `git index-pack`.
- **Confundir `.idx` con el pack**: el `.idx` es solo índice (hashes → offsets). Borrarlo sin el `.pack` no destruye objetos; se puede regenerar con `git index-pack`.

## Relación con escenarios reales

- Clones iniciales grandes = Git sirve el repositorio como un **packfile** (streaming). Ver `smart HTTP` y `fetch pack`.
- `git maintenance` en background hace `incremental-repack` para mantener I/O bajo sin bloquear al usuario.
- Herramientas de observabilidad de repos (p. ej. `git-sizer`) usan los packfiles para estimar coste.

## Limpieza

```bash
rm -rf /tmp/pack-demo
```
