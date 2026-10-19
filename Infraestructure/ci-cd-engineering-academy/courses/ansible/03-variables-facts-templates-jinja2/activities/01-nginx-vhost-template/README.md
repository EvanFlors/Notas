# Actividad 01 — Plantilla Jinja2 para un vhost de nginx

## 1. Identificación

- **ID:** `ans-03-01-nginx-vhost-template`
- **Tecnología:** `ansible`
- **Módulo:** `ans-03-variables-facts-templates-jinja2`
- **Dificultad:** beginner
- **Duración estimada:** 50–60 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo quiere dejar de mantener tres copias casi idénticas del vhost de nginx (una por entorno). Vas a reemplazarlas por **una** plantilla Jinja2 (`vhost.conf.j2`) y un playbook corto que la renderice con las variables adecuadas. Todo el ejercicio corre en **localhost** y escribe en `/tmp/ans-03-vhost/` — no toca `/etc/nginx` ni requiere root.

## 3. Objetivos

Al terminar deberías poder:

- Escribir una plantilla Jinja2 válida que itere una lista de upstreams.
- Usar el módulo `ansible.builtin.template` con `src`/`dest`/`mode`.
- Pasar variables desde `vars:` del playbook y por `-e` (extra vars) y entender cuál gana.
- Verificar el output renderizado con un script de bash + grep.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§5 y §6).
- `ansible-core` instalado (`pipx install ansible` o `pip install ansible-core`).
- Herramientas: `bash`, `grep`, `ansible-playbook`.

> **Si no tienes Ansible instalado**, el validador reporta `SKIP` y sale con código `0`; pero no podrás completar el ejercicio realmente. Instala Ansible antes de empezar.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-03-vhost/templates
cd /tmp/ans-03-vhost
```

Puedes usar otro directorio; entonces pasa la ruta al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Archivos a crear

Dentro de `/tmp/ans-03-vhost/` necesitas:

```
/tmp/ans-03-vhost/
├── inventory.ini
├── playbook.yml
└── templates/
    └── vhost.conf.j2
```

Nombres **exactos** (el validador los busca).

#### `inventory.ini`

Un host local con `ansible_connection=local`:

```ini
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/env python3
```

#### `playbook.yml`

Debe tener (al menos) una play con `hosts: local`, `gather_facts: false`, un bloque `vars:` que defina:

- `vhost_server_name` (string, p. ej. `app.example.local`),
- `vhost_listen_port` (int, p. ej. `8080`),
- `vhost_upstreams` (lista de dicts con claves `host` y `port`, al menos 2 elementos).

Y una task `ansible.builtin.template` que renderice `templates/vhost.conf.j2` a `/tmp/ans-03-vhost/output/vhost.conf` con `mode: '0644'`. Añade antes un `ansible.builtin.file` para crear el directorio `/tmp/ans-03-vhost/output`.

#### `templates/vhost.conf.j2`

La plantilla debe contener:

- Una cabecera con `# {{ ansible_managed }}` para marcar "esto lo generó Ansible".
- Un bloque `server { ... }` con:
  - `listen {{ vhost_listen_port }};`
  - `server_name {{ vhost_server_name }};`
- Un bloque `upstream backend { ... }` **antes** del `server` que itere `vhost_upstreams` con `{% for %}` y genere una línea `server <host>:<port>;` por elemento. Usa whitespace control (`{%- %}`) para que no queden líneas vacías.
- Dentro del `server`, un `location /` con `proxy_pass http://backend;`.

### 5.3 Ejecutar

```bash
cd /tmp/ans-03-vhost
ansible-playbook -i inventory.ini playbook.yml
cat output/vhost.conf
```

El validador vuelve a correr el playbook y comprueba el output renderizado.

### 5.4 Entregables

```
/tmp/ans-03-vhost/
├── inventory.ini
├── playbook.yml
├── templates/vhost.conf.j2
└── output/vhost.conf   (lo genera el playbook)
```

## 6. Resultado esperado

Al correr el validador:

- Si `ansible-playbook` no está instalado → `SKIP` (exit 0) con un mensaje claro.
- Si está instalado:
  - El playbook corre sin errores.
  - `output/vhost.conf` contiene `server_name`, el `listen` con tu puerto, y al menos 2 líneas `server <ip>:<port>;` dentro del `upstream backend`.
  - Validador imprime `OK` y sale con código 0.

## 7. Criterios de aceptación

- **Funcionalidad**: el validador pasa.
- **Correctitud estructural**: la plantilla usa `{% for %}` para iterar upstreams (no los lista hardcodeados).
- **Legibilidad**: cabecera `{{ ansible_managed }}` presente; indentación consistente.
- **Reutilización**: si cambias `vhost_server_name` por `-e vhost_server_name=otro.local` y vuelves a correr, el output refleja el nuevo valor.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-03-vhost
```

El validador ejecuta `ansible-playbook` y comprueba el output. No valida que el `nginx` real "acepte" la config (eso requeriría instalar nginx) — solo valida que el render es correcto.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `vhost_upstreams: []` (lista vacía)? ¿Nginx aceptaría el `upstream backend { }` vacío?
2. ¿Dónde pondrías `vhost_server_name` si tuvieras 3 entornos (dev/stg/prod) con dominios diferentes? ¿`vars:`, `group_vars/`, extra vars?
3. ¿Qué diferencia hay entre `{% for u in vhost_upstreams %}` y `{%- for u in vhost_upstreams -%}`? Prueba las dos variantes y mira el output renderizado.
4. ¿Cómo te asegurarías de que el `vhost.conf` renderizado es *válido* para nginx antes de reemplazar el existente?

## 10. Extensiones

- Añade una variable `vhost_tls_enabled: true|false` y, si es `true`, renderiza también `listen 443 ssl;` + rutas de certificado.
- Añade un `{% if %}` que incluya `access_log /var/log/nginx/{{ vhost_server_name }}.access.log;` solo si `vhost_access_log_enabled` es `true`.
- Divide la plantilla en dos: `vhost.conf.j2` que haga `{% include 'upstream.j2' %}`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-03-vhost
```
