# Recursos — gh-11

## Documentación oficial — Hooks

- **`githooks(5)`** — catálogo completo de hooks. <https://git-scm.com/docs/githooks>
- *Pro Git* cap. 7.4 "Git Hooks". <https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks>
- *Pro Git* cap. 8.3 "Example Git-Enforced Policy" (hooks de servidor). <https://git-scm.com/book/en/v2/Customizing-Git-An-Example-Git-Enforced-Policy>

## Framework `pre-commit`

- Sitio oficial. <https://pre-commit.com/>
- Catálogo de hooks mantenidos oficialmente. <https://github.com/pre-commit/pre-commit-hooks>
- `ruff-pre-commit` (lint + format Python). <https://github.com/astral-sh/ruff-pre-commit>
- `black` pre-commit. <https://black.readthedocs.io/en/stable/integrations/source_version_control.html>
- `trufflehog` (secret scanning). <https://github.com/trufflesecurity/trufflehog>
- `gitleaks` (alternativa). <https://github.com/gitleaks/gitleaks>
- `conventional-pre-commit`. <https://github.com/compilerla/conventional-pre-commit>

## Alternativas al framework (otros ecosistemas)

- **Husky** (JavaScript). <https://typicode.github.io/husky/>
- **lefthook** (multi-lenguaje, Go, muy rápido). <https://github.com/evilmartians/lefthook>

## Submódulos

- `git-submodule(1)`. <https://git-scm.com/docs/git-submodule>
- *Pro Git* cap. 7.11 "Submodules". <https://git-scm.com/book/en/v2/Git-Tools-Submodules>
- Blog "Why your company shouldn't use Git submodules" (perspectiva crítica útil). <https://medium.com/@porteneuve/mastering-git-submodules-34c65e940407>

## Subtrees

- `git-subtree(1)`. <https://git-scm.com/docs/git-subtree>
- Atlassian tutorial "Git subtree". <https://www.atlassian.com/git/tutorials/git-subtree>

## Monorepo tooling

- Bazel. <https://bazel.build/>
- Nx. <https://nx.dev/>
- Turborepo. <https://turbo.build/repo>
- Pants. <https://www.pantsbuild.org/>
- Google "Why Google stores billions of lines of code in a single repository" (CACM, 2016). <https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext>

## Git LFS

- Sitio oficial y docs. <https://git-lfs.com/>
- `git-lfs` spec. <https://github.com/git-lfs/git-lfs/tree/main/docs>
- Comando `git lfs migrate`. <https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-migrate.adoc>
- GitHub docs sobre LFS billing. <https://docs.github.com/en/billing/managing-billing-for-git-large-file-storage>

## Repos grandes: sparse / partial / Scalar

- `git-sparse-checkout(1)`. <https://git-scm.com/docs/git-sparse-checkout>
- `git-clone(1)` sección `--filter`. <https://git-scm.com/docs/git-clone>
- Partial clone design. <https://git-scm.com/docs/partial-clone>
- `git-maintenance(1)`. <https://git-scm.com/docs/git-maintenance>
- `scalar(1)` (integrado en Git ≥ 2.38). <https://git-scm.com/docs/scalar>
- GitHub blog: "Get up to speed with partial clone and shallow clone". <https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/>
- `git-sizer`. <https://github.com/github/git-sizer>

## Transporte offline

- `git-bundle(1)`. <https://git-scm.com/docs/git-bundle>

## Alternativas a LFS (contexto)

- `git-annex`. <https://git-annex.branchable.com/>
- `dvc` (Data Version Control). <https://dvc.org/>
