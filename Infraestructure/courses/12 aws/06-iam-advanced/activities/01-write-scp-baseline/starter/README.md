# Starter — aws-06-01-write-scp-baseline

No hay plantilla ejecutable. Tus entregables son JSON escritos a mano y un documento Markdown.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-06-scp-baseline/policies
   cd /tmp/aws-06-scp-baseline
   ```
3. Escribe los tres JSON y el `BASELINE.md` según las instrucciones.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/06-iam-advanced/activities/01-write-scp-baseline/tests/validate.sh /tmp/aws-06-scp-baseline
   ```
5. Compara con `../solution/REFERENCE.md` y `../solution/policies/`.
6. Limpia:
   ```bash
   rm -rf /tmp/aws-06-scp-baseline
   ```

> El validador comprueba estructura (JSON válido + claves esperadas). La semántica (ataque prevenido, elección de condition) la revisas tú contra la referencia.
