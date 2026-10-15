# Recursos — gh-03

## Documentación oficial

- **`git-branch(1)`** — crear, listar, borrar, renombrar ramas. <https://git-scm.com/docs/git-branch>
- **`git-switch(1)`** — cambiar de rama (moderno, desde 2.23). <https://git-scm.com/docs/git-switch>
- **`git-checkout(1)`** — equivalente legacy (sigue siendo útil leer). <https://git-scm.com/docs/git-checkout>
- **`git-merge(1)`** — fast-forward, 3-way, flags (`--no-ff`, `--ff-only`, `--squash`, `--abort`). <https://git-scm.com/docs/git-merge>
- **`git-mergetool(1)`** — GUI tools de 3-way merge. <https://git-scm.com/docs/git-mergetool>
- **`git-log(1)`** — opciones `--graph`, `--all`, `--decorate`, `--merges`, `--oneline`. <https://git-scm.com/docs/git-log>
- **`gitrevisions(7)`** — sintaxis `HEAD~1`, `main..feature`, `main...feature`, `:1:path`, etc. <https://git-scm.com/docs/gitrevisions>

## Pro Git (libro)

- **Capítulo 3: Git Branching** — introducción canónica al modelo de ramas. <https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell>
- **3.2 Basic Branching and Merging**. <https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging>
- **3.3 Branch Management**. <https://git-scm.com/book/en/v2/Git-Branching-Branch-Management>
- **7.8 Advanced Merging** — estrategias, `rerere`, resolución compleja. <https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging>

## Release notes relevantes

- **Git 2.23 Release Notes** — introducción de `git switch` y `git restore`. <https://github.com/git/git/blob/master/Documentation/RelNotes/2.23.0.txt>

## Herramientas y configuración relacionadas

- **`merge.conflictStyle = diff3`** — qué cambia y por qué recomendamos activarlo. <https://git-scm.com/docs/git-config#Documentation/git-config.txt-mergeconflictStyle>
- **`git rerere`** — reuse recorded resolution (reduce fricción con conflictos recurrentes). <https://git-scm.com/docs/git-rerere>
- **`gitattributes(5)`** — `merge=union`, `merge=ours`, drivers de merge por path (lo exploramos en `gh-11`). <https://git-scm.com/docs/gitattributes>

## Lectura complementaria

- *Think Like (a) Git* — modelo mental de refs y DAG (gratuito). <https://think-like-a-git.net/>
- *Learn Git Branching* — tutorial interactivo visual. <https://learngitbranching.js.org/>
- *A successful Git branching model* (Vincent Driessen, GitFlow) — por contraste con trunk-based; relevante para `gh-08`. <https://nvie.com/posts/a-successful-git-branching-model/>
