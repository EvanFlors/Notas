# Recursos — ans-07

## Oficial (ansible-core 2.17/2.18)

- [Check mode & diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html) — reglas, limitaciones por módulo, `check_mode: false` forzado.
- [Error handling: block/rescue/always](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html) — semántica exacta de cuándo cada bloque dispara.
- [Delegation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_delegation.html) — `delegate_to`, `delegate_facts`, `run_once`.
- [Rolling updates (`serial`)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html#setting-the-batch-size-with-serial) — valores escalares, porcentajes, listas, `max_fail_percentage`.
- [Strategies (`linear`, `free`, `host_pinned`)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html).
- [`command` module (nota sobre `creates`/`removes`)](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html).
- [`changed_when` / `failed_when` reference](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html).

## Lecturas recomendadas

- Jeff Geerling, *Ansible for DevOps*, capítulos sobre idempotencia y rolling deployments (edición actualizada a ansible-core 2.1x).
- [Red Hat blog — "Why idempotency matters"](https://www.redhat.com/en/blog) — buscar por "ansible idempotent".
- Repo de referencia `ansible/ansible` — issues etiquetados `check_mode` para ver qué módulos tienen soporte parcial.

## Performance

- [`pipelining` en `ansible.cfg`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#ansible-pipelining).
- [Fact caching plugins](https://docs.ansible.com/ansible/latest/plugins/cache.html).
- Mitogen for Ansible — estado del proyecto variable; antes de adoptarlo revisar el último release y los issues abiertos.
