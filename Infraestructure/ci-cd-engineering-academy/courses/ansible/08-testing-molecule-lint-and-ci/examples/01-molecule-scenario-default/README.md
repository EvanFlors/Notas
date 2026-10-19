# Ejemplo 01 — Scenario `default/` de Molecule

Este ejemplo muestra la **estructura mínima** de un scenario de Molecule para un role trivial que instala y arranca `nginx` en una distro basada en Debian.

> Lectura, no obligatoriamente ejecución. Si quieres correrlo:
> `pip install molecule 'molecule-plugins[docker]' docker ansible-core && molecule test`
> dentro de un role que contenga este directorio.

## Layout

```
my-role/
├── defaults/main.yml
├── handlers/main.yml
├── tasks/main.yml
├── meta/main.yml
└── molecule/
    └── default/
        ├── molecule.yml
        ├── converge.yml
        └── verify.yml
```

## `molecule/default/molecule.yml`

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    command: /sbin/init
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
provisioner:
  name: ansible
verifier:
  name: ansible
```

## `molecule/default/converge.yml`

```yaml
---
- name: Converge
  hosts: all
  become: true
  tasks:
    - name: Include my-role
      ansible.builtin.include_role:
        name: my-role
```

## `molecule/default/verify.yml`

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  become: true
  tasks:
    - name: Gather service facts
      ansible.builtin.service_facts:

    - name: Assert nginx is running
      ansible.builtin.assert:
        that:
          - "'nginx.service' in services"
          - services['nginx.service'].state == 'running'
```

## Ciclo observable

```
$ molecule test
PLAY RECAP (converge, 1a pasada):   changed=4
PLAY RECAP (idempotence, 2a pasada): changed=0   # <- esto es lo que molecule espera
PLAY RECAP (verify):                 failed=0
```

Si la 2ª pasada reporta `changed>0`, Molecule falla el step `idempotence` y el ciclo completo falla.
