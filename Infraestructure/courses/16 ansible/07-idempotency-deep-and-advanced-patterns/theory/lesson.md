# ans-07 — Lección: idempotencia profunda y patrones avanzados

> 10 secciones. Prerrequisitos: `ans-02` (playbooks, handlers, módulos), `ans-04` (roles).

---

## 1. ¿Qué significa realmente que un playbook sea idempotente?

Un playbook es **idempotente** si al correrlo **N veces** el estado final del sistema es el mismo y, a partir de la segunda corrida, Ansible reporta `changed=0`.

No es un adorno estético: es la propiedad que te permite:

- **Converger** un sistema derivado desde cualquier estado inicial.
- **Operar producción** sin miedo a "ejecutarlo dos veces por error".
- **Detectar drift**: si la segunda corrida reporta cambios inesperados, alguien tocó algo a mano.
- **Hacer check mode confiable**: `--check` tiene sentido solo si los módulos saben leer estado antes de actuar.

El error de arranque más común: tratar Ansible como "scripts bash con YAML por encima". Ese código sí converge una vez — pero cada corrida siguiente dice "changed, changed, changed" aunque nada haya cambiado, y nadie sabe si eso es drift real o ruido.

> **Idea clave:** la idempotencia no la da el lenguaje (YAML) sino el **módulo**. Un módulo idempotente lee estado, compara con el deseado y actúa **solo si** difieren. Los módulos "crudos" (`command`, `shell`, `raw`) **no leen estado** — tú tienes que fingir idempotencia a mano.

---

## 2. Cómo decide un módulo que algo está `changed`

Cada módulo oficial tiene su propia lógica:

- **`file:`** compara `path`, `state`, `mode`, `owner`, `group`. Si todo coincide, `changed=false`.
- **`copy:`** compara el checksum del origen con el destino. Si son iguales, no copia.
- **`template:`** renderiza Jinja2 en memoria, hashea el resultado, compara con el destino.
- **`apt:` / `dnf:` / `yum:`** consulta la DB del package manager; instala solo si el paquete no está en la versión deseada.
- **`user:` / `group:`** lee `/etc/passwd` o `/etc/group`.
- **`service:` / `systemd:`** consulta el estado del init system (started/stopped/enabled).
- **`lineinfile:` / `blockinfile:`** parsean el archivo, buscan el patrón, modifican solo si falta.
- **`uri:`** siempre reporta `changed=true` salvo que uses `status_code` + `changed_when:` explícito (es una llamada HTTP; Ansible no sabe si "cambió" algo del lado del servidor).

**Comando / shell / raw** son el caso explícito: **siempre** reportan `changed=true` salvo que les enseñes a decidir. No miran al sistema antes; ejecutan y punto.

```yaml
# Antipatrón: siempre reporta changed, siempre reinstala, siempre ruidoso.
- name: Install something
  shell: curl -sfL https://foo | bash

# Patrón correcto: solo corre si el binario no existe.
- name: Install something
  shell: curl -sfL https://foo | bash
  args:
    creates: /usr/local/bin/something
```

---

## 3. Herramientas para forzar idempotencia en `command`/`shell`

Cuatro palancas. En orden de preferencia:

### 3.1 `creates:` y `removes:`

- `creates: /path`: la task **no se ejecuta** si la ruta existe. Semántica: "crea /path".
- `removes: /path`: la task **no se ejecuta** si la ruta **no** existe. Semántica: "elimina /path".

Son el camino limpio: idempotencia real a nivel de ejecución (no "corre pero no reporta cambio" — directamente **no corre**).

```yaml
- name: Fetch and extract tarball
  shell: curl -sfL https://example.com/x.tgz | tar xz -C /opt
  args:
    creates: /opt/x/bin/x
```

### 3.2 `changed_when:` (expresión Jinja2)

Si la task **tiene** que correr siempre (porque es una query, un `echo`, un check), pero quieres **mentir** sobre el changed, usa `changed_when:`:

```yaml
- name: Query current nginx version
  command: nginx -v
  register: nginx_v
  changed_when: false            # nunca marca changed
  failed_when: nginx_v.rc != 0   # pero sigue fallando si rc != 0

- name: Only mark changed if output contains "created"
  command: /opt/bin/sync-config
  register: sync
  changed_when: '"created" in sync.stdout'
```

> `changed_when: false` es el patrón más usado: "esta task es un read-only, nunca cambia nada; no la contabilices como `changed`".

### 3.3 `failed_when:` (expresión Jinja2)

Por defecto una task falla si el `rc != 0`. A veces un `rc != 0` **es** el resultado esperado (un `grep` que no encuentra nada, un `curl` que recibe 404 que esperabas, un check que vuelve 1 cuando el servicio no existe aún). Usa `failed_when:` para redefinir el criterio:

```yaml
- name: Check if user exists
  command: id appuser
  register: id_result
  failed_when: false              # nunca falla, solo registra
  changed_when: false

- name: Create user if missing
  user:
    name: appuser
    state: present
  when: id_result.rc != 0
```

