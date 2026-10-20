# Lección — Playbooks, plays, tasks, módulos y handlers

## 1. De comandos ad-hoc a playbooks

En `ans-01` ejecutaste comandos **ad-hoc**: `ansible all -m ping`, `ansible web -m apt -a "name=nginx state=present"`. Son útiles para explorar o para acciones one-shot, pero no se versionan, no se componen y no documentan intención.

Un **playbook** es un archivo YAML que:

1. Describe **el estado deseado** de un conjunto de hosts.
2. Vive en el repositorio (código revisable).
3. Puede ejecutarse 1 o N veces: Ansible solo aplica lo necesario para converger (idempotencia).

```yaml
---
- name: Configurar servidor web
  hosts: web
  become: true
  tasks:
    - name: Instalar nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
```

Guárdalo como `playbook.yml` y ejecútalo con `ansible-playbook -i hosts.ini playbook.yml`.

## 2. Anatomía: playbook → plays → tasks → módulos

- **Playbook** (archivo): lista YAML en la raíz.
- Cada elemento de esa lista es una **play**: un bloque con `hosts:`, `vars:`, `tasks:`, `handlers:`.
- Cada **task** invoca exactamente **un módulo** con parámetros clave=valor.
- Un **módulo** es código Python que Ansible copia al host remoto, ejecuta y recoge su salida JSON.

```yaml
- name: Play 1
  hosts: web
  tasks:
    - name: Task 1
      ansible.builtin.apt: { name: nginx, state: present }

- name: Play 2
  hosts: db
  tasks:
    - name: Task 2
      ansible.builtin.service: { name: postgresql, state: started }
```

Reglas:

- Los **nombres** (`name:`) son opcionales técnicamente, obligatorios en la práctica (son tu log humano).
- Dentro de una play las tasks corren **en orden secuencial** sobre cada host en paralelo (por defecto 5 forks).
- Si una task falla en un host, Ansible saca a ese host del resto de la play (no de la siguiente).

## 3. Módulos idempotentes vs `shell:`/`command:`

**Idempotencia** = aplicar la acción N veces produce el mismo estado que aplicarla 1 vez. Es la propiedad que convierte a Ansible en algo operable, no en un script bash disfrazado.

Un módulo idempotente:

1. **Consulta el estado actual** del recurso.
2. Lo **compara** con el estado deseado.
3. Solo **actúa si hay diferencia**, y reporta `changed=true` solo en ese caso.

Módulos core idempotentes a conocer:

| Módulo | Qué gestiona |
|--------|--------------|
| `apt` / `yum` / `dnf` / `package` | Paquetes (según distro). |
| `file` | Permisos, propietario, enlaces simbólicos, directorios. |
| `copy` | Copia un archivo local al remoto. |
| `template` | Como `copy` pero renderiza Jinja2 primero. |
| `service` / `systemd` | Servicios SysV / systemd. |
| `user` / `group` | Cuentas y grupos locales. |
| `cron` | Entradas de crontab. |
| `lineinfile` / `blockinfile` | Edita líneas o bloques dentro de un archivo. |
| `uri` | Llamadas HTTP (puede comprobar estado y actuar). |
| `wait_for` | Espera a que un puerto, archivo o condición ocurra. |

**`shell:` y `command:` NO son idempotentes por defecto**. Son escape hatches para cuando no existe módulo. Hay que decirle a Ansible cómo evitar re-ejecutar:

```yaml
- name: Compilar solo si el binario no existe (idempotente)
  ansible.builtin.command: make install
  args:
    chdir: /opt/src/myapp
    creates: /usr/local/bin/myapp   # si existe, Ansible salta la task
```

Alternativas: `removes:` (opuesto), `changed_when: false` (lo marca como `ok`, nunca `changed`), `register:` + `changed_when:` para derivar `changed` del output.

## 4. Handlers: reaccionar al cambio, no al tiempo

Un **handler** es una task especial que:

- Vive en la sección `handlers:` de la play.
- **No se ejecuta** por posición en el flujo.
- Se dispara con `notify: <handler-name>` desde una task **que haya reportado `changed`**.
- Se ejecuta **al final del play**, **una sola vez** aunque se le notifique N veces.

