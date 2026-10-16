# Starter — sec-12-02-rule-authoring-exercise

Esta actividad es **100 % offline**: produces un YAML (reglas Falco) y un documento Markdown.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio y copia las plantillas:
   ```bash
   mkdir -p /tmp/sec-12-rule
   cp TEMPLATE.md /tmp/sec-12-rule/RULES.md
   cp custom-rules.template.yaml /tmp/sec-12-rule/custom-rules.yaml
   ```
3. Edita ambos para cubrir el caso de dominio (`chmod` permisivo bajo `/var/log`).
4. Valida:
   ```bash
   bash ../tests/validate.sh /tmp/sec-12-rule
   ```
5. Compara con `../solution/REFERENCE.md` y `../solution/custom-rules.yaml` para autoevaluarte.

Archivos en este starter:

- `TEMPLATE.md` — esqueleto de `RULES.md` con las 4 secciones.
- `custom-rules.template.yaml` — esqueleto YAML con una regla a completar.
