# Starter — aws-02-02-assume-role-cross-session

Esta actividad no tiene código. Produces 3 JSON + 1 Markdown.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-02-chain
   cd /tmp/aws-02-chain
   ```
3. Crea:
   - `TRUST_OPERATOR.json`
   - `TRUST_PROD.json`
   - `PERM_PROD.json`
   - `SESSION.md`
4. Opcional: usa `../solution/TEMPLATE.md` como *scaffolding* vacío de secciones.
5. Valida:
   ```bash
   bash <repo>/courses/aws/02-iam-fundamentals/activities/02-assume-role-cross-session/tests/validate.sh /tmp/aws-02-chain
   ```
6. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** nunca pongas account IDs reales. Usa `111111111111`, `222222222222` o `123456789012`. El validador rechaza otros IDs de 12 dígitos.
