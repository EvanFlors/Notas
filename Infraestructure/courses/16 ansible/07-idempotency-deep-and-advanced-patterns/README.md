# ans-07 — Idempotencia profunda y patrones avanzados

## Identificación

- **ID:** `ans-07-idempotency-deep-and-advanced-patterns`
- **Curso:** `ansible`
- **Nivel:** advanced
- **Duración estimada:** 4 h
- **Prerrequisitos:** `ans-02` (playbooks/handlers), `ans-04` (roles).

## Objetivo

Interiorizar qué significa que un playbook sea **idempotente de verdad** (y no "run-once-and-hope") y aprender los patrones avanzados (`check_mode`, `changed_when`, `failed_when`, `block/rescue/always`, `delegate_to`, `run_once`, `serial`) que resuelven los casos donde los módulos ingenuos fallan.

Al terminar deberías poder convertir un playbook plagado de `shell:` imperativos en uno que se puede correr N veces sin romper nada, y diseñar un rolling restart con red de seguridad para producción.

## Alcance

Este módulo cubre:

- **Idempotencia desde dentro**: cómo decide un módulo que algo está `changed`; por qué `command`/`shell` no son idempotentes por defecto.
- **Herramientas para forzar idempotencia** en `command`/`shell`: `creates:`, `removes:`, `changed_when:`, `failed_when:`.
- **Check mode (`--check`) y diff mode (`--diff`)**: la red de seguridad para operar producción; qué módulos no lo soportan y cómo marcar tasks con `check_mode: true/false` explícito.
- **`block:` + `rescue:` + `always:`**: try/except/finally para playbooks; cuándo rescue sí ejecuta y cuándo no.
- **`delegate_to:`**: ejecutar una task en un host distinto al del loop (típico para registrar en un DNS central).
- **`run_once: true`**: ejecutar una task una sola vez por play (útil para registros globales).
- **`serial: N` / `serial: "20%"`**: rolling update por lotes, con `max_fail_percentage` como cinturón de seguridad.
- **Patrones de performance**: `strategy: free`, `pipelining`, `fact caching` (mención; sin lab profundo).

Lo que **no** cubre:

- Testing con Molecule (es el módulo siguiente: `ans-08`).
- Mitogen y otros aceleradores externos (se mencionan; no se laboran).
- Event-Driven Ansible (va en `ans-09`).

Todas las actividades corren **en `localhost`** (sin VMs ni infraestructura cloud). El inventario simula varios hosts con `ansible_connection=local` para poder trabajar `serial` y `delegate_to` sin montar red.

## Materiales

- **`theory/lesson.md`** — lección profunda en 10 secciones.
- **`examples/`** — ejemplos ejecutables en `localhost`:
  - `01-shell-with-creates/` — convertir un `shell:` no idempotente usando `creates:` y `changed_when:`.
  - `02-delegate-and-run-once/` — un task que corre solo una vez y en un host distinto al del loop.
  - `03-block-rescue-always/` — try/except/finally con `block/rescue/always`.
  - `04-check-and-diff-mode/` — correr un playbook en modo `--check --diff` y observar la diferencia con un `shell:` que fuerza `check_mode: false`.
- **`activities/`** — dos actividades independientes:
  - `01-make-playbook-idempotent/` (guided-lab): toma un playbook "sucio" y lo reescribe para que la **segunda** ejecución reporte `changed=0`.
  - `02-rolling-restart-with-serial/` (independent): rolling restart sobre 3 "hosts" locales con `serial: 1`, `delegate_to`, `run_once`, `block/rescue/always` y `max_fail_percentage`.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `shell: echo hola` siempre reporta `changed`; cuándo rescue se dispara y cuándo no; qué garantiza check mode y qué no. |
| Operativa | Reescribir un `shell:` imperativo como task pseudo-idempotente con `creates:` + `changed_when:`; interpretar un recap de rolling restart. |
| Arquitectónica | Decidir el valor de `serial` y `max_fail_percentage` para un workload dado; identificar qué debería ir en `always:` y qué no. |

## Criterios de evaluación

- La segunda corrida de tus playbooks produce `changed=0` en el recap.
- Tu rolling restart no toca el host #2 si el health check del host #1 falla.
- Puedes correr tu playbook con `--check --diff` sin que falle, y entiendes qué partes no se "ensayan" realmente.
- Los dos validadores (`activities/*/tests/validate.sh`) terminan en verde.

## Entregables

- Playbook `site.yml` **idempotente** (actividad 01) que converge en una segunda corrida con `changed=0`.
- Playbook `rolling.yml` (actividad 02) que simula el rolling restart de 3 instancias con `serial: 1`, verifica salud tras cada lote y aborta si una falla.

## Costos

**Ninguno.** Todo corre contra `localhost`. Necesitas `ansible-core` instalado (`pipx install ansible` o `pip install --user ansible-core`).

## Siguiente módulo

→ `ans-08-testing-molecule-lint-and-ci` — probar roles con Molecule, `ansible-lint`, y matriz CI (ubuntu/debian/rocky × ansible-core versiones).
