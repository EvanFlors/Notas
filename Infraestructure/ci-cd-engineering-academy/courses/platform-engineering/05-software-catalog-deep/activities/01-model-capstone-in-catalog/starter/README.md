# Starter — plat-05-01-model-capstone-in-catalog

Esta actividad es **independiente**: no hay código base que ejecutar. Tu entregable es un árbol de `catalog-info.yaml` escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Verifica que `python3` tiene `pyyaml`:
   ```bash
   python3 -c "import yaml; print(yaml.__version__)"
   ```
   Si falta, instala: `pip3 install pyyaml` (o `pip install pyyaml` en venv).
3. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-05-catalog
   cd /tmp/plat-05-catalog
   ```
4. Crea el árbol de `catalog-info.yaml` siguiendo §5 del README (mínimos: ≥3 Components, ≥2 APIs, ≥1 Resource, ≥1 System, ≥1 Domain, ≥2 Groups).
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/05-software-catalog-deep/activities/01-model-capstone-in-catalog/tests/validate.sh /tmp/plat-05-catalog
   ```
6. Compara tu árbol con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador verifica estructura (counts por kind, owners resueltos a Groups existentes, relaciones a entidades existentes, annotations mínimas) pero **no** semántica. La corrección conceptual la revisas tú contra la referencia.
