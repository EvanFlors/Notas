# Ejemplo 02 — Role `nginx` real

## Qué muestra

Un role con contenido en `defaults`, `vars`, `tasks`, `handlers`, `templates`, `meta` y README. Es el patrón que vas a replicar en las actividades.

## Estructura

```
roles/nginx/
├── README.md
├── defaults/main.yml           # Config sobreescribible por el usuario
├── vars/main.yml               # Config interna (rutas, paquete)
├── tasks/
│   ├── main.yml                # Entry point
│   ├── install.yml             # Instalar paquetes
│   ├── configure.yml           # Templates + perms
│   └── service.yml             # Start/enable + handler notify
├── handlers/main.yml           # restart nginx, reload nginx
├── templates/nginx.conf.j2     # Config principal parametrizada
└── meta/main.yml               # Author, platforms, galaxy_tags
```

## Snippets ilustrativos

### `defaults/main.yml` (sobreescribible)

```yaml
---
nginx_port: 80
nginx_server_name: localhost
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_user: www-data
```

### `vars/main.yml` (interno)

```yaml
---
nginx_pkg: nginx
nginx_service: nginx
nginx_conf_path: /etc/nginx/nginx.conf
```

### `tasks/main.yml`

```yaml
---
- name: Install
  ansible.builtin.import_tasks: install.yml
  tags: [nginx, install]

- name: Configure
  ansible.builtin.import_tasks: configure.yml
  tags: [nginx, configure]

- name: Service
  ansible.builtin.import_tasks: service.yml
  tags: [nginx, service]
```

### `tasks/install.yml`

```yaml
---
- name: Ensure nginx package is installed
  ansible.builtin.package:
    name: "{{ nginx_pkg }}"
    state: present
  become: true
```

### `tasks/configure.yml`

```yaml
---
- name: Deploy nginx.conf
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: "{{ nginx_conf_path }}"
    owner: root
    group: root
    mode: "0644"
  become: true
  notify: reload nginx
```

### `tasks/service.yml`

```yaml
---
- name: Ensure nginx is running and enabled
  ansible.builtin.service:
    name: "{{ nginx_service }}"
    state: started
    enabled: true
  become: true
```

### `handlers/main.yml`

```yaml
---
- name: reload nginx
  ansible.builtin.service:
    name: "{{ nginx_service }}"
    state: reloaded
  become: true

- name: restart nginx
  ansible.builtin.service:
    name: "{{ nginx_service }}"
    state: restarted
  become: true
```

### `templates/nginx.conf.j2`

```jinja
user {{ nginx_user }};
worker_processes {{ nginx_worker_processes }};

events {
  worker_connections {{ nginx_worker_connections }};
}

http {
  server {
    listen {{ nginx_port }};
    server_name {{ nginx_server_name }};

    location / {
      return 200 'ok';
      add_header Content-Type text/plain;
    }
  }
}
```

### `meta/main.yml`

```yaml
---
galaxy_info:
  author: platform-team
  description: Install and configure nginx
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions: [jammy, noble]
    - name: Debian
      versions: [bookworm]
    - name: EL
      versions: ["9"]
  galaxy_tags: [web, nginx]

dependencies: []
```

## Uso desde un playbook

```yaml
---
- hosts: web
  become: true
  roles:
    - role: nginx
      vars:
        nginx_port: 8080
        nginx_server_name: api.example.com
```

Observa cómo el consumidor **sólo toca variables de `defaults/`**. Nunca `nginx_pkg` ni `nginx_conf_path`.

## Lecciones clave

- Separación `defaults` (del usuario) vs `vars` (del role) es la base de la reutilización.
- `tasks/main.yml` corto que `import_tasks:` fases concretas facilita selección por tags.
- Handler `reload nginx` disparado por `template:` evita restarts innecesarios.
- `meta/main.yml` lista explícita de platforms es parte del contrato.
