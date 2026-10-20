# Recursos — gh-06 Rebase vs merge e interactivo

## Documentación oficial

- `git-rebase(1)` — <https://git-scm.com/docs/git-rebase>
- `git-cherry-pick(1)` — <https://git-scm.com/docs/git-cherry-pick>
- `git-rerere(1)` — <https://git-scm.com/docs/git-rerere>
- `git-merge(1)` — <https://git-scm.com/docs/git-merge>
- `git-reflog(1)` — <https://git-scm.com/docs/git-reflog>
- `git-push(1)` (ver `--force-with-lease`, `--force-if-includes`) — <https://git-scm.com/docs/git-push>

## Libros y capítulos recomendados

- *Pro Git* (Scott Chacon, Ben Straub), 2.ª ed.:
  - cap. 3.6 — *Rebasing* <https://git-scm.com/book/en/v2/Git-Branching-Rebasing>
  - cap. 7.6 — *Rewriting history* <https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History>

## Artículos de referencia

- Atlassian — *Merging vs Rebasing* <https://www.atlassian.com/git/tutorials/merging-vs-rebasing>
- GitHub Docs — *About merge methods on GitHub* <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-merge-methods-on-github>
- GitHub Blog — *Rebase and merge pull requests* (histórico) <https://github.blog/open-source/git/rebase-and-merge-pull-requests/>
- Linus Torvalds — *On rebase* (lista del kernel, 2009) <https://lkml.org/lkml/2009/3/27/383>

## Release notes relevantes

- Git 2.38 — introduce `rebase --update-refs` <https://github.com/git/git/blob/master/Documentation/RelNotes/2.38.0.txt>
- Git 2.30 — mejoras varias en rebase; versión mínima recomendada para este módulo <https://github.com/git/git/blob/master/Documentation/RelNotes/2.30.0.txt>

## Tooling adicional (opcional)

- Graphite — stacked PRs sobre GitHub (usa rebase intensivamente) <https://graphite.dev/docs>
- Sapling — frontend alternativo (Meta) <https://sapling-scm.com/>
- Jujutsu (`jj`) — DVCS compatible con repos Git, reescritura como primitiva <https://github.com/jj-vcs/jj>

## Herramientas útiles

- `git log --graph --oneline --all --decorate` — vista rápida del DAG.
- `tig` — TUI para explorar historia Git <https://jonas.github.io/tig/>
- `gitk` / `git-gui` — vista gráfica incluida con Git.

## Snippets recomendados para `~/.gitconfig`

```ini
[pull]
    rebase = true
[rebase]
    autoStash = true
    autoSquash = true
    updateRefs = true
[rerere]
    enabled = true
[alias]
    fpush = push --force-with-lease --force-if-includes
    cleanup = rebase -i --autosquash
```