### 3.4 `register:` + lógica

Combinar `register`, `changed_when` y `failed_when` te deja construir módulos pseudo-idempotentes a partir de nada. Es la vía de escape para herramientas que no tienen módulo nativo. **Regla**: si vas a hacerlo dos veces en el repo, considera escribir un módulo propio en Python.

---

## 4. Check mode (`--check`) y diff mode (`--diff`)

**Check mode** (`ansible-playbook site.yml --check`) corre el playbook en **dry-run**: Ansible aplica cada módulo en modo "simulación" y reporta qué **habría** cambiado. Es la red de seguridad fundamental para operar producción.

Reglas que doleran si no las sabes:

- **No todos los módulos soportan check mode.** Los módulos oficiales canónicos (`file`, `copy`, `template`, `apt`, `user`, `service`, `systemd`, `lineinfile`...) sí. `command`, `shell`, `raw`, `uri` **no** por defecto — Ansible los **salta** en check mode y reporta `skipped`.
- **`check_mode: false`** fuerza que una task **sí** se ejecute aunque el playbook corra con `--check`. Útil para queries de lectura que no mutan nada:

  ```yaml
  - name: Query current version (always run, even in check mode)
    command: /opt/bin/version
    register: v
    changed_when: false
    check_mode: false
  ```

- **`check_mode: true`** fuerza que una task **nunca** aplique cambios, aunque el playbook no se haya invocado con `--check`. Útil para tasks que todavía no están listas para producción.

**Diff mode** (`--diff`) muestra el **diff** real de cada módulo que lo soporta (`template`, `copy`, `lineinfile`, `blockinfile`, `file` para permisos). Combinado con check mode (`--check --diff`), obtienes un plan de cambios estilo Terraform.

> **Práctica recomendada:** cualquier merge en main que vaya a producción debería tener un paso de CI que corra `ansible-playbook site.yml --check --diff --limit prod` contra inventario mock. Si falla o reporta cambios inesperados, el PR no entra.

---

## 5. `block:` + `rescue:` + `always:` — try/except/finally

Un **block** agrupa tasks que comparten `when`, `tags`, `become`, etc., **y** permite capturar fallos.

```yaml
- name: Deploy with safety net
  block:
    - name: Put app in maintenance mode
      file: { path: /var/www/.maintenance, state: touch }

    - name: Run risky migration
      command: /opt/app/bin/migrate --prod

    - name: Restart app
      systemd: { name: app, state: restarted }

  rescue:
    - name: Rollback on failure
      command: /opt/app/bin/migrate --rollback

    - name: Fail loudly
      fail:
        msg: "Deploy failed and rollback was executed"

  always:
    - name: Remove maintenance flag no matter what
      file: { path: /var/www/.maintenance, state: absent }
```

Reglas:

- **`rescue:`** se ejecuta **si** alguna task del `block:` falla. Si todas pasan, no corre.
- **`always:`** corre **siempre**: tras un bloque exitoso, tras un `rescue:` exitoso, incluso tras un `rescue:` que a su vez falló.
- Dentro de `rescue:` tienes la variable `ansible_failed_task` y `ansible_failed_result` para inspeccionar qué task reventó.
- Un `fail:` dentro de `rescue:` sí marca el host como fallido para el resto del play; omítelo si solo querías rollback silencioso.
- `block/rescue/always` **no** es un `transaction` — no revierte efectos; solo da puntos de gancho para que tú escribas la lógica de reversión.

> **Trampa**: la gente mete toda la lógica en `rescue:` y olvida que **si el error ocurre en una task que no soporta check mode y el playbook corre con `--check`**, el flujo nunca entra en rescue — porque la task se saltó, no falló. Prueba tus `rescue` con corridas reales, no solo con check mode.

---

## 6. `delegate_to:` — ejecutar en otro host

Por defecto una task corre en el **host del loop**. Con `delegate_to: <host>` la ejecutas en otro host del inventario (o en `localhost`) manteniendo el contexto del host original (variables, facts).

Casos típicos:

- **Registrar un DNS** al provisionar un nuevo nodo: la task se dispara "por cada nuevo host" pero el `nsupdate` corre en el servidor DNS central.
- **Avisar a un balanceador** que saque un backend del pool antes de reiniciarlo.
- **Escribir un fact del host actual en un fichero local**: `delegate_to: localhost`.

```yaml
- name: Remove node from LB pool
  uri:
    url: "https://lb/api/pool/{{ pool_name }}/drain/{{ inventory_hostname }}"
    method: POST
  delegate_to: lb-primary

- name: Restart app on current host
  systemd:
    name: app
    state: restarted

- name: Put node back in LB pool
  uri:
    url: "https://lb/api/pool/{{ pool_name }}/enable/{{ inventory_hostname }}"
    method: POST
  delegate_to: lb-primary
```

