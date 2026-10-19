# Recursos — ans-04 Roles

## Docs oficiales

- [Reusing Ansible artifacts — Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [`ansible-galaxy role init`](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#creating-roles)
- [Variable precedence (22 niveles)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [`import_role` vs `include_role`](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html#dynamic-vs-static)
- [`meta/main.yml` — dependencies](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#using-role-dependencies)
- [Argument validation con `meta/argument_specs.yml`](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#role-argument-validation)

## Lecturas

- Jeff Geerling — *Ansible for DevOps* (capítulos de roles y Galaxy).
- Red Hat — [Best practices for roles](https://www.ansible.com/blog/ansible-best-practices-roles-separation).
- Ansible Lint — [reglas que afectan roles](https://ansible-lint.readthedocs.io/rules/).

## Repositorios de referencia

- [`geerlingguy/ansible-role-nginx`](https://github.com/geerlingguy/ansible-role-nginx) — ejemplo canónico, con Molecule y matrix CI.
- [`ansible-collections/community.general`](https://github.com/ansible-collections/community.general) — ver cómo las collections empaquetan roles + modules.

## Siguiente módulo

- `ans-05-collections-galaxy-and-automation-hub` — empaquetar varios roles en una collection.
- `ans-08-testing-molecule-lint-and-ci` — probar roles como se prueba código.
