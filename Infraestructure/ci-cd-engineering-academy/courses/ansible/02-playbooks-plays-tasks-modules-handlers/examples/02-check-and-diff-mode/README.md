# Ejemplo 02 — Check mode y diff mode

Ilustra la **red de seguridad** para operar en prod: ver qué cambiaría antes de aplicarlo.

## Ejecutar

```bash
# Dry-run: Ansible simula, no toca el host.
ansible-playbook -i inventory.ini playbook.yml --check --diff

# Luego aplicar de verdad.
ansible-playbook -i inventory.ini playbook.yml
```

## Observaciones

- Con `--check` cualquier task que use `shell:` o `command:` sin `check_mode: true` falla o se salta (los módulos arbitrarios no son dry-run por default).
- Los módulos nativos (`copy`, `template`, `file`, `lineinfile`) muestran el **diff real** del archivo con `--diff`.
- Esto se combina con `--limit host1` para probar en un solo nodo antes del rolling.
