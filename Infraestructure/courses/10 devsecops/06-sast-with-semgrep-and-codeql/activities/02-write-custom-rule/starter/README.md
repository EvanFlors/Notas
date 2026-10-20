# Starter — sec-06-02-write-custom-rule

Esta actividad es escribir una regla + fixture + doc. No hay código a ejecutar más allá de `semgrep --test`.

## Pasos

1. Lee `../README.md`.
2. Prepara el scratch:
   ```bash
   rm -rf /tmp/sec-06-02-custom-rule
   mkdir -p /tmp/sec-06-02-custom-rule/.semgrep
   cd /tmp/sec-06-02-custom-rule
   ```
3. Escribe `.semgrep/no-requests-without-timeout.yml`.
4. Escribe `.semgrep/no-requests-without-timeout.test.py` con ≥3 `ruleid:` y ≥3 `ok:`.
5. (Opcional) `semgrep --test .semgrep/` — debe pasar.
6. Escribe `TEMPLATE.md` con las 4 secciones (qué detecta, cuándo suprimir, cuándo migrar al wrapper, dueño).
7. Valida:
   ```bash
   bash <ruta-repo>/courses/devsecops/06-sast-with-semgrep-and-codeql/activities/02-write-custom-rule/tests/validate.sh /tmp/sec-06-02-custom-rule
   ```
8. Compara con `../solution/`.
9. Limpia: `rm -rf /tmp/sec-06-02-custom-rule`.
