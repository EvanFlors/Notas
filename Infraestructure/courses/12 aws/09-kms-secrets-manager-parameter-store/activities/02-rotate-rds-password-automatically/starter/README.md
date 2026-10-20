# Starter — aws-09-02-rotate-rds-password-automatically

Esta actividad es **independiente** y **documental**: no hay código ni infra que levantar. Tu entregable es un `ROTATION.md`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el scratch:
   ```bash
   mkdir -p /tmp/aws-09-rotate-rds
   cd /tmp/aws-09-rotate-rds
   ```
3. Crea `ROTATION.md` con las 6 secciones (A..F). Puedes usar `ROTATION.template.md` de este directorio como punto de partida.
4. Valida:
   ```bash
   bash ../tests/validate.sh /tmp/aws-09-rotate-rds
   ```
5. Compara con `../solution/REFERENCE.md`.

> **Importante:** el validador comprueba **estructura** (headings, palabras clave, filas de la tabla). La corrección semántica la revisas tú.
>
> Nunca pongas secretos reales. Usa valores etiquetados `fake-` / `NOT-REAL`.
