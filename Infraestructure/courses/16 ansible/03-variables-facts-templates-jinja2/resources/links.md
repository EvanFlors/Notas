# ans-03 — Recursos

## Documentación oficial

- [Using Variables (Ansible docs)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) — guía canónica de variables y precedence.
- [Variable precedence: Where should I put a variable?](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence) — la tabla de 22 niveles.
- [Discovering variables: facts and magic variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html) — `ansible_facts`, `inventory_hostname`, `groups`, `hostvars`.
- [Templating (Jinja2) in Ansible](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) — filtros, tests, lookups.
- [`ansible.builtin.template` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html) — opciones del módulo (`validate`, `backup`, `block_start_string`...).
- [`ansible.builtin.set_fact` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/set_fact_module.html).
- [`ansible.builtin.setup` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/setup_module.html) — qué recolecta `gather_facts`.

## Jinja2 directamente

- [Jinja2 template designer docs](https://jinja.palletsprojects.com/en/stable/templates/) — filtros, tests, control structures.
- [List of all Ansible-added filters](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) — los que Ansible añade encima de Jinja2 estándar.

## Lectura recomendada

- "Variable precedence is a feature, not a bug" — buscar en los release notes de ansible-core para entender por qué hay 22 niveles.
- [Ansible for DevOps (Jeff Geerling)](https://www.ansiblefordevops.com/) — capítulo 5 trata variables y templates con ejemplos reales.
