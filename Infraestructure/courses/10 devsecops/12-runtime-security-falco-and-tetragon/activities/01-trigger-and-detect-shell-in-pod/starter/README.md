# Starter — sec-12-01-trigger-and-detect-shell-in-pod

Esta actividad produce un documento Markdown y, opcionalmente, un cluster `kind` con Falco. No hay código a compilar.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-12-detect
   cd /tmp/sec-12-detect
   ```
3. Elige camino A (con `kind`) o B (walkthrough con sample events). Las instrucciones están en §5.2 y §5.3 del README.
4. Escribe `DETECTION.md` con las cuatro secciones (A, B, C, D).
5. Valida la estructura:
   ```bash
   bash ../tests/validate.sh /tmp/sec-12-detect
   ```
6. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú.
