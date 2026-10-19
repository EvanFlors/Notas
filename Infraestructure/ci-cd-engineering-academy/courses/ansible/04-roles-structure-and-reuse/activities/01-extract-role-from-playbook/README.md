# Actividad 01 — Extraer un role `webserver` desde un playbook monolítico

## 1. Identificación

- **ID:** `ans-04-01-extract-role-from-playbook`
- **Tecnología:** `ansible`
- **Módulo:** `ans-04-roles-structure-and-reuse`
- **Dificultad:** intermediate
- **Duración estimada:** 70–80 min
- **Tipo:** guided-lab

## 2. Contexto

Heredas un `playbook.yml` de ~70 líneas que instala nginx, despliega un `nginx.conf` templatizado, levanta el servicio y notifica un handler para recargar. Está escrito como una pared de tasks con variables mezcladas, templates inline y cero reutilización. Tu misión es refactorizarlo a un **role `webserver`** siguiendo la estructura canónica, y correrlo contra `localhost` (sólo `--syntax-check` si no hay root; `--check` si quieres ir más allá).

Trabajas en `/tmp/ans-04-extract/`. El validador espera encontrar ahí la estructura final.

## 3. Objetivos

Al terminar deberías poder:

- Dado un playbook monolítico, extraer un role respetando la convención `defaults/`, `vars/`, `tasks/`, `handlers/`, `templates/`, `meta/`, `README.md`.
- Decidir qué variables van a `defaults/` y cuáles a `vars/`.
- Dividir `tasks/main.yml` en sub-tasks (`install.yml`, `configure.yml`, `service.yml`) con `import_tasks:`.
- Escribir un README que sirva de contrato: variables, defaults, OS soportados, ejemplo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§2 a §9) y recorrido `../../examples/02-role-nginx/`.
- Herramientas: `bash`, `python3` (para parsear YAML en el validador). `ansible-core` opcional — si no está instalado, el validador salta `--syntax-check` y reporta la razón.

**Costos**: ninguno. Todo local.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/ans-04-extract
cd /tmp/ans-04-extract
```

### 5.2 Punto de partida (opcional)

El playbook monolítico de referencia está en `starter/playbook.yml`. Léelo primero. **No lo copies tal cual** — el objetivo es refactorizarlo.

### 5.3 Crear la estructura del role

Opción A — con `ansible-galaxy`:

```bash
mkdir -p roles
cd roles
ansible-galaxy role init webserver
cd ..
```

Opción B — a mano (si no tienes ansible instalado):

```bash
mkdir -p roles/webserver/{defaults,vars,tasks,handlers,templates,meta}
```

El validador espera **al menos** estas carpetas presentes:

```
/tmp/ans-04-extract/
├── site.yml                           # Playbook top-level que llama al role
├── roles/
│   └── webserver/
│       ├── README.md                  # Contrato del role
│       ├── defaults/main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── install.yml
│       │   ├── configure.yml
│       │   └── service.yml
│       ├── handlers/main.yml
│       ├── templates/nginx.conf.j2
│       └── meta/main.yml
```

### 5.4 Requisitos por archivo

#### `site.yml` (top-level)

- Debe tener `hosts: localhost` (o `all` + inventario local).
- Debe tener `connection: local` o inventario con `ansible_connection=local`.
- Debe invocar `roles: [webserver]` (o `- role: webserver` con vars override).

#### `roles/webserver/defaults/main.yml`

- Al menos las variables: `webserver_port`, `webserver_server_name`, `webserver_worker_processes`.
- Valores por defecto razonables (`80`, `localhost`, `auto`).

#### `roles/webserver/tasks/main.yml`

- Usa `import_tasks:` para `install.yml`, `configure.yml`, `service.yml` (tres imports como mínimo).

#### `roles/webserver/tasks/install.yml`

- Usa el módulo `ansible.builtin.package` (o `apt`/`yum` si prefieres explicitar) para instalar nginx.

#### `roles/webserver/tasks/configure.yml`

- Usa `ansible.builtin.template` para desplegar `nginx.conf.j2`.
- `notify:` un handler.

#### `roles/webserver/tasks/service.yml`

- Usa `ansible.builtin.service` o `ansible.builtin.systemd` con `state: started`.

#### `roles/webserver/handlers/main.yml`

- Define al menos un handler cuyo `name:` coincida con el `notify:` de `configure.yml` (ej. `reload nginx` o `restart nginx`).

#### `roles/webserver/templates/nginx.conf.j2`

- Jinja2 que use al menos `{{ webserver_port }}` y `{{ webserver_server_name }}`.

#### `roles/webserver/meta/main.yml`

- `galaxy_info.author`, `galaxy_info.description`, `galaxy_info.license`.
- `galaxy_info.platforms:` lista con al menos una entrada.
- `dependencies:` presente (puede ser `[]`).

#### `roles/webserver/README.md`

- Secciones (headings) para: `Variables`, `OS`, `Ejemplo`.

### 5.5 Verificación local opcional (si tienes ansible)

```bash
ansible-playbook -i localhost, -c local site.yml --syntax-check
```

Debería imprimir `playbook: site.yml` sin errores. Para un dry-run real necesitarías permisos de root para instalar nginx; omítelo.

## 6. Resultado esperado

- Estructura del role existe y es completa.
- YAML parseable en todos los archivos.
- Validador en verde: `RESULT: 0 issue(s).`

## 7. Criterios de aceptación

- **Estructura**: todas las carpetas y archivos listados existen.
- **YAML**: todos los `.yml` parsean.
- **Separación de vars**: `defaults/main.yml` tiene las variables de usuario; `vars/main.yml` (opcional) tiene lo interno.
- **Documentación**: README cubre variables, OS y ejemplo.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-04-extract
```

Si `ansible-playbook` está instalado, el validador también corre `--syntax-check` contra `site.yml`. Si no, lo salta e informa.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `webserver_pkg: nginx` en `defaults/main.yml` en vez de `vars/main.yml`? ¿Es un bug?
2. ¿Por qué `import_tasks` en vez de `include_tasks` para `install/configure/service.yml`?
3. ¿Qué cambiaría si tuvieras que soportar también `apache` como webserver? ¿Un segundo role, o parametrizar éste?

## 10. Extensiones

- Añade `meta/argument_specs.yml` validando que `webserver_port` sea entero entre 1 y 65535.
- Añade tags por fase (`install`, `configure`, `service`) y verifica `--tags configure`.
- Añade `vars/main.yml` con `webserver_pkg`, `webserver_service`, `webserver_conf_path` y comenta por qué están ahí y no en `defaults/`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-04-extract
```
