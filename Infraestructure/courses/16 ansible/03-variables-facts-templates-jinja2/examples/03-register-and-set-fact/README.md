# Ejemplo 03 — `register:` y `set_fact:`

Captura la salida de un `command:` con `register`, extrae un dato con `set_fact`, y lo usa en una task siguiente — todo en `localhost`.

## Archivos

- `inventory.ini` — un host local.
- `playbook.yml` — tres tasks:
  1. `command: uname -s` → `register: uname_out`
  2. `set_fact: detected_os="{{ uname_out.stdout | lower }}"`
  3. `debug` del valor compuesto.

## Ejecutar

```bash
cd examples/03-register-and-set-fact
ansible-playbook -i inventory.ini playbook.yml
```

Output esperado en macOS:

```
TASK [Show detected OS] ********************
ok: [localhost] => {
    "msg": "Detected OS = darwin"
}
```

## Qué observar

- `uname_out.stdout` contiene la salida; `uname_out.rc` el exit code; `uname_out.changed` siempre `true` para `command` salvo que uses `changed_when: false`.
- `set_fact` sobreescribe cualquier `detected_os` que viniera del inventory (precedence nivel 18).
- `changed_when: false` evita que un `command:` puro inflé el *change report*.
