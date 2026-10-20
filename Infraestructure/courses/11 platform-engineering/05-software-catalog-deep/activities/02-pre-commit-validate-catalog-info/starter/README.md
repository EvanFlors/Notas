# Starter — plat-05-02-pre-commit-validate-catalog-info

Esta actividad es **independiente**: no hay código base que ejecutar. Tu entregable es un hook Bash + fixtures + un `install.md`.

## Pasos

1. Lee `../README.md` completo.
2. Verifica que `python3` tiene `pyyaml`:
   ```bash
   python3 -c "import yaml; print(yaml.__version__)"
   ```
   Si falta, instala: `pip3 install pyyaml`.
3. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-05-precommit/fixtures
   cd /tmp/plat-05-precommit
   ```
4. Crea:
   - `validate-catalog-info.sh` (ejecutable, shebang, usa `python3` + `pyyaml`).
   - `install.md` (documenta ambas opciones de instalación).
   - `fixtures/good-component.yaml` y `fixtures/bad-*.yaml` cubriendo los 4 errores comunes del README.
5. Prueba tu hook manualmente:
   ```bash
   bash validate-catalog-info.sh fixtures/good-component.yaml    # debe salir 0
   bash validate-catalog-info.sh fixtures/bad-missing-owner.yaml # debe salir 1
   ```
6. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/05-software-catalog-deep/activities/02-pre-commit-validate-catalog-info/tests/validate.sh /tmp/plat-05-precommit
   ```
7. Compara tu hook con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba que el hook rechaza los `bad-*` y acepta el `good`. Si tu hook es permisivo con un `bad-*` o estricto con el `good`, falla.
