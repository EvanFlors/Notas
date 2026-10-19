# Ejemplo 03 — `import_role` vs `include_role`

## Qué muestra

Las dos formas de invocar un role desde dentro de un play (fuera de la sección `roles:`), con sus diferencias observables.

## Resumen de un vistazo

| Aspecto             | `import_role`                    | `include_role`                       |
|---------------------|----------------------------------|--------------------------------------|
| Momento de carga    | **Parse time** (eager)           | **Runtime** (lazy)                   |
| `loop:`             | **No** soportado                 | **Sí**                               |
| `when:`             | Se aplica a cada task del role   | Se evalúa al momento de incluir      |
| Tags externos       | **Sí** propagan hacia dentro     | **No** propagan                      |
| Errores de sintaxis | Detectados antes de empezar      | Detectados al llegar al include      |
| Variables dinámicas | Nombre del role debe ser literal | Nombre puede venir de un fact / var  |

## Snippet A — `import_role` (el default)

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Apply nginx role eagerly
      ansible.builtin.import_role:
        name: nginx
      vars:
        nginx_port: 8080
      tags: [web]
```

Si corres `ansible-playbook site.yml --tags web`, se ejecutan **todos** los tasks del role `nginx`. Si el role no existe en `roles/`, Ansible falla **antes** de empezar el play.

## Snippet B — `include_role` con `loop:`

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    apps:
      - name: api
        port: 8080
      - name: admin
        port: 8081
  tasks:
    - name: Apply nginx role per app
      ansible.builtin.include_role:
        name: nginx
      vars:
        nginx_port: "{{ item.port }}"
        nginx_server_name: "{{ item.name }}.example.com"
      loop: "{{ apps }}"
```

Esto es imposible con `import_role` porque no acepta `loop:`.

## Snippet C — `include_role` con nombre dinámico

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Pick role based on OS family
      ansible.builtin.include_role:
        name: "{{ 'nginx-debian' if ansible_facts.os_family == 'Debian' else 'nginx-rhel' }}"
```

Imposible con `import_role` porque el nombre se resuelve en runtime.

## Error típico: tags que no filtran

```bash
ansible-playbook include-with-tags.yml --tags configure
```

Si dentro de un `include_role` tienes tasks con `tags: [configure]`, **no se ejecutan** porque el include completo no fue tagueado desde fuera. Esto confunde a mucha gente. Soluciones:

- Usa `import_role` si quieres filtrado por tags externos.
- O etiqueta el `include_role` entero y acepta que corre todo lo de dentro:

```yaml
- include_role:
    name: nginx
    apply:
      tags: [web]
  tags: [web]
```

## Regla operativa

1. **Por defecto, `import_role`** o directamente la sección `roles:` del play. Más predecible.
2. **`include_role` sólo** cuando necesitas `loop:` o cuando el nombre del role depende de un valor dinámico (fact, var).
3. Si cambias de `import` a `include`, revisa los tags que esperabas filtrar.
