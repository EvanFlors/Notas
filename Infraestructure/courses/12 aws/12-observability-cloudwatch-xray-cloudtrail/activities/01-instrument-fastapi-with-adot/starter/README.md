# Starter — aws-12-01-instrument-fastapi-with-adot

Esta actividad produce dos ficheros:

- `/tmp/aws-12-adot/config.yaml` — la configuración del ADOT Collector.
- `/tmp/aws-12-adot/NOTES.md` — justificación en 5 bullets numerados.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio y copia la plantilla:
   ```bash
   mkdir -p /tmp/aws-12-adot
   cp starter/config.yaml /tmp/aws-12-adot/config.yaml
   ```
3. Abre `config.yaml` y rellena los `# TODO` siguiendo las instrucciones del README principal.
4. Crea `NOTES.md` con **al menos 5 bullets numerados** (`1.` a `5.`) que respondan a las preguntas de la sección 5.3.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/12-observability-cloudwatch-xray-cloudtrail/activities/01-instrument-fastapi-with-adot/tests/validate.sh /tmp/aws-12-adot
   ```
6. Autoevalúate con `../solution/REFERENCE.md`.
