# Ejemplo 03 — Tags y ejecución selectiva

Un playbook con tres grupos de tasks etiquetados. Permite correr solo lo necesario (p. ej. solo "config" tras cambiar la plantilla, sin reinstalar).

## Ejecutar

```bash
ansible-playbook -i inventory.ini playbook.yml --list-tags
ansible-playbook -i inventory.ini playbook.yml --tags config
ansible-playbook -i inventory.ini playbook.yml --skip-tags install
```

## Observaciones

- `--list-tags` enumera los tags disponibles sin ejecutar nada.
- Un task con `tags: [always]` se ejecuta siempre, incluso cuando filtras por otro tag.
- Los tags son herramientas de **operación**, no de modelado: no abuses de ellos para codificar lógica de negocio.
