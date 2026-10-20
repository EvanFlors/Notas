# ans-03 — Lección: variables, facts, templates, Jinja2

> 8 secciones. Prerrequisitos: `ans-01`, `ans-02`.

---

## 1. Por qué parametrizar es inevitable

Un playbook sin variables sirve una vez: cuando lo escribes para un host concreto, con un puerto concreto, con un `server_name` concreto. En cuanto quieres aplicarlo a *staging* y a *producción*, o a dos hosts del mismo grupo con diferente IP, aparecen dos malos reflejos:

1. **Copiar y pegar el playbook** para cada entorno. Resultado: tres copias que empiezan a divergir y nadie sabe cuál es la "buena".
2. **Hacer `sed`** antes de ejecutar. Resultado: el playbook no es idempotente, no es revisable, y falla silenciosamente cuando una variable no se sustituye.

La solución correcta es **separar datos de código**: el playbook describe *qué pasos ejecutar*, las variables describen *con qué valores*. Y los templates (Jinja2) describen *qué forma tiene el archivo de configuración renderizado*.

Lo difícil no es la sintaxis — es decidir **dónde** poner cada variable para que, seis meses después, otra persona pueda cambiarla sin romper tres cosas.

---

## 2. Fuentes de variables (las que usarás a diario)

Ansible admite ~22 niveles de precedence. La trampa es tratar de usarlos todos. En la práctica, un equipo disciplinado usa 4 o 5:

| Nivel | Dónde se declara | Para qué |
|-------|------------------|----------|
| `defaults/main.yml` de un role | dentro del role | **valor por defecto** que el consumidor del role puede sobreescribir. |
| `group_vars/<grupo>.yml` | en el inventory | **config por entorno/grupo** (p. ej. `webservers`, `prod`). |
| `host_vars/<host>.yml` | en el inventory | **override puntual** para un host específico. |
| `vars:` en la play | en el playbook | **constantes locales** a esa play. |
| `-e key=value` (extra vars) | línea de comandos | **override puntual en una ejecución**, p. ej. CI. |

Reglas prácticas:

- **`defaults/`** son los *más bajos* en precedence. Idóneo para "esto es lo que casi todo el mundo quiere".
- **`group_vars/`** y **`host_vars/`** son el 80% de los casos reales. Modela aquí tu inventario mental "qué es dev, qué es prod, qué host es diferente".
- **`vars:` en la play** sirven para valores que no tienen sentido fuera de esa play.
- **`extra vars` (`-e`)** son los *más altos* en precedence (salvo `role_params` y cosas poco usadas). Úsalos para forzar un valor en CI o en runs ad-hoc. **No** los uses como mecanismo normal de configuración — se vuelven invisibles.

> Regla mental corta: *"si lo mismo cambia en todos los hosts del grupo, va en `group_vars/`; si cambia en un host, va en `host_vars/`; si es una excepción puntual, va en `-e`"*.

---

## 3. Precedence: cómo ganar sin hacer trampa

La [tabla oficial de precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence) tiene 22 niveles. En orden de **menor a mayor** (los de abajo ganan):

1. `command line` values (p. ej. `-u user`)
2. `role defaults` (`defaults/main.yml`)
3. `inventory file or script` group vars
4. `inventory group_vars/all`
5. `playbook group_vars/all`
6. `inventory group_vars/*`
7. `playbook group_vars/*`
8. `inventory host_vars/*`
9. `playbook host_vars/*`
10. `host facts / cached set_facts`
11. `play vars`
12. `play vars_prompt`
13. `play vars_files`
14. `role vars` (`vars/main.yml`)
15. `block vars`
16. `task vars`
17. `include_vars`
18. `set_facts` / registered vars
19. `role (and include_role) params`
20. `include params`
21. `extra vars` (`-e`)

Lo que debes recordar:

- **`defaults/` siempre pierde** (bueno — son defaults).
- **`role vars/`** (en `vars/main.yml`) *gana* a `group_vars`/`host_vars`/`set_fact`. Por eso los usas para "esto es config interna del role, no quiero que nadie me la cambie desde fuera".
- **`extra vars` siempre gana**. Útil en CI; peligroso si se abusa.
- **`set_fact` sobreescribe** a casi todo salvo `role vars`, `include params`, y `extra vars`.

> Si una variable "no vale lo que debería", el 90% de las veces es porque alguien la redefinió en `vars/main.yml` del role o pasó `-e` en el CI. Mira ahí primero.

---

## 4. Facts: lo que Ansible descubre del host

