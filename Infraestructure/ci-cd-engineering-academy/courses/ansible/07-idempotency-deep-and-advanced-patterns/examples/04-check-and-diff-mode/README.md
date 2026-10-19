# Ejemplo 04 — Check mode y diff mode

Demuestra `--check` y `--diff`, y cómo `command`/`shell` se saltan por defecto en check mode salvo que uses `check_mode: false`.

## Playbook

Guarda como `play.yml`:

```yaml
---
- name: check & diff mode demo
  hosts: localhost
  gather_facts: false
  vars:
    target: /tmp/ans-07-ex04.conf

  tasks:
    - name: Write config (soporta check + diff)
      copy:
        dest: "{{ target }}"
        mode: "0644"
        content: |
          # version 1
          key = value

    - name: Shell que NO corre en check mode (skipped por defecto)
      shell: "echo 'esto no se simula en check' >> {{ target }}"
      changed_when: false

    - name: Query de solo lectura — forzamos que corra en check mode
      command: "cat {{ target }}"
      register: dump
      changed_when: false
      check_mode: false      # fuerza ejecucion incluso con --check

    - name: Mostrar contenido leido
      debug:
        var: dump.stdout_lines
```

## Cómo correrlo

```bash
# Primera corrida real.
ansible-playbook play.yml

# Cambia la version a mano:
sed -i.bak 's/version 1/version 2/' /tmp/ans-07-ex04.conf

# Dry-run con diff: 'copy' muestra el diff; 'shell' se salta; el 'command' corre
# porque pusimos check_mode: false; el 'debug' muestra lo que lee.
ansible-playbook play.yml --check --diff

# Aplicar realmente.
ansible-playbook play.yml

# Limpieza.
rm -f /tmp/ans-07-ex04.conf /tmp/ans-07-ex04.conf.bak
```

## Qué observar

- `copy:` imprime el diff coloreado del contenido que **cambiaria** si no fuera check mode.
- La task `shell:` aparece como **`skipped`** en check mode (Ansible no sabe simularla).
- La task con `check_mode: false` corre de verdad aunque invoques `--check` — útil para queries read-only cuyos datos quieres usar más adelante en el play.
- Esta asimetría ("algunos módulos simulan, otros se saltan") es la razón por la que un `--check` limpio **no garantiza** un `--apply` limpio: puede haber dependencias en tasks skipped.
