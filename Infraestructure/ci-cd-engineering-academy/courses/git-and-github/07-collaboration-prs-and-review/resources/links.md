# Recursos — gh-07

## Documentación oficial de GitHub

- **About pull requests** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests>
- **Creating a pull request from a fork** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork>
- **About pull request merges** (merge strategies) — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges>
- **Automatically merging a pull request** (auto-merge) — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request>
- **Creating a pull request template for your repository** — <https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository>
- **Linking a pull request to an issue** (closing keywords) — <https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue>
- **About code owners (`CODEOWNERS`)** — <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- **About protected branches** — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- **About rulesets** (sustituto moderno de branch protection) — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- **Reviewing changes in pull requests** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews>

## `gh` CLI

- **`gh pr` reference** — <https://cli.github.com/manual/gh_pr>
- **`gh pr create`** — <https://cli.github.com/manual/gh_pr_create>
- **`gh pr review`** — <https://cli.github.com/manual/gh_pr_review>
- **`gh pr merge`** — <https://cli.github.com/manual/gh_pr_merge>
- **`gh api`** (CODEOWNERS errors endpoint) — <https://cli.github.com/manual/gh_api>

## Lectura recomendada

- **Pro Git** cap. 6 "GitHub" — <https://git-scm.com/book/en/v2/GitHub-Account-Setup-and-Configuration>
- **How to Write a Git Commit Message**, Chris Beams — <https://cbea.ms/git-commit/>
- **Code Review Developer Guide**, Google eng-practices — <https://google.github.io/eng-practices/review/>
- **Pull Requests at Scale**, varios engineering blogs; buscar "code review guidelines <org>".

## Especificaciones y referencias técnicas

- **CODEOWNERS pattern syntax** (sección "CODEOWNERS syntax" en la doc de GitHub, incluye limitaciones vs `.gitignore`).
- **Refs convention**: ver `git ls-remote origin 'refs/pull/*/head'` en cualquier repo con PRs.
- **GitHub Flow** — <https://docs.github.com/en/get-started/using-github/github-flow>

## Herramientas complementarias

- `gh` CLI — <https://cli.github.com/>
- `pre-commit` (para validar mensajes/formato antes del PR) — <https://pre-commit.com/>
- `conventional-pre-commit` hook — <https://github.com/compilerla/conventional-pre-commit>
