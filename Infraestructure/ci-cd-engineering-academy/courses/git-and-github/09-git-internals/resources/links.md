# Recursos — gh-09

## Documentación oficial

- **`gitrepository-layout(5)`** — layout de `.git/`. <https://git-scm.com/docs/gitrepository-layout>
- **`git-hash-object(1)`** — calcular hash y opcionalmente escribir blob. <https://git-scm.com/docs/git-hash-object>
- **`git-cat-file(1)`** — inspeccionar cualquier objeto. <https://git-scm.com/docs/git-cat-file>
- **`git-mktree(1)`** — construir un tree desde stdin. <https://git-scm.com/docs/git-mktree>
- **`git-write-tree(1)`** — construir un tree desde el index. <https://git-scm.com/docs/git-write-tree>
- **`git-commit-tree(1)`** — crear un commit desde un tree. <https://git-scm.com/docs/git-commit-tree>
- **`git-update-ref(1)`** — mover refs de forma segura. <https://git-scm.com/docs/git-update-ref>
- **`git-ls-tree(1)`** — listar contenido de trees. <https://git-scm.com/docs/git-ls-tree>
- **`git-rev-parse(1)`** — resolver cualquier revspec a hash. <https://git-scm.com/docs/git-rev-parse>
- **`git-fsck(1)`**. <https://git-scm.com/docs/git-fsck>
- **`git-gc(1)`**. <https://git-scm.com/docs/git-gc>
- **`git-maintenance(1)`**. <https://git-scm.com/docs/git-maintenance>
- **`git-prune(1)`** / **`git-prune-packed(1)`**. <https://git-scm.com/docs/git-prune>
- **`git-verify-pack(1)`**. <https://git-scm.com/docs/git-verify-pack>
- **`git-repack(1)`**. <https://git-scm.com/docs/git-repack>
- **`gitformat-pack(5)`** — formato on-disk de un packfile. <https://git-scm.com/docs/gitformat-pack>

## Pro Git (libro)

- **Capítulo 10 — Git Internals**. <https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain>
- **10.2 — Git Objects**. <https://git-scm.com/book/en/v2/Git-Internals-Git-Objects>
- **10.3 — Git References**. <https://git-scm.com/book/en/v2/Git-Internals-Git-References>
- **10.4 — Packfiles**. <https://git-scm.com/book/en/v2/Git-Internals-Packfiles>
- **10.7 — Maintenance and Data Recovery**. <https://git-scm.com/book/en/v2/Git-Internals-Maintenance-and-Data-Recovery>

## Hash function transition

- **Hash function transition design doc**. <https://git-scm.com/docs/hash-function-transition>
- **Marc Stevens — SHAttered (2017)**. <https://shattered.io/>
- **`sha1dc`** (SHA-1 collision detection, Marc Stevens). <https://github.com/cr-marcstevens/sha1collisiondetection>

## Herramientas y lecturas complementarias

- **Scalar** (Microsoft) — partial clone + sparse + maintenance preconfigurados. <https://github.com/microsoft/scalar>
- **Git LFS** — se cubre en `gh-11`, pero su integración con el object store es relevante aquí. <https://git-lfs.com/>
- **"Git from the inside out"** — Mary Rose Cook (lectura muy clara del modelo). <https://maryrosecook.com/blog/post/git-from-the-inside-out>
- **"Understanding git packfiles"** — ThoughtBot. <https://thoughtbot.com/blog/understanding-git-packfiles>
