# Starter — plat-06-02-test-template-in-ci

Esta actividad es **independiente**: trae un paquete casi completo con dos TODOs clave (script + workflow).

## Pasos

1. Lee `../README.md`.
2. Copia a `/tmp/plat-06-ci`:
   ```bash
   mkdir -p /tmp/plat-06-ci
   cp -r <ruta-repo>/courses/platform-engineering/06-templates-and-scaffolder/activities/02-test-template-in-ci/starter/* /tmp/plat-06-ci/
   cd /tmp/plat-06-ci
   ```
3. Completa `scripts/regenerate-fixture.sh` (los TODOs están marcados `# TODO:`).
4. Completa `.github/workflows/template-ci.yaml` (idem).
5. Valida:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/06-templates-and-scaffolder/activities/02-test-template-in-ci/tests/validate.sh /tmp/plat-06-ci
   ```

> El validador comprueba estructura + ejecuta el script si cookiecutter está instalado. Si no está, SKIP.
