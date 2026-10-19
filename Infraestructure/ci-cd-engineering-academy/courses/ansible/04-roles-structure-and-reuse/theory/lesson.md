# ans-04 — Teoría: Roles, estructura y reutilización

## 1. Por qué roles y no un playbook enorme

Un playbook crece bien hasta ~200 líneas. A partir de ahí, la mezcla de tasks, handlers, variables y templates vuelve el archivo frágil: cualquier cambio toca algo adyacente, los diffs se vuelven ruidosos y la reutilización entre equipos es imposible porque la lógica está entrelazada con el inventario y las decisiones del entorno.

Un **role** resuelve esto imponiendo una estructura canónica. Es una convención, no una característica mágica: Ansible asume que si existe `roles/<name>/tasks/main.yml`, al llamar `- role: <name>` ejecuta esos tasks, carga `defaults/main.yml`, prepara `handlers/main.yml` para `notify:`, y pone `templates/` y `files/` disponibles para `template:` y `copy:`. Ese contrato es lo que permite compartir roles entre repos y entre organizaciones.

El objetivo real es **separar lógica de configuración**. El role encapsula "cómo instalar y configurar X correctamente"; el consumidor pasa variables desde su inventario o playbook sin tocar el role.

## 2. Estructura canónica

Ejecuta `ansible-galaxy role init my_role` y obtienes:

```
my_role/
├── defaults/
│   └── main.yml          # Variables por defecto (precedence más baja)
├── vars/
│   └── main.yml          # Variables internas del role (precedence alta)
├── tasks/
│   └── main.yml          # Entry point de tasks
├── handlers/
│   └── main.yml          # Handlers reactivos (notify)
├── templates/            # Archivos Jinja2 para el modulo template:
├── files/                # Archivos estaticos para el modulo copy:
├── meta/
│   └── main.yml          # Metadatos: author, license, dependencies, galaxy_tags
├── tests/
│   ├── inventory
│   └── test.yml          # Playbook minimo para probar el role
└── README.md             # Contrato: que hace, variables, OS soportados, ejemplos
```

Cada carpeta tiene un rol muy específico:

- **`defaults/main.yml`** — variables que el consumidor **va a sobreescribir**. Son el nivel más bajo de precedence (nivel 2 de 22 en la docs oficial). Usa esto para "el puerto de nginx, por defecto 80".
- **`vars/main.yml`** — variables internas del role, que el consumidor **no debería tocar**. Precedence alta (nivel 15). Usa esto para "el path del binario, que depende del OS".
- **`tasks/main.yml`** — entry point. Puedes dividir en archivos adicionales (`install.yml`, `configure.yml`) e invocarlos con `import_tasks:` o `include_tasks:`.
- **`handlers/main.yml`** — handlers con `name:` que los tasks referencian con `notify:`. Se ejecutan al final del play, una sola vez por handler, sólo si algo los notificó.
- **`templates/`** — Jinja2 (`.j2`) para `template:`. El contexto incluye todas las variables del play, facts y vars del role.
- **`files/`** — estáticos para `copy:`, sin interpolación.
- **`meta/main.yml`** — autor, licencia, OS soportados, `galaxy_tags` y, crucialmente, `dependencies:` (otros roles que se ejecutan **antes** de este).
- **`README.md`** — el contrato público. Si falta o está incompleto, el role es inusable fuera de tu cabeza.

## 3. `defaults` vs `vars`: la decisión más importante

La regla operativa:

- **Si el usuario del role puede querer cambiarlo → `defaults/main.yml`.**
- **Si tocarlo rompe el role → `vars/main.yml`.**

Ejemplo con `nginx`:

```yaml
# defaults/main.yml  (sobreescribible)
nginx_port: 80
nginx_worker_processes: auto
nginx_server_name: localhost

# vars/main.yml  (interno)
nginx_conf_path: /etc/nginx/nginx.conf
nginx_pkg_name: nginx
nginx_service_name: nginx
```

Si pones `nginx_conf_path` en `defaults`, un usuario descuidado podría sobreescribirlo desde `group_vars` y romper el role sin darse cuenta. En `vars` tendría que forzarlo explícitamente desde el play (precedence 18), lo cual deja rastro en el código.

## 4. `tasks/main.yml`: entrypoint y descomposición

Mantén `main.yml` corto y declarativo. Divide en sub-archivos por fase:

```yaml
# tasks/main.yml
- name: Install packages
  import_tasks: install.yml
  tags: [install]

- name: Configure service
  import_tasks: configure.yml
  tags: [configure]

- name: Ensure service running
  import_tasks: service.yml
  tags: [service]
```

- **`import_tasks:`** se expande en **tiempo de parse** (eager). Los tags aplican a cada task importado individualmente; los errores de sintaxis se detectan antes de empezar el play.
- **`include_tasks:`** se evalúa en **tiempo de ejecución** (lazy). Permite loops y `when:` dinámicos pero no puedes seleccionar los tags internos desde fuera.

Regla: **usa `import_tasks` por defecto**; cambia a `include_tasks` sólo cuando necesites un `loop:` o un `when:` cuya expresión depende de facts recolectados durante el play.

## 5. Handlers y templates

Handlers:

