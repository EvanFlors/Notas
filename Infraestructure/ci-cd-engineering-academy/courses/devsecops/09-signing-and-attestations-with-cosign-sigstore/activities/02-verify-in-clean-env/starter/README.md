# Starter — sec-09-02-verify-in-clean-env

Esta actividad es **independiente**: no hay código. Tu entregable es `VERIFY-POLICY.md`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-09-02-verify && cd /tmp/sec-09-02-verify
   ```
3. Crea `VERIFY-POLICY.md` con las 4 secciones (A, B, C, D).
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/09-signing-and-attestations-with-cosign-sigstore/activities/02-verify-in-clean-env/tests/validate.sh /tmp/sec-09-02-verify
   ```
5. Compara con `../solution/REFERENCE.md`.

> El validador comprueba estructura (secciones + flags obligatorios + anclas del regex). La corrección semántica la revisas tú contra la referencia.
