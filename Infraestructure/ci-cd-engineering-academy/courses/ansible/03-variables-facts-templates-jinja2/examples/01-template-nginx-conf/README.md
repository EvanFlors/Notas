# Ejemplo 01 — Render de `nginx.conf` desde una plantilla Jinja2

Demuestra cómo el módulo `ansible.builtin.template` toma una plantilla, le inyecta variables y escribe el archivo final. Todo corre en `localhost` y escribe en `/tmp/ans-03-nginx/` — no toca `/etc`.

## Archivos

- `inventory.ini` — un único host (`localhost`) con `ansible_connection=local`.
- `playbook.yml` — una play que renderiza la plantilla con unas variables definidas inline.
- `templates/nginx.conf.j2` — la plantilla, con 3 variables (`nginx_worker_processes`, `nginx_server_name`, `nginx_upstreams`) y un `for` que itera upstreams.

## Ejecutar

```bash
cd examples/01-template-nginx-conf
ansible-playbook -i inventory.ini playbook.yml
cat /tmp/ans-03-nginx/nginx.conf
```

Deberías ver el `nginx.conf` renderizado con los upstreams listados.

## Qué observar

- La cabecera `# {{ ansible_managed }}` se expande a algo como `# Ansible managed`.
- El loop `{% for u in nginx_upstreams %}` genera una línea por upstream, sin dejar líneas vacías gracias al `{%- %}`.
- Si cambias `nginx_worker_processes` a `4` en `playbook.yml` y vuelves a correr, verás `changed=1` (porque el archivo cambió) y el nuevo valor en el output.

## Variación

Añade más upstreams a `nginx_upstreams` y re-ejecuta. El template no cambia; solo cambian los datos.
