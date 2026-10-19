# Starter — gl-06-01

Crea `/tmp/gl-06-runner-k8s/` y produce estos cuatro archivos:

- `values.yaml` — valores del chart `gitlab/gitlab-runner`.
- `config.toml` — configuración standalone equivalente.
- `.gitlab-ci.yml` — pipeline mínimo con tag `k8s` y build con Kaniko.
- `NOTES.md` — tres secciones justificativas (ver README §5.5).

Guías rápidas:

- Para `values.yaml`, parte del ejemplo `../../examples/01-k8s-executor-chart/README.md` y recórtalo a lo mínimo que exige el validador.
- Para `config.toml`, usa doble-corchete `[[runners]]` (list of tables) y anidamiento `[runners.kubernetes]`.
- Para `.gitlab-ci.yml`, recuerda `tags:` por job y `image: gcr.io/kaniko-project/executor:v1.23.0-debug` con `entrypoint: [""]`.
- Para `NOTES.md`, los encabezados exactos son `## Decisión`, `## Por qué no DinD`, `## Cache S3 e IRSA`.

Valida con:

```bash
bash ../tests/validate.sh /tmp/gl-06-runner-k8s
```
