# Ejercicio operativo — Ansible exam

Corre **todo en `localhost`** con el connection plugin `local`. No se requiere SSH, cloud, ni root. No incluyas secretos reales en ningún archivo entregado.

## Prerrequisitos

```bash
command -v ansible && ansible --version          # ansible-core >= 2.16 recomendado
command -v ansible-lint || pipx install ansible-lint
```

Si no está disponible `ansible-core`, el script `validate.sh` imprime `SKIP: ansible-core no disponible` y termina con `exit 0`. En ese caso entrega los archivos solicitados por el enunciado y una transcripción escrita de la salida esperada en `run-transcript.txt`.

## Archivos de inicio

- `inventory.yml` — un solo host (`localhost`), connection local.
- `bad_playbook.yml` — anti-patrón intencional, usa `shell` para todo.
- `validate.sh` — ejecuta tu `good_playbook.yml` dos veces y verifica idempotencia.

## Entregables

- `good_playbook.yml` — versión idempotente.
- `templates/app.conf.j2` — template Jinja2 pedido en OP-task-3.
- `lint-notes.md` — explicación de warnings de `ansible-lint`.
- `run-transcript.txt` — salida de `bash validate.sh` (o SKIP justificado).

## Validación

```bash
bash validate.sh
```

Debe imprimir `OK` al final. Si entra en modo SKIP, documenta el entorno (SO, Python, por qué no estaba Ansible) en `run-transcript.txt`.