```yaml
# handlers/main.yml
- name: restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

Y desde un task:

```yaml
- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```

El handler se dispara **una sola vez** al final del play, incluso si varios tasks lo notifican. Esto es lo que permite "reiniciar sólo si cambió algo" sin lógica adicional.

Templates viven en `templates/`. En `template:` usas `src: nginx.conf.j2` sin ruta — Ansible resuelve relativa a `templates/` del role.

## 6. `meta/main.yml` y dependencies

```yaml
# meta/main.yml
galaxy_info:
  author: platform-team
  description: Install and configure nginx
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions: [jammy, noble]
    - name: EL
      versions: ["9"]
  galaxy_tags: [web, nginx]

dependencies:
  - role: common
    vars:
      common_timezone: UTC
```

**Dependencies**:

- Se ejecutan **antes** que el role que las declara, en orden.
- Se ejecutan **una sola vez por play** aunque varios roles las declaren (dedup por nombre + vars).
- Son **acoplamiento oculto**: alguien que lee `playbook.yml` no ve que `webserver` arrastra `common`. Por eso muchas orgs las evitan y prefieren **composición explícita**:

```yaml
# site.yml (preferido en muchos equipos)
- hosts: web
  roles:
    - common
    - webserver
    - fastapi-app
```

Usa `dependencies:` sólo cuando la dependencia es **técnica y obligatoria** (p. ej. `fastapi-app` requiere `webserver` para servir vía proxy). Para "setup general del host", compón en el playbook.

## 7. `import_role` vs `include_role`

Dentro de otro playbook o role:

- **`import_role`** — eager, en tiempo de parse. Comportamiento equivalente a `roles:`. Los tags se propagan.
- **`include_role`** — lazy, en tiempo de ejecución. Puedes usar `loop:` y `when:` que dependen de valores dinámicos. Los tags **no** se propagan hacia dentro.

```yaml
# Eager: lo normal
- import_role:
    name: webserver

# Lazy: necesario cuando el nombre viene de un fact
- include_role:
    name: "{{ chosen_role }}"
  loop: "{{ roles_to_apply }}"
  loop_control:
    loop_var: chosen_role
```

Si tu validador salta roles por `--tags`, recuerda: tags declarados dentro de un `include_role` no se filtran desde la línea de comandos. Prefiere `import_role` + tags externos.

## 8. Role por responsabilidad vs role monolítico

Anti-pattern clásico: `role setup-everything` que instala paquetes, configura red, despliega app, crea usuarios y mete cron jobs. Síntomas:

- README imposible de escribir sin convertirse en un manual.
- Variables colisionan (p. ej. `port` para nginx y para la app).
- No reutilizable: nadie necesita "todo-eso" otra vez.
- Testear requiere levantar el escenario completo.

Regla práctica: un role hace **una cosa coherente** que un operador reconocería como una unidad. `nginx`, `postgresql`, `fastapi-app`, `common-hardening`. Si un role necesita más de 10 variables para configurarse, probablemente son dos roles.

## 9. Documentación como contrato

El `README.md` del role es su API pública. Debe tener, como mínimo:

1. **Qué hace** (1 párrafo).
2. **OS soportados** (lista explícita; Ubuntu 22.04, Debian 12, RHEL 9, etc.).
3. **Variables requeridas** y **variables opcionales con defaults**.
4. **Ejemplo de uso** (snippet de 10 líneas).
5. **Handlers que expone** (si otros roles pueden `notify:`).
6. **Dependencies** (si las declara en `meta/main.yml`).
7. **Changelog** (SemVer: 1.0.0, 1.1.0, 2.0.0 cuando rompes compatibilidad).

Sin esto, el role es tuyo y de nadie más.

## 10. Dónde viven los roles

Ansible busca roles en, por orden:

1. `roles/` relativo al playbook.
2. Rutas en `roles_path` del `ansible.cfg`.
3. `~/.ansible/roles/`.
4. `/usr/share/ansible/roles/` y `/etc/ansible/roles/`.

Para proyectos, lo normal es `roles/` en el repo. Para roles compartidos entre repos, publícalos a **Galaxy** (público) o a un **Git repo privado** referenciado desde `requirements.yml`:

```yaml
# requirements.yml
- src: https://github.com/myorg/ansible-role-nginx.git
  version: v1.2.0
  name: nginx
```

Y `ansible-galaxy install -r requirements.yml -p roles/`.

## 11. Precedence recordatorio

En orden ascendente (los superiores ganan):

1. `role defaults` ← lo que vive en `defaults/main.yml`.
2. `inventory vars` (grupo/host).
3. `group_vars/all`, `group_vars/<group>`, `host_vars/<host>`.
4. `play vars`.
5. `role vars` ← `vars/main.yml` del role.
6. `set_fact` / `register`.
7. `extra_vars` (`-e`) ← siempre gana.

Por eso **`defaults` es sobreescribible** y **`vars` es intrusivo**. Esta es la raíz de la regla de la §3.

## 12. Qué viene después

- **Collections (`ans-05`)** — empaquetar varios roles + modules + plugins con namespace y lockfile.
- **Testing (`ans-08`)** — Molecule levanta contenedores, aplica el role, verifica idempotencia; sin esto, el role rompe silenciosamente en la próxima distro.
- **CI del role** — matriz de distros, publicación on-tag.

Un role sin README + sin tests es deuda. Un role con README + tests es un activo que sobrevive a su autor.