Cuando una play arranca, Ansible ejecuta por defecto el módulo `setup` contra cada host — eso es *gather_facts*. Recolecta cientos de datos y los deja en `ansible_facts`:

```yaml
ansible_facts.distribution        # 'Ubuntu', 'Debian', 'RedHat'...
ansible_facts.distribution_major_version  # '22', '12', '9'...
ansible_facts.os_family           # 'Debian', 'RedHat'...
ansible_facts.default_ipv4.address
ansible_facts.processor_vcpus
ansible_facts.memtotal_mb
ansible_facts.mounts              # lista de filesystems montados
```

Dos aliases: Ansible expone los mismos datos como `ansible_<key>` (sin el `facts.`), p. ej. `ansible_distribution`. Es el estilo legacy, aún muy usado.

**Cuándo apagarlos:**

```yaml
- hosts: all
  gather_facts: false
```

- Si vas a correr una tarea trivial contra 500 hosts, `setup` suma varios segundos por host. En playbooks de ping/ping-like, apágalo.
- Si *vas a usar facts*, déjalos activos (es el default).

**Fact caching**: si corres el mismo inventory muchas veces, puedes cachear los facts en Redis o en JSON files (`ansible.cfg → fact_caching = jsonfile`). Las plays posteriores leen del cache en lugar de hacer `setup`.

**Diferencia conceptual**:

- Un **fact** lo descubre Ansible del host (`ansible_distribution`).
- Una **variable** la escribiste tú (`app_port: 8080`).

Un error típico: tratar `ansible_hostname` como "el nombre lógico del host en mi arquitectura". **No lo es** — es el hostname real del sistema operativo. Para "nombre lógico" usa `inventory_hostname` (la clave con la que lo nombraste en el inventory).

---

## 5. Jinja2 lo justo (y nada más)

Jinja2 es un *template engine*. En Ansible lo ves en dos sitios:

1. **Expresiones embebidas en strings YAML**: `name: "{{ app_name }}-webserver"`.
2. **Archivos de template** (`.j2`) renderizados por el módulo `ansible.builtin.template`.

Sintaxis mínima útil:

```jinja2
# Interpolación
{{ var }}

# Default si la var no existe
{{ port | default(8080) }}

# Default obligatorio (falla si no se define, útil en roles)
{{ port | mandatory }}

# Filtros encadenados
{{ app_name | lower | regex_replace(' ', '-') }}

# Condicionales
{% if env == 'prod' %}
worker_processes auto;
{% else %}
worker_processes 2;
{% endif %}

# Loops
{% for upstream in upstreams %}
    server {{ upstream.host }}:{{ upstream.port }};
{% endfor %}

# Comentarios (no aparecen en el output)
{# este comentario no se renderiza #}
```

**Whitespace control**: `{%- ... -%}` elimina espacios/newlines alrededor del tag. Útil para que el loop no deje líneas vacías en el output:

```jinja2
upstream backend {
{%- for u in upstreams %}
    server {{ u.host }}:{{ u.port }};
{%- endfor %}
}
```

**Filtros frecuentes**:

| Filtro | Qué hace |
|--------|----------|
| `default('x')` | valor por defecto si la var no está definida |
| `upper` / `lower` | mayúsculas/minúsculas |
| `trim` | elimina whitespace de los extremos |
| `regex_replace('a', 'b')` | sustitución regex |
| `to_json` / `to_nice_json` | serializar a JSON |
| `combine({...})` | fusionar diccionarios |
| `union([...])` / `difference([...])` | operaciones de set sobre listas |

**Regla de oro**: *la lógica va en los playbooks, no en los templates*. Si tu template tiene un `{% if %}` dentro de un `{% for %}` dentro de otro `{% if %}`, probablemente deberías calcular eso con `set_fact:` **antes** y meter el resultado ya cocinado en el template.

---

## 6. El módulo `template:` en la práctica

El workflow canónico es:

1. Escribes un archivo `templates/foo.conf.j2` con variables Jinja2.
2. En una task usas:

```yaml
- name: Render nginx.conf
  ansible.builtin.template:
    src: nginx.conf.j2            # ruta relativa a templates/ del play o del role
    dest: /etc/nginx/nginx.conf   # ruta en el host destino
    owner: root
    group: root
    mode: '0644'
    validate: 'nginx -t -c %s'    # opcional: valida antes de reemplazar
  notify: reload nginx
```

Puntos interesantes:

