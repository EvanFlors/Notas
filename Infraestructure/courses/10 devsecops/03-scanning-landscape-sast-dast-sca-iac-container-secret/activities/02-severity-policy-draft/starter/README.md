# Starter — sec-03-02-severity-policy-draft

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-03-policy
   cd /tmp/sec-03-policy
   ```
3. Crea `SEVERITY_POLICY.md` con las cuatro secciones:
   - A: taxonomía P0..P3 con SLA
   - B: matriz de asignación de prioridad (≥ 5 filas)
   - C: suppressions vs exceptions con campos obligatorios
   - D: proceso y métricas
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/03-scanning-landscape-sast-dast-sca-iac-container-secret/activities/02-severity-policy-draft/tests/validate.sh /tmp/sec-03-policy
   ```
5. Compara tu documento con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Limpieza

```bash
rm -rf /tmp/sec-03-policy
```
