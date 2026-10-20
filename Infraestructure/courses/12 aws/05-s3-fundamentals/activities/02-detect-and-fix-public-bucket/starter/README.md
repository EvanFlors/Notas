# Starter — aws-05-02-detect-and-fix-public-bucket

En este directorio tienes 3 ficheros JSON que describen el estado **actual** del bucket que debes auditar:

- `bucket-config.json` — settings a nivel bucket: BPA, ownership, versioning, acl canonica.
- `bucket-policy-current.json` — bucket policy aplicada hoy.
- `object-acl-sample.json` — ACL de un objeto representativo (una imagen de campaña).

## Pasos

1. Lee `../README.md`.
2. Copia los JSON al working dir:

   ```bash
   mkdir -p /tmp/aws-05-audit
   cp *.json /tmp/aws-05-audit/
   cd /tmp/aws-05-audit
   ```

3. Produce:
   - `AUDIT.md` (secciones A, B, C, Preguntas)
   - `policy-fixed.json`
   - `bpa-fixed.json`

4. Valida:

   ```bash
   bash <ruta-repo>/courses/aws/05-s3-fundamentals/activities/02-detect-and-fix-public-bucket/tests/validate.sh /tmp/aws-05-audit
   ```

5. Compara con `../solution/REFERENCE.md`.
