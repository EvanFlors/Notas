# Ejemplo 01 — `shell:` con `creates:` y `changed_when:`

Demuestra la diferencia entre un `shell:` "ingenuo" (siempre `changed`) y uno envuelto con `creates:` o `changed_when:` para fingir idempotencia.

## Playbook

Guarda como `play.yml`:

```yaml
---
- name: Idempotent shell demo
  hosts: localhost
  gather_facts: false
  vars:
    marker: /tmp/ans-07-ex01.marker

  tasks:
    # Antipatrón: siempre reporta changed.
    - name: Naive shell (always changed)
      shell: echo "hola $(date +%s)"
      register: naive
      tags: naive

    # Patrón 1: creates — ni siquiera corre si el marker existe.
    - name: Shell with creates (skipped if marker exists)
      shell: "echo creado > {{ marker }}"
      args:
        creates: "{{ marker }}"
      tags: creates

    # Patrón 2: changed_when — corre siempre pero no contabiliza como changed.
    - name: Pure read-only check
      command: cat /etc/hostname
      register: host
      changed_when: false
      failed_when: host.rc != 0
      tags: readonly

    # Patrón 3: changed_when con regex sobre stdout.
    - name: Fake sync, only changed when output says 'created'
      shell: 'echo "nothing to do"'
      register: sync
      changed_when: '"created" in sync.stdout'
      tags: smart
```

## Cómo correrlo

```bash
# Primera corrida: todo pasa.
ansible-playbook play.yml

# Segunda corrida: 'creates' se salta; 'readonly' y 'smart' nunca cuentan como changed;
# el 'naive' sigue reportando changed (es el punto).
ansible-playbook play.yml

# Limpieza para repetir.
rm -f /tmp/ans-07-ex01.marker
```

## Qué observar

- El recap de la **segunda** corrida: solo el task "Naive" dice `changed=1`. Los otros son `ok` o `skipped`.
- Si borras el marker (`rm /tmp/ans-07-ex01.marker`) y corres de nuevo, el task "creates" vuelve a ejecutarse.
- `changed_when: false` es la palanca más usada para read-only checks.