```yaml
- name: Configurar nginx
  hosts: web
  become: true
  tasks:
    - name: Publicar nginx.conf
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: Reload nginx

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

Resultado:

- Primera ejecución: la plantilla cambia → `changed=true` → notifica → al final del play nginx se recarga.
- Segunda ejecución: la plantilla ya está igual → `changed=false` → **no se notifica** → nginx **no se recarga innecesariamente**.

Esto es exactamente la propiedad que separa "automatizar bien" de "reiniciar servicios en cada deploy porque sí".

Convención: nombra los handlers con verbo imperativo mayúscula ("Reload nginx", "Restart app"). El `notify:` debe coincidir **exacto** con el `name:` del handler.

## 5. Privilegios: `become`

Por defecto Ansible se conecta como el usuario SSH y no eleva privilegios. Para administrar paquetes/servicios necesitas `root`:

```yaml
- hosts: web
  become: true
  become_method: sudo        # default
  become_user: root          # default
  tasks: ...
```

Se puede acotar por task en vez de por play:

```yaml
- name: Instalar paquete global
  ansible.builtin.apt: { name: curl, state: present }
  become: true
```

En hosts gestionados que requieren password sudo, usa `--ask-become-pass` (`-K`) o `ansible_become_password` en vault.

## 6. Condicionales y loops

**`when:`** evalúa una expresión Jinja (sin `{{ }}`):

```yaml
- name: Instalar firewalld solo en RHEL-like
  ansible.builtin.dnf: { name: firewalld, state: present }
  when: ansible_facts['os_family'] == 'RedHat'
```

**`loop:`** itera una task sobre una lista:

```yaml
- name: Crear usuarios de aplicación
  ansible.builtin.user:
    name: "{{ item }}"
    state: present
  loop:
    - app
    - deploy
    - metrics
  loop_control:
    label: "{{ item }}"
```

Nunca uses `shell:` dentro de un `loop:` para "hacer bulk" cuando el módulo nativo lo soporta por lista; es más lento y pierde idempotencia por elemento.

## 7. Tags y modos seguros (`--check`, `--diff`)

**Tags** permiten etiquetar tasks (o plays enteras) y luego ejecutar solo un subconjunto:

```yaml
- name: Instalar nginx
  ansible.builtin.apt: { name: nginx, state: present }
  tags: [install]

- name: Publicar config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  tags: [config]
```

Luego:

```bash
ansible-playbook playbook.yml --tags config         # solo tareas con tag "config"
ansible-playbook playbook.yml --skip-tags install   # todo menos "install"
```

Tags útiles de serie: `always` (siempre se corre, incluso con `--tags X`) y `never` (nunca, excepto con `--tags <el-tag>`).

**Check mode (`--check`)**: dry-run. Ansible simula el cambio sin aplicarlo. **No todos los módulos lo soportan** — los nativos sí, muchos con `command:/shell:` no. Combínalo con **`--diff`** para ver el delta exacto que se aplicaría a los archivos:

```bash
ansible-playbook playbook.yml --check --diff
```

Esto es tu red de seguridad para operar en producción.

## 8. Fundamentos internos

Cuando ejecutas una task, Ansible internamente:

1. Serializa el módulo Python + los argumentos.
2. Lo copia al host remoto (SSH SFTP, por defecto a `~/.ansible/tmp/`).
3. Lo ejecuta allí con el intérprete Python detectado.
4. El módulo imprime un JSON con `changed`, `failed`, `msg`, campos específicos.
5. Ansible parsea ese JSON y decide el siguiente paso.

Consecuencias:

- **Sin Python en el target no funciona** (hay un `raw:` como escape para instalar Python primero).
- La **latencia SSH** domina en playbooks largos; `pipelining = true` en `ansible.cfg` reduce round-trips.
- Un módulo **no es un script bash** — es código real que puede testearse y mantenerse.

Los **handlers**, por su parte, se gestionan en memoria del controlador: Ansible registra qué handlers han sido notificados por cada host, los dedupe, y al final del play los ejecuta en el **orden en el que están definidos** (no en el orden de notificación).

## 9. Qué sigue

Con esto escribes playbooks correctos pero aún "estáticos": todos los valores están hardcoded. En `ans-03` sacas los valores a **variables**, aplicas plantillas **Jinja2** con disciplina y entiendes la (temida) **precedence** de variables.
