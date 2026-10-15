# Recursos — gh-04

## Documentación oficial

- **`git-remote`**. <https://git-scm.com/docs/git-remote>
- **`git-clone`** (incluye `--bare`, `--mirror`, `--depth`, `--filter`). <https://git-scm.com/docs/git-clone>
- **`git-fetch`** (incluye `--prune`, refspecs). <https://git-scm.com/docs/git-fetch>
- **`git-pull`** (incluye `--rebase`, `--ff-only`). <https://git-scm.com/docs/git-pull>
- **`git-push`** (incluye `-u`, `--force-with-lease`, `--delete`). <https://git-scm.com/docs/git-push>
- **`git-ls-remote`**. <https://git-scm.com/docs/git-ls-remote>
- **`git-init`** (sección `--bare`). <https://git-scm.com/docs/git-init>
- **`gitprotocol-pack(5)`** — protocolo que corre bajo fetch/push. <https://git-scm.com/docs/gitprotocol-pack>

## Pro Git (libro)

- Capítulo 2.5 "Working with Remotes". <https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes>
- Capítulo 3.5 "Remote Branches". <https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches>
- Capítulo 4 "Git on the Server" (setup real de un server bare + SSH). <https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols>

## Conceptos específicos

- **Refspecs explicadas**. <https://git-scm.com/book/en/v2/Git-Internals-The-Refspec>
- **Shallow / partial clones**: <https://git-scm.com/docs/partial-clone>
- **`core.bare` y por qué un server lo usa**: ver `git-init(1)` + sección "Bare repositories" en Pro Git cap. 4.
- **`--force` vs `--force-with-lease`**: <https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegt>

## Lecturas útiles

- Scott Chacon — "The Thing About Git" (artículo clásico sobre el modelo distribuido).
- Atlassian — "Syncing: git fetch/pull/push". <https://www.atlassian.com/git/tutorials/syncing>
- Julia Evans — zines y posts sobre `git fetch` vs `git pull`. <https://jvns.ca/>

## Lo que verás en los siguientes módulos

- `gh-05` — autenticación SSH y HTTPS/PAT con GitHub real; `gh` CLI.
- `gh-06` — rebase interactivo (profundiza el rebase que aquí usas plano).
- `gh-07` — pull requests y code review sobre lo que aquí es `push`.
- `gh-12` — branch protection y rulesets para prohibir force-push a `main` a nivel server.