- **`validate:`** ejecuta el comando con el path temporal del archivo renderizado. Si falla, Ansible **no** reemplaza el archivo original. Para configuraciones críticas (nginx, sshd, sudoers) **úsalo siempre**.
- **`notify:`** encadena un handler (lo viste en `ans-02`). Solo se dispara si el template realmente cambió.
- **`--diff`** en la línea de comandos muestra el diff del archivo renderizado. Combínalo con `--check` para hacer *dry run*.

**Lookups**: en tiempo de render puedes consultar datos externos:

```jinja2
{{ lookup('file', '/etc/machine-id') }}
{{ lookup('env', 'HOME') }}
{{ lookup('vars', 'app_' + env + '_port') }}
```

Los lookups se ejecutan **en el control node** (donde corre Ansible), no en el target. Si lees un archivo con `lookup('file', ...)` estás leyendo el archivo de tu laptop/runner, no del host remoto.

---

## 7. `register:` y `set_fact:` — capturar y propagar

A veces necesitas usar el resultado de una task en tasks siguientes. Dos mecanismos:

### `register:`

Captura el objeto de resultado de una task:

```yaml
- name: Check if config exists
  ansible.builtin.stat:
    path: /etc/myapp.conf
  register: cfg_stat

- name: Backup if present
  ansible.builtin.copy:
    src: /etc/myapp.conf
    dest: /etc/myapp.conf.bak
    remote_src: true
  when: cfg_stat.stat.exists
```

El `register` vive durante toda la play. Es **por host** (cada host tiene el suyo). Contiene campos típicos: `rc`, `stdout`, `stderr`, `changed`, `failed`, y los campos específicos del módulo (`stat.exists`, `stat.size`...).

### `set_fact:`

Define una variable *desde dentro* del playbook, calculada en tiempo de ejecución:

```yaml
- name: Build upstream list
  ansible.builtin.set_fact:
    upstreams: "{{ groups['appservers'] | map('extract', hostvars, 'ansible_default_ipv4') | map(attribute='address') | list }}"

- name: Render load balancer config
  ansible.builtin.template:
    src: lb.conf.j2
    dest: /etc/haproxy/haproxy.cfg
```

`set_fact` sobreescribe las vars del inventory (ver precedence). Útil cuando necesitas computar algo complejo y luego usarlo "como si fuera" una variable normal.

> No abuses de `set_fact`. Si pones 20 por play, la lógica se vuelve inmanejable. Prefiere `group_vars` cuando sea posible.

---

## 8. Antipatterns y hábitos sanos

**Antipatterns frecuentes:**

1. **Lógica en templates**: cálculos complejos dentro de `{{ }}` que deberían ser `set_fact`. El template se vuelve ilegible y los errores aparecen en tiempo de render, no de task.
2. **Hardcodear valores en `vars:` de la play** cuando deberían estar en `group_vars/`. El valor se vuelve invisible para quien hereda el playbook.
3. **Usar `vars/main.yml` del role en lugar de `defaults/main.yml`** para config esperada del usuario. `vars/` tiene precedence muy alta — el consumidor del role **no podrá sobreescribirlo** desde `group_vars`.
4. **Depender de un fact que puede no existir** (`ansible_facts.foo.bar`) sin `default()`. Si el fact no está, la play revienta.
5. **No usar `validate:`** en templates críticos. Un `sshd_config` roto deja al host inaccesible.

**Hábitos sanos:**

- Reserva `vars/main.yml` del role solo para constantes internas (versiones de paquetes, URLs internas).
- Nombra variables con prefijo del role o del contexto: `nginx_worker_processes`, no `worker_processes` — evita colisiones.
- Documenta en `defaults/main.yml` cada variable con un comentario sobre su propósito.
- Para templates de más de ~40 líneas, divide con `{% include 'parcial.j2' %}`.
- Añade `# {{ ansible_managed }}` en la cabecera de los archivos renderizados para que humanos vean "esto lo hace Ansible, no lo edites a mano".

Un ejemplo de buena cabecera en `nginx.conf.j2`:

```jinja2
# {{ ansible_managed }}
# Generado por el role nginx desde {{ playbook_dir }}
# No editar manualmente — los cambios se perderán en el siguiente ansible-playbook.

worker_processes {{ nginx_worker_processes | default('auto') }};
```

Y el consumidor del archivo renderizado sabe exactamente qué está mirando.

---

## Cierre

Con lo de aquí ya puedes convertir cualquier playbook "hardcodeado para dev" en uno multi-entorno. En `ans-04` lo empaquetarás todo (variables, templates, tasks, handlers) en un **role** reutilizable, y en `ans-05` lo distribuirás como collection.
