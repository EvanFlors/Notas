# Reference — ans-03-01-nginx-vhost-template

Solucion de referencia para autoevaluacion. **No la mires antes de intentar la actividad.**

## Que debe tener la plantilla

- Cabecera `# {{ ansible_managed }}` (sustituida por `# Ansible managed` al renderizar).
- Un bloque `upstream backend` iterado con `{% for u in vhost_upstreams %}` y whitespace control (`{%- -%}`).
- Un `server` con `listen {{ vhost_listen_port }};` y `server_name {{ vhost_server_name }};`.
- Un `location /` con `proxy_pass http://backend;`.

## Por que `{%- %}` y no `{% %}`

Sin whitespace control, cada iteracion del `for` deja una linea en blanco por el newline que sigue al tag `{% for %}`. El resultado es un `upstream { }` con huecos visuales y, peor, con la primera linea desplazada. `{%- %}` elimina ese newline.

## Por que `vars:` en el playbook y no `group_vars/`

En esta actividad hay un unico "host" (localhost) y es un ejercicio didactico. En un setup real pondrias `vhost_server_name` en `group_vars/web.yml` (por entorno) y `vhost_listen_port` como `defaults/main.yml` del role. Aqui esta inline por simplicidad.

## Comando util para probar override por extra vars

```bash
ansible-playbook -i inventory.ini playbook.yml -e vhost_server_name=otro.local
grep server_name output/vhost.conf
```

Deberias ver `server_name otro.local;`. Esto demuestra que `extra vars` (nivel 21) gana contra `vars:` del playbook (nivel 11).
