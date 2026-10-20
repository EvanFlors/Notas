# Starter — sec-04-01

Esta actividad no provee código inicial. Debes crear tu propio directorio en
`/tmp/sec-04-full-pipeline/` siguiendo los pasos de `../README.md`.

Un esqueleto sugerido:

```
/tmp/sec-04-full-pipeline/
├── .git/                        # git init -b main
├── .pre-commit-config.yaml
├── .gitleaks.toml
├── .github/workflows/secret-scan.yml
├── tests/fixtures/sample.env    # fakes obvios
└── RUNBOOK.md
```

Consulta `../../examples/01-pre-commit-gitleaks/` y `../../examples/02-ci-full-history-scan/`
para plantillas de los archivos de configuración.

Cuando termines:

```bash
bash ../tests/validate.sh /tmp/sec-04-full-pipeline
```
