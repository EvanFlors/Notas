# Ejemplo 01 — El esqueleto que genera `ansible-galaxy role init`

## Qué muestra

Qué carpetas y archivos produce el comando oficial para iniciar un role, y qué significa cada uno.

## Comando

```bash
ansible-galaxy role init my_role
```

## Resultado

```
my_role/
├── README.md
├── defaults/
│   └── main.yml
├── files/
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yml
├── templates/
├── tests/
│   ├── inventory
│   └── test.yml
└── vars/
    └── main.yml
```

## Lectura rápida de cada carpeta

| Carpeta       | Para qué                                                                  | Precedence  |
|---------------|---------------------------------------------------------------------------|-------------|
| `defaults/`   | Variables por defecto, pensadas para que el consumidor las sobreescriba.  | 2 (baja)    |
| `vars/`       | Variables internas del role. Si se sobreescriben, el role puede romperse. | 15 (alta)   |
| `tasks/`      | Entry point `main.yml`. Puedes dividir en `install.yml`, `configure.yml`. | n/a         |
| `handlers/`   | Handlers reactivos (`notify:`). Se ejecutan al final del play.            | n/a         |
| `templates/`  | Jinja2 (`.j2`) para `template:`. Se resuelve relativo a esta carpeta.     | n/a         |
| `files/`      | Estáticos para `copy:`. Sin interpolación.                                | n/a         |
| `meta/`       | Autor, licencia, platforms, `galaxy_tags`, `dependencies`.                | n/a         |
| `tests/`      | `test.yml` + `inventory` mínimos. Molecule (`ans-08`) lo supera.          | n/a         |
| `README.md`   | Contrato público. Variables, OS, ejemplo.                                 | n/a         |

## Snippet mínimo `tasks/main.yml`

```yaml
---
# tasks file for my_role
- name: Ensure package is installed
  ansible.builtin.package:
    name: "{{ my_role_pkg }}"
    state: present
  become: true
```

Con `defaults/main.yml`:

```yaml
---
my_role_pkg: nginx
```

## Qué NO está en el esqueleto

- `meta/argument_specs.yml` — definición formal de argumentos (opcional, útil para validar input).
- `library/`, `module_utils/`, `plugins/` — se usan cuando el role incluye módulos propios (menos común, suele ir en una **collection**).

## Ver también

- `../02-role-nginx/` — un role real con contenido en cada carpeta.
- `../03-import-vs-include-role/` — cuándo invocar un role con `import_role` vs `include_role`.
