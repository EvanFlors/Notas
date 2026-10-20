# Starter — ans-07-01-make-playbook-idempotent

Esta actividad es **independiente**. Tu entregable es un `site.yml` reescrito.

## Pasos

1. Lee `../README.md` completo y recorre los `examples/` del módulo (en especial `01-shell-with-creates`, `03-block-rescue-always` y `04-check-and-diff-mode`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-07-01
   cp site.yml /tmp/ans-07-01/site.yml
   cd /tmp/ans-07-01
   ```
3. Edita `/tmp/ans-07-01/site.yml` siguiendo las pistas inline y el checklist de `../README.md` §5.3.
4. Verifica a mano:
   ```bash
   ansible-playbook site.yml           # 1a corrida
   ansible-playbook site.yml           # 2a corrida — debe reportar changed=0
   ansible-playbook site.yml --check --diff
   ```
5. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/07-idempotency-deep-and-advanced-patterns/activities/01-make-playbook-idempotent/tests/validate.sh /tmp/ans-07-01
   ```
6. Compara con `../solution/site.yml` para autoevaluarte.

## Qué debe aparecer en tu `site.yml`

- `creates:` en al menos una task `shell`/`command`.
- `changed_when:` explícito en al menos una task.
- `failed_when:` explícito en al menos una task.
- `check_mode:` explícito en al menos una task.
- Un `block:` con `rescue:` y `always:` alrededor del bloque riesgoso.
