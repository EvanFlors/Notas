# ans-02 — Playbooks, plays, tasks, módulos y handlers

## Identificación

- **ID:** `ans-02-playbooks-plays-tasks-modules-handlers`
- **Curso:** `ansible`
- **Nivel:** fundamentos (beginner)
- **Duración estimada:** 4 h
- **Prerrequisitos:** `ans-01-cm-vs-iac-setup-inventory-and-adhoc`.

## Objetivo

Escribir **playbooks correctos** usando módulos idempotentes y **handlers** reactivos. Entender el ciclo play → tasks → handlers, el papel de `become`, `when:`, `loop:`, tags y los modos `--check` / `--diff` que convierten a Ansible en una herramienta operable en producción.

## Alcance

Este módulo cubre:

- Estructura de un `playbook.yml`: un archivo contiene una o más **plays**; cada play aplica a `hosts:`, declara `vars:`, ejecuta `tasks:` y responde con `handlers:`.
- **Módulos idempotentes** fundamentales: `apt`/`yum`/`dnf`/`package`, `file`, `copy`, `template`, `service`/`systemd`, `user`, `group`, `cron`, `lineinfile`/`blockinfile`, `uri`, `wait_for`.
- **Handlers**: por qué un `notify:` dispara el handler **una sola vez al final del play** y solo si la tarea reportó `changed`.
- Elevación de privilegios: `become: true` + `become_method: sudo`.
- Control de flujo: `when:` para condicionales, `loop:` (y `loop_control:`) para iteración.
- **Tags**: `--tags`, `--skip-tags` para ejecutar partes selectivas de un playbook grande.
- Modos seguros: `--check` (dry-run) y `--diff` (muestra el delta de archivos).
- Fundamentos internos: por qué `shell:` **no** es idempotente por defecto y qué significa que un módulo "consulte el estado antes de actuar".

Lo que **no** cubre (se verá después):

- Variables, facts, Jinja2 y precedence → `ans-03`.
- Roles y estructura reutilizable → `ans-04`.
- Patrones avanzados (`delegate_to`, `serial`, `block/rescue`, `async`) → `ans-07`.
- Testing con Molecule → `ans-08`.

Este módulo es **mayoritariamente práctico**. Los ejemplos y actividades están pensados para correr contra **localhost** (connection `local`) o contra un **contenedor Docker** levantado por el estudiante. No se requiere infraestructura cloud.

## Materiales

- **`theory/lesson.md`** — lección profunda estructurada en 8 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y ejecución local):
  - `01-install-nginx-with-handler/` — play completa: instala nginx, publica una config por `template` y reinicia por **handler**.
  - `02-check-and-diff-mode/` — misma play ejecutada con `--check` y `--diff` para ilustrar la red de seguridad en prod.
  - `03-tags-selective-run/` — un playbook con tags (`install`, `config`, `service`) y ejecución selectiva.
- **`activities/`** — dos actividades complementarias:
  - `01-nginx-reverse-proxy/` — **guided-lab**: escribir un playbook idempotente que configura nginx como reverse proxy a `127.0.0.1:8080` con handler de reload.
  - `02-fix-non-idempotent-task/` — **debug**: recibir un playbook roto con `shell:` repetitivos y convertirlo en idempotente usando `creates:`, `changed_when:` y `lineinfile`.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué significa "idempotente", cuándo un módulo reporta `changed` y por qué un handler se ejecuta una sola vez al final del play. |
| Operativa | Escribir una play completa con `become`, `tasks`, `handlers`, `notify`, `when` y `loop`; ejecutarla con `--check --diff` antes de aplicar. |
| Diagnóstico | Reconocer un `shell:` no idempotente y repararlo con `creates:`/`removes:`/`changed_when:` o con el módulo nativo adecuado. |

## Criterios de evaluación

- El playbook de la actividad 01 converge nginx en 1 host (localhost o contenedor), configura el reverse proxy y es **idempotente** (segunda ejecución reporta `0 changed`).
- El handler se dispara exactamente cuando cambia la plantilla, no en cada ejecución.
- El playbook de la actividad 02 corre dos veces y reporta `ok=N  changed=0` en la segunda vuelta.
- `bash tests/validate.sh` sale con `0 issue(s)` en ambas actividades.

## Cómo ejecutar los ejemplos

Los ejemplos están pensados para correr contra el propio host (`ansible_connection: local`) o contra un contenedor Ubuntu/Debian al que te conectes por SSH. El `inventory.ini` de cada ejemplo apunta a `localhost` por defecto. Para correr contra un contenedor:

```bash
docker run -d --name ans-target -p 2222:22 \
  -e "ROOT_PASS=ansible" \
  rastasheep/ubuntu-sshd:18.04
# Luego apunta el inventory a localhost:2222 con ansible_user=root.
```

Si `ansible-playbook` no está instalado los validadores lo detectan y **saltan graciosamente** las comprobaciones dinámicas, manteniendo las estructurales.
