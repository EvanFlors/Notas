# Reference — ans-03-02-precedence-exercise

## Resultado esperado (sin extra vars)

```
web1: app_port=7000
web2: app_port=7000
db1: app_port=7000
```

Los tres son `7000` porque `vars:` de la play (nivel 11 de precedence) gana a `host_vars/` del inventory (nivel 8) y a `group_vars/` (niveles 6-7). El `9090` de `host_vars/web2.yml` **pierde** aunque este definido mas abajo en el filesystem.

## Resultado esperado (con `-e app_port=9999`)

```
web1: app_port=9999
web2: app_port=9999
db1: app_port=9999
```

Extra vars (nivel 21) gana a todo.

## Por que `run_once: true` + `delegate_to: localhost`

Sin esto, `ansible.builtin.template` corre una vez por host del inventario y sobreescribe el mismo archivo tres veces (idempotente, pero conceptualmente feo y mas lento). Con `run_once: true` el template se renderiza una sola vez; dentro del template iteramos `groups['all']` para obtener la lista completa y `hostvars[h].app_port` para el valor resuelto por host.

## Trampa habitual

El error tipico es poner `app_port: 1234` en `group_vars/all.yml` y "esperar" que se vea en el output. Si el playbook tiene `vars: { app_port: 7000 }`, el valor del inventory **nunca** aparece. Lo descubres cambiando `app_port` en el inventory y viendo que no pasa nada.
