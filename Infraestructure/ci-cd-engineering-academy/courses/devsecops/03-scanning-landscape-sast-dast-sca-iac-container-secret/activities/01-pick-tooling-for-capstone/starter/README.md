# Starter — sec-03-01-pick-tooling-for-capstone

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-03-tooling
   cd /tmp/sec-03-tooling
   ```
3. Crea `TOOLING.md` con las tres secciones:
   - A: matriz capa × herramienta (≥ 6 filas)
   - B: pipeline con gates
   - C: descartes y limitaciones (≥ 3)
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/03-scanning-landscape-sast-dast-sca-iac-container-secret/activities/01-pick-tooling-for-capstone/tests/validate.sh /tmp/sec-03-tooling
   ```
5. Compara tu documento con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Limpieza

```bash
rm -rf /tmp/sec-03-tooling
```
