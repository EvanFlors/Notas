# Recursos — capstone etapa 3 (CI calidad + seguridad)

## GitHub Actions

- **Workflow syntax** — https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- **Permissions (minimo privilegio)** — https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs
- **OIDC con cloud providers** — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- **Code Scanning (upload-sarif)** — https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github
- **codeql-action/upload-sarif** — https://github.com/github/codeql-action

## Lint y tipos

- **Ruff** — https://docs.astral.sh/ruff/
- **Ruff rules** — https://docs.astral.sh/ruff/rules/
- **mypy** — https://mypy.readthedocs.io/en/stable/
- **mypy strict mode** — https://mypy.readthedocs.io/en/stable/command_line.html#cmdoption-mypy-strict

## Tests y coverage

- **pytest** — https://docs.pytest.org/en/stable/
- **pytest-cov** — https://pytest-cov.readthedocs.io/en/latest/
- **diff-cover** — https://github.com/Bachmann1234/diff_cover

## SAST / SCA / secretos

- **Bandit** — https://bandit.readthedocs.io/en/latest/
- **Bandit SARIF formatter** — https://pypi.org/project/bandit-sarif-formatter/
- **pip-audit** — https://pypi.org/project/pip-audit/
- **pip-audit (PyPA)** — https://github.com/pypa/pip-audit
- **gitleaks** — https://github.com/gitleaks/gitleaks
- **gitleaks-action** — https://github.com/gitleaks/gitleaks-action

## SARIF y Code Scanning

- **SARIF 2.1.0 spec** — https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
- **Code Scanning REST API** — https://docs.github.com/en/rest/code-scanning

## Lectura recomendada

- **Securing GitHub Actions supply chain (OpenSSF)** — https://openssf.org/blog/
- **Conventional Commits** — https://www.conventionalcommits.org/
- **GitHub Actions pinning (StepSecurity)** — https://www.stepsecurity.io/blog/pinning-github-actions-for-enhanced-security
