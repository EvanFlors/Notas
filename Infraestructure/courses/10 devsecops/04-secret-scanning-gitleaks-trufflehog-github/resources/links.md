# Recursos — sec-04

Referencias oficiales. Verificar vigencia antes de un deployment productivo.

## gitleaks

- Repo: `https://github.com/gitleaks/gitleaks`
- Config reference: `https://github.com/gitleaks/gitleaks#configuration`
- GitHub Action: `https://github.com/gitleaks/gitleaks-action`

## trufflehog

- Repo: `https://github.com/trufflesecurity/trufflehog`
- Docs: `https://docs.trufflesecurity.com/`
- GitHub Action: `https://github.com/trufflesecurity/trufflehog`

## GitHub secret scanning

- Visión general: `https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning`
- Push protection: `https://docs.github.com/en/code-security/secret-scanning/push-protection-for-repositories-and-organizations`
- Partner program (proveedores que reciben alertas): `https://docs.github.com/en/code-security/secret-scanning/secret-scanning-partner-program`

## Reescritura de historia

- `git filter-repo`: `https://github.com/newren/git-filter-repo`
- BFG Repo-Cleaner: `https://rtyley.github.io/bfg-repo-cleaner/`
- GitHub guide "Removing sensitive data from a repository": `https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository`

## pre-commit framework

- Sitio: `https://pre-commit.com/`
- Hook de gitleaks: `https://github.com/gitleaks/gitleaks/blob/master/.pre-commit-hooks.yaml`

## Incidentes reales (lecturas)

- Uber 2016 — AWS key en repo privado → brecha de 57M registros.
- Toyota 2022 — credencial en repo público 5 años → datos de 300k clientes expuestos.
- Fallout de scraping bots sobre GitHub (medir en segundos, no minutos).