`delegate_facts: true` guarda los facts bajo el host *delegado* en vez del host actual (útil cuando quieres leer facts recolectados en el LB desde tasks posteriores).

---

## 7. `run_once: true` — una vez por play, no por host

Normalmente cada task del play se ejecuta en **cada host** del `hosts:`. Con `run_once: true` la task corre **una sola vez** (en el primer host del batch) y se "aplica" lógicamente a todos.

```yaml
- name: Create DB schema (one-shot, not per host)
  command: /opt/app/bin/create-schema
  run_once: true
  delegate_to: db-primary
```

Combinación habitual: `run_once: true` + `delegate_to: <nodo central>`. Lee: "para todos los hosts del play, pero ejecútalo una sola vez y en el nodo central".

Ojo: `run_once` **respeta `serial:`**: si corres por lotes, `run_once` significa "una vez por lote". Para "una vez en todo el play" asegúrate de que el batch cubre todos los hosts (sin `serial`) o diseña el task para que sea idempotente igualmente.

---

## 8. `serial:` — rolling update por lotes

Por defecto Ansible aplica una task a **todos** los hosts en paralelo (hasta `forks`), avanza a la siguiente task, y así. Para un **rolling restart** necesitas lo contrario: completar el play entero para un lote antes de pasar al siguiente.

```yaml
- hosts: web
  serial: 1                      # un host a la vez
  max_fail_percentage: 0         # cualquier fallo aborta el resto
  tasks:
    - name: Drain
      ...
    - name: Restart
      systemd: { name: app, state: restarted }
    - name: Wait healthy
      uri:
        url: http://{{ inventory_hostname }}:8080/health
        status_code: 200
      retries: 10
      delay: 3
    - name: Undrain
      ...
```

Variantes:

- `serial: 2`: 2 hosts a la vez.
- `serial: "20%"`: 20% del batch.
- `serial: [1, 5, "100%"]`: 1 primero (canario), 5 siguientes, luego el resto. Patrón recomendado para despliegues cuidadosos.

**`max_fail_percentage: N`** aborta el play completo si > N% de hosts del lote fallan. Combinado con `serial`, es la columna vertebral de un rolling restart con red: "canario primero, si falla no sigas".

**Diferencia con handlers**: los handlers se encolan y disparan al final del play; `serial` cambia el ritmo del play entero. Para "restart si cambió config": handler. Para "redeploy ordenado por lotes": `serial`.

---

## 9. Performance: strategy, pipelining, fact caching, Mitogen

Breve, porque este módulo no es de performance:

- **`strategy: linear`** (default): Ansible espera a que todos los hosts terminen una task antes de pasar a la siguiente.
- **`strategy: free`**: cada host avanza a su ritmo. Más rápido en inventarios grandes y heterogéneos, pero rompe `serial` y hace más difícil razonar sobre el flujo.
- **`pipelining = True`** en `ansible.cfg`: evita escribir el script del módulo en disco en el target; lo pasa por SSH stdin. Puede acelerar 2-5× con muchos hosts. Requiere `requiretty` desactivado en sudoers.
- **Fact caching** (`fact_caching = jsonfile|redis|memcached`): guarda facts entre corridas; evita el `setup` cada vez. Útil cuando corres playbooks pequeños contra inventarios grandes.
- **Mitogen**: plugin externo que reemplaza el conector SSH por uno con sesiones persistentes. Puede ser muy rápido, pero su mantenimiento ha sido intermitente y en Ansible moderno el combo `pipelining + fact caching + ssh ControlPersist` suele bastar. Evalúa caso a caso; no es la primera palanca.

> **Regla operativa**: antes de meter Mitogen o `strategy: free`, perfila. Normalmente el cuello de botella es un task mal diseñado (un `shell: curl` dentro de un loop de 500 items), no el conector.

---

## 10. Qué llevarse

- La idempotencia **no la da el lenguaje**; la da **el módulo**. Preferir módulos oficiales; usar `command`/`shell` solo cuando no hay alternativa, y envolverlos con `creates:`/`removes:`/`changed_when:`.
- Check mode es la red de seguridad para producción. **Pero** no todos los módulos lo soportan — diseña tus playbooks sabiéndolo.
- `block/rescue/always` **no es una transacción** — es un gancho para que escribas tu propia lógica de rollback.
- `delegate_to` + `run_once` son la combinación clásica para "efectos globales" (DNS, LB, DB schema).
- `serial` + `max_fail_percentage` + health check tras cada lote = rolling restart con cinturón.
- La performance se mejora **midiendo primero**; no asumas que necesitas Mitogen.

### Qué sigue

- `ans-08` — Molecule, `ansible-lint`, CI matrix: cómo *probar* roles y playbooks que ahora sabes diseñar bien.
- `ans-09` — Ansible junto a Terraform/Packer; patrón `Packer + Ansible → AMI → TF usa AMI` como forma de evitar drift por construcción.
