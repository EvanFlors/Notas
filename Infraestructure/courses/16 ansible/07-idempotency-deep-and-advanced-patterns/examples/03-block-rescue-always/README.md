# Ejemplo 03 — `block:` + `rescue:` + `always:`

Demuestra try/except/finally en Ansible: una task "arriesgada" falla, `rescue:` hace rollback, `always:` limpia el flag de mantenimiento siempre.

## Playbook

Guarda como `play.yml`:

```yaml
---
- name: block/rescue/always demo
  hosts: localhost
  gather_facts: false
  vars:
    maintenance_flag: /tmp/ans-07-ex03.maintenance
    rollback_flag:    /tmp/ans-07-ex03.rollback
    # Cambia a false para ver la ruta exitosa.
    simulate_failure: true

  tasks:
    - name: Fake deploy with safety net
      block:
        - name: Enter maintenance mode
          file:
            path: "{{ maintenance_flag }}"
            state: touch
            mode: "0644"

        - name: Risky migration (puede fallar)
          command: /bin/false
          when: simulate_failure | bool

        - name: Risky migration (ruta exitosa)
          command: /bin/true
          when: not (simulate_failure | bool)

      rescue:
        - name: Rollback — crear flag de reversion
          file:
            path: "{{ rollback_flag }}"
            state: touch
            mode: "0644"

        - name: Avisar que hubo rescue
          debug:
            msg: "rescue ejecutado porque {{ ansible_failed_task.name }} fallo"

      always:
        - name: Clean maintenance flag (siempre)
          file:
            path: "{{ maintenance_flag }}"
            state: absent
```

## Cómo correrlo

```bash
# Ruta de fallo (default): rescue y always ejecutan; el play termina con FAILED.
ansible-playbook play.yml
ls /tmp/ans-07-ex03.*                 # solo quedara ans-07-ex03.rollback

# Ruta exitosa: rescue no corre; always sigue limpiando.
ansible-playbook play.yml -e simulate_failure=false

# Limpieza.
rm -f /tmp/ans-07-ex03.*
```

## Qué observar

- Con `simulate_failure=true`: la task "Risky migration" falla, se dispara `rescue:` (crea el rollback flag), luego `always:` borra el maintenance flag, y el play termina con **UNREACHABLE/FAILED** salvo que `rescue:` termine sin `fail:` adicional.
- Con `simulate_failure=false`: la task risky pasa, `rescue:` **no** corre, `always:` sí.
- `ansible_failed_task.name` dentro de `rescue:` te permite loggear exactamente qué task reventó.
- `always:` **no** rescata: solo garantiza "finally".
