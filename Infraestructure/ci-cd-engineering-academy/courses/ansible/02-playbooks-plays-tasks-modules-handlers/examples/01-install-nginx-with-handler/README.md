# Ejemplo 01 — Instalar nginx con handler

Play completa que:

1. Instala nginx (`apt`).
2. Publica `/etc/nginx/sites-available/example.conf` desde una plantilla.
3. Habilita el sitio con `file` (symlink).
4. Notifica al handler **Reload nginx** solo si la plantilla cambió.
5. Garantiza que nginx está arrancado.

## Ejecutar

Contra el propio host (requiere Debian/Ubuntu con sudo):

```bash
ansible-playbook -i inventory.ini playbook.yml --check --diff   # dry-run
ansible-playbook -i inventory.ini playbook.yml                   # aplicar
ansible-playbook -i inventory.ini playbook.yml                   # 2a vuelta: 0 changed
```

## Puntos a observar

- La **primera ejecución** reporta `changed` en la instalación y en la plantilla; el handler se dispara al final.
- La **segunda ejecución** reporta todo `ok=…  changed=0`. **No se recarga nginx** porque nadie lo notificó.
- Si editas la plantilla manualmente y vuelves a correr: el módulo `template` detecta el drift, lo reconvierte y vuelve a disparar el handler.
