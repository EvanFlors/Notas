# Contribuir

Este repositorio es un programa de estudio. Las contribuciones típicas son:

- Añadir una lección o módulo nuevo siguiendo `templates/module-template.md`.
- Añadir una actividad siguiendo `templates/activity-template.md` y `activity.yaml`.
- Corregir imprecisiones técnicas o actualizar versiones.

## Reglas

1. Usa Markdown y kebab-case para archivos/carpetas.
2. Un ID estable por módulo y actividad. No renombrar sin motivo.
3. Separar `starter/`, `tests/`, `solution/` en cada actividad.
4. Nada de secretos reales (ni ejemplos "ilustrativos" con claves de aspecto real).
5. Indicar versión de la herramienta usada y verificar contra documentación oficial.
6. Soluciones nunca se revelan en el enunciado de ejercicios independientes.

## Validación

Antes de enviar cambios ejecutar:

```bash
python scripts/validate-activities.py
```
