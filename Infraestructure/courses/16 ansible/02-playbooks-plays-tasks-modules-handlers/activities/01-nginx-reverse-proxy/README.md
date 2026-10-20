# Actividad 01 — Nginx reverse proxy con handler

## 1. Identificación

- **ID:** `ans-02-01-nginx-reverse-proxy`
- **Tecnología:** `ansible`
- **Módulo:** `ans-02-playbooks-plays-tasks-modules-handlers`
- **Dificultad:** beginner
- **Duración estimada:** 70–90 min
- **Tipo:** guided-lab

## 2. Contexto

Operaciones necesita que **cualquier VM Debian/Ubuntu** pueda convertirse en un reverse proxy nginx hacia la aplicación interna que escucha en `127.0.0.1:8080`. El playbook debe:

- Instalar nginx.
- Publicar un vhost renderizado por plantilla con `server_name` y `upstream_host:upstream_port` parametrizables.
- Deshabilitar el `default` que trae nginx (symlink en `sites-enabled/default`).
- Reiniciar nginx **solo** cuando algo cambia (vía handler).

El entregable es un **playbook idempotente**. Si el estudiante lo corre dos veces, la segunda vuelta debe reportar `changed=0`.

## 3. Objetivos

Al terminar deberías poder:

- Explicar por qué un `shell: nginx -s reload` es peor que un handler.
- Escribir una plantilla Jinja2 mínima parametrizada.
- Diagnosticar por qué una task se marca `changed` en cada ejecución.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (todas las secciones).
- Haber corrido `../../examples/01-install-nginx-with-handler/`.
- Herramientas: `bash`, `ansible-core` (opcional para test dinámico; el validador salta si no está).

**Costos**: ninguno. Se corre en localhost o en un contenedor Ubuntu.

## 5. Instrucciones

### 5.1 Copia el starter

```bash
cp -r starter/ /tmp/ans-02-01/
cd /tmp/ans-02-01/
```

Encontrarás un skeleton:

```
playbook.yml           # con tareas marcadas # TODO
inventory.ini          # localhost por default
templates/nginx-proxy.conf.j2.sample   # ejemplo que debes convertir en .j2
group_vars/web.yml     # variables (upstream_host, upstream_port, server_name)
```

### 5.2 Escribe el playbook

Debes producir, dentro de `playbook.yml`, una play que:

1. Instale `nginx` con `ansible.builtin.apt` (`state: present`, `update_cache: true`).
2. Publique la plantilla `templates/nginx-proxy.conf.j2` como `/etc/nginx/sites-available/reverse-proxy.conf`.
3. Habilite el sitio como symlink en `/etc/nginx/sites-enabled/reverse-proxy.conf`.
4. Deshabilite el `default` (`state: absent` sobre `/etc/nginx/sites-enabled/default`).
5. Asegure que el servicio nginx está arrancado y habilitado.
6. Defina un handler **`Reload nginx`** (`service: name=nginx state=reloaded`) y notifíquelo desde las tasks de plantilla / symlink / default.

Reglas:

- `become: true`.
- Nada de `shell:` ni `command:`.
- Todos los paths y nombres deben venir de variables en `group_vars/web.yml`.

### 5.3 Ejecuta

```bash
ansible-playbook -i inventory.ini playbook.yml --check --diff   # dry-run
ansible-playbook -i inventory.ini playbook.yml                  # aplica
ansible-playbook -i inventory.ini playbook.yml                  # 2a vuelta
```

La segunda vuelta debe salir con `changed=0`. Si ves `changed=1` o `2`, alguna task no es idempotente (típicamente un `shell:` o un `file:` que modifica mtime).

### 5.4 Valida

```bash
bash tests/validate.sh
```

El validador comprueba la **estructura** del playbook y archivos. Si tienes `ansible-playbook` instalado, además hace `--syntax-check` sobre el playbook del starter copiado (o del propio directorio) y lo marca OK/SKIP.

## 6. Entregables

- `playbook.yml` con la play completa y handler.
- `templates/nginx-proxy.conf.j2` con `server_name`, `upstream_host`, `upstream_port` parametrizados.
- `group_vars/web.yml` con los valores de ejemplo.
- `bash tests/validate.sh` → `0 issue(s)`.

## 7. Autoevaluación

Compara tu `playbook.yml` con `solution/playbook.yml`. Diferencias **aceptables**:

- Orden de tasks (siempre que la instalación vaya primero).
- Nombres de tasks (siempre descriptivos).
- Uso de `ansible.builtin.package` en lugar de `apt` (más portable, no es requisito).

Diferencias **inaceptables**:

- Uso de `shell:` o `command:` para operaciones que tienen módulo nativo.
- Reiniciar nginx como task (no como handler).
- Hardcodear `server_name` o puertos en el template sin variables.

## 8. Pistas de debug

- La task del symlink reporta `changed` cada vez → asegura `state: link` con `src` y `dest` correctos; `file: state: touch` **sí** cambia siempre.
- El handler no se dispara → confirma que el `name:` del handler y el string del `notify:` coinciden **exactamente** (case-sensitive).
- `--check` falla en la task de plantilla → la primera vez el directorio padre no existe; agrega una task `file: state: directory` antes.
