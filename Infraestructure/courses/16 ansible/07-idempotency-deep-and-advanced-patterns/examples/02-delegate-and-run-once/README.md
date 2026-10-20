# Ejemplo 02 — `delegate_to` y `run_once`

Demuestra ejecutar una task en un host distinto al del loop (`delegate_to`) y una task "una sola vez por play" (`run_once`), usando inventario local con 3 "hosts" ficticios.

## Inventario

Guarda como `inventory.ini`:

```ini
[web]
web-a ansible_connection=local
web-b ansible_connection=local
web-c ansible_connection=local

[registry]
registry-1 ansible_connection=local
```

> Todos apuntan a `local`; esto permite jugar con topología multi-host sin VMs.

## Playbook

Guarda como `play.yml`:

```yaml
---
- name: delegate_to and run_once demo
  hosts: web
  gather_facts: false

  tasks:
    - name: Per-host task — runs 3 times
      debug:
        msg: "soy {{ inventory_hostname }}, haciendo mi trabajo"

    - name: Delegated task — runs 3 times, but logically on registry-1
      debug:
        msg: "registrando {{ inventory_hostname }} en el registry central"
      delegate_to: registry-1

    - name: One-shot task — runs ONCE, delegated to registry-1
      debug:
        msg: "notificacion global: deploy terminado para toda la flota web"
      run_once: true
      delegate_to: registry-1
```

## Cómo correrlo

```bash
ansible-playbook -i inventory.ini play.yml
```

## Qué observar

- La primera task se ejecuta **3 veces** (una por host de `[web]`).
- La segunda también se ejecuta 3 veces (una por host de loop) pero cada iteración "aparece" ejecutada en `registry-1`.
- La tercera se ejecuta **una sola vez**: el output muestra el host de delegación en vez de los 3 hosts.
- Patrón real: `delegate_to: lb-primary` + `run_once: true` para "sacar del LB el servicio compartido antes de empezar el rolling" (una sola vez por play, aunque haya 20 hosts en `[web]`).
