# MAP.md — referencia de solución (`gh-01-03-explore-dot-git`)

> **No consultar hasta haber producido tu propio `MAP.md`.**
> Los hashes variarán por repo; aquí se muestran los **tipos y relaciones**.

## A. Mapa anotado de `.git/`

```
.git/
├── HEAD                        — ref simbólico; en este repo: "ref: refs/heads/main"
├── config                      — config local: user.name, user.email, init.defaultBranch
├── description                 — placeholder; no se usa
├── index                       — staging area (binario); refleja el estado actual
├── hooks/*.sample              — hooks de ejemplo, sin activar
├── info/
│   └── exclude                 — ignores LOCALES (añadimos "*.swp", ".DS_Store")
├── logs/
│   ├── HEAD                    — reflog de HEAD: cada checkout/commit/reset
│   └── refs/
│       └── heads/
│           ├── main            — reflog de main (3 entries por los 3 commits)
│           └── feature/x       — reflog de feature/x
├── objects/
│   ├── XX/YYYYYY…              — objetos sueltos (blobs, trees, commits, tag)
│   ├── info/                   — metadata; vacío
│   └── pack/                   — vacío si no se corrió `git gc`
├── packed-refs                 — presente si se ejecutó `git pack-refs`; aquí típicamente ausente
└── refs/
    ├── heads/
    │   ├── main                — hash del commit 3
    │   └── feature/x           — hash del commit "feature/x"
    └── tags/
        └── v0.1                — hash de un OBJETO TAG (annotated); NO del commit 2
```

## B. Diagrama de objetos

```
HEAD → ref: refs/heads/main
                         │
                         ▼
                    commit_3  ──parent──> commit_2  ──parent──> commit_1  (root)
                    (main)                   ^
                                             │
                                        refs/tags/v0.1 → tag_obj (annotated)
                                                                ↓ (points to)
                                                             commit_2

refs/heads/feature/x → commit_fx ──parent──> commit_2 (shared with main)

Para cada commit, sus trees + blobs:

commit_1
  tree_1 ─ 100644 blob_readme1  "README.md"

commit_2
  tree_2 ─ 100644 blob_readme1  "README.md"
          └─ 040000 tree_src   "src/"
                     └─ 100644 blob_app  "app.py"

commit_3
  tree_3 ─ 100644 blob_readme2  "README.md"   ← nuevo blob (contenido cambió)
          └─ 040000 tree_src    "src/"         ← MISMO tree reutilizado (no cambió)
                     └─ 100644 blob_app  "app.py"

commit_fx (feature/x)
  tree_fx ─ 100644 blob_readme1  "README.md"  (igual a commit_2)
           ├─ 040000 tree_src     "src/"       (igual a commit_2)
           │          └─ 100644 blob_app  "app.py"
           └─ 040000 tree_feature "feature/"
                      └─ 100644 blob_future  "future.md"
```

## Preguntas (respuestas)

**1. Blobs únicos.**
Esperado: **4**.
- `blob_readme1` (README original, en commit_1 y commit_2 y commit_fx)
- `blob_readme2` (README después de añadir nota, en commit_3)
- `blob_app` (`src/app.py`, usado en commit_2, commit_3 y commit_fx)
- `blob_future` (`feature/future.md`, solo en commit_fx)

Verifica:
```bash
find .git/objects -type f -not -path '*/pack/*' | \
  awk -F/ '{print $(NF-1)$NF}' | \
  while read h; do echo "$(git cat-file -t "$h") $h"; done | \
  sort | uniq -c | awk '$2=="blob"'
```

**2. Trees únicos.**
Esperado: **5–6** (depende de cómo Git deduplica):
- `tree_1` (solo README)
- `tree_src` (solo `app.py`) — compartido por commit_2, commit_3, commit_fx
- `tree_2` (README + src/) — commit_2
- `tree_3` (README nuevo + src/) — commit_3
- `tree_feature` (solo `future.md`)
- `tree_fx` (README + src/ + feature/)

Verifica con el mismo pipeline cambiando `$2=="tree"`.

**3. Commits y tags.**
- **4 commits**: 3 en main (incluyendo el root) + 1 en feature/x. Nota: feature/x comparte commit_2 con main — no se cuenta dos veces.
- **1 tag object** (annotated: `v0.1`).

Verifica:
```bash
# commits
git rev-list --all --count
# tag objects
find .git/objects -type f -not -path '*/pack/*' | \
  awk -F/ '{print $(NF-1)$NF}' | \
  while read h; do git cat-file -t "$h"; done | sort | uniq -c
```

**4. Verificación.** El pipeline del punto anterior responde las tres preguntas (blob/tree/commit/tag counts).

**5. Tag annotated vs lightweight.**
`refs/tags/v0.1` apunta a un **objeto tag** (annotated), no directamente al commit. Verifica:
```bash
cat .git/refs/tags/v0.1          # hash
git cat-file -t $(cat .git/refs/tags/v0.1)   # "tag" (annotated) vs "commit" (lightweight)
git cat-file -p $(cat .git/refs/tags/v0.1)   # muestra tagger, mensaje, apunta a commit_2
```
Si hubiera sido lightweight (`git tag v0.1` sin `-a`), el tipo sería `commit` directamente.

**6. Borrar `refs/heads/feature/x`.**
Los commits de la rama **no se pierden inmediatamente**:
- Siguen en `.git/objects/` hasta la próxima `git gc` (con TTL por defecto ~30 días para unreachable).
- `logs/refs/heads/feature/x` sigue existiendo brevemente, útil para recuperar vía `reflog`.
- Mientras algún proceso los mantenga vivos (reflog, otra ref, worktree), sobreviven.

```bash
# Antes
git log --oneline feature/x
# Borrar la ref
rm .git/refs/heads/feature/x
# El commit sigue accesible por hash
git cat-file -t <commit_fx_hash>   # commit
# Recuperable: git branch feature/x <hash>
```

**7. Tras `git gc`.**
- Los objetos sueltos se empaquetan en `.git/objects/pack/pack-*.pack` + `.idx`.
- `find .git/objects -type f -not -path '*/pack/*'` muestra muy pocos o ninguno.
- Objetos **unreachable** más viejos que `gc.pruneExpire` (default 2 weeks) se eliminan.
- Los commits accesibles desde refs siguen funcionando — Git los sirve desde el pack transparentemente.

```bash
git gc
ls .git/objects/pack/
find .git/objects -type f -not -path '*/pack/*' | wc -l  # debería caer a 0 o cerca
git log --oneline main   # sigue funcionando
```

---

## Notas para quien autoevalúa

Si tu `MAP.md`:
- Cubre todas las entradas A y las relaciones B ≈ comprensión sólida.
- Falta la distinción annotated/lightweight en pregunta 5 → re-leer sección 4.2 de la lección.
- Afirma que borrar la ref borra los commits "al instante" → re-leer pregunta 6 y referirse al prompt del módulo `gh-10 Recovery`.
- Confunde "tree" con "directorio del filesystem" → re-leer sección 4.2.
