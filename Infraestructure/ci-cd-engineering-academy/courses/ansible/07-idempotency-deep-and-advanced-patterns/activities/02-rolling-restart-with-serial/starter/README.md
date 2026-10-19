# Starter — ans-07-02-rolling-restart-with-serial

Esta actividad es **independiente**. Produces `inventory.ini` y `rolling.yml`.

## Pasos

1. Lee `../README.md` completo y el example `02-delegate-and-run-once` del módulo.
2. Prepara:
   ```bash
   mkdir -p /tmp/ans-07-02
   cp inventory.ini rolling.yml /tmp/ans-07-02/
   cd /tmp/ans-07-02
   # Limpia logs de corridas previas
   rm -f /tmp/ans-07-02.*.log /tmp/ans-07-02.done
   ```
3. Edita `rolling.yml` siguiendo los `# TODO`. Debe quedar con:
   - `serial: 1`, `max_fail_percentage: 0`.
   - Un `delegate_to: lb-primary` para drain **y** otro para undrain.
   - `block/rescue/always` por host.
   - Una task final con `run_once: true` + `delegate_to: lb-primary`.
4. Corre:
   ```bash
   rm -f /tmp/ans-07-02.*.log /tmp/ans-07-02.done
   ansible-playbook -i inventory.ini rolling.yml
   cat /tmp/ans-07-02.processed.log       # debe listar los 3 hosts en orden
   ls   /tmp/ans-07-02.done                # debe existir
   ```
5. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/07-idempotency-deep-and-advanced-patterns/activities/02-rolling-restart-with-serial/tests/validate.sh /tmp/ans-07-02
   ```
6. Compara con `../solution/rolling.yml`.

## Qué debe aparecer en `rolling.yml`

- `serial: 1`
- `max_fail_percentage: 0`
- `delegate_to:` (al menos 2 veces, apuntando a `lb-primary`)
- `run_once: true` (al menos 1 vez)
- `block:`, `rescue:`, `always:`
