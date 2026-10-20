# ans-03 — Variables, facts, templates y Jinja2

## Identificación

- **ID:** `ans-03-variables-facts-templates-jinja2`
- **Curso:** `ansible`
- **Nivel:** fundamentos (beginner en metadata)
- **Duración estimada:** 3 h
- **Prerrequisitos:** `ans-02` (playbooks, módulos, handlers).

## Objetivo

Aprender a **parametrizar** playbooks con disciplina: entender las fuentes de variables, el orden de precedence, los `facts` que Ansible recolecta, y cómo escribir **templates Jinja2** correctos para generar archivos de configuración reales (`nginx.conf`, vhosts, `unit` files de systemd) sin meter lógica de negocio dentro del template.

Al terminar deberías:

- Saber dónde pondrías cada variable (play vars, inventory, `group_vars/`, `host_vars/`, `defaults` de role, extra vars) y por qué.
- Predecir el valor final de una variable cuando varias fuentes la definen.
- Escribir una plantilla `nginx.conf.j2` que renderice correctamente en 2+ entornos (dev y prod) solo cambiando el inventory.
- Usar `register:` + `set_fact:` para capturar resultados y encadenar tasks.
- Diferenciar un *fact* (`ansible_facts.distribution`) de una *var* del inventory.

## Alcance

Este módulo cubre:

- **Fuentes de variables**: `vars:` en play, inventory inline, `group_vars/<grupo>.yml`, `host_vars/<host>.yml`, `defaults/` y `vars/` de role, `-e @file.yml` y `-e key=value` en línea de comandos.
- **Precedence**: 22 niveles en la documentación oficial. La moraleja práctica — usar pocos y entenderlos — es la que vas a interiorizar.
- **Facts**: qué recolecta `setup` (OS, red, memoria, CPU, discos), cómo acceder (`ansible_facts.distribution`, `ansible_default_ipv4.address`), cuándo desactivarlos (`gather_facts: false`), fact caching.
- **Jinja2**: `{{ var }}`, filtros (`default`, `upper`, `to_json`, `regex_replace`, `combine`, `union`), estructuras (`{% if %}`, `{% for %}`), *whitespace control* (`{%- %}`), herencia de plantillas (`{% include %}`).
- **Templates y lookups**: módulo `ansible.builtin.template` para renderizar archivos; `lookup('file', ...)`, `lookup('env', ...)`, `lookup('vars', ...)`.
- **`register:` y `set_fact:`**: capturar el `result` de una task y usarlo en tasks siguientes.

Lo que **no** cubre (siguiente módulo):

- Roles (`ansible-galaxy role init`), encapsulación de todo lo anterior en una unidad reutilizable → `ans-04`.
- Collections, Vault, idempotency avanzada → `ans-05`, `ans-06`, `ans-07`.

Este módulo se ejecuta **100% en localhost** con `--connection=local`. No hace falta levantar VMs ni pagar nada. Los playbooks tocan `/tmp/` para no ensuciar el sistema.

## Materiales

- **`theory/lesson.md`** — lección con 8 secciones.
- **`examples/`** — ejemplos leíbles (puedes ejecutarlos en local):
  - `01-template-nginx-conf/` — render de `nginx.conf` desde una plantilla Jinja2 parametrizada.
  - `02-group-vars-and-overrides/` — tres hosts, dos grupos, mismo var definido en varios niveles. Ejecuta el playbook y observa cuál gana.
  - `03-register-and-set-fact/` — capturar la salida de un `command:` y usarla luego.
- **`activities/`**:
  - `01-nginx-vhost-template/` — guiada: escribir un `vhost.conf.j2` que acepte N upstreams en loop y render al vuelo para dev y prod.
  - `02-precedence-exercise/` — independiente: dado un conjunto de definiciones en 4 niveles, el estudiante predice y luego comprueba el valor final.
- **`resources/links.md`** — documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en 2 minutos la jerarquía de precedence sin leer la doc; distinguir fact de var. |
| Operativa | Convertir un `nginx.conf` hardcodeado en una plantilla reutilizable; usar `register:` + `when:` para flujos condicionales. |
| Diseño | Decidir qué va en `group_vars/` vs `host_vars/` vs `defaults/`; evitar lógica de negocio dentro de un template. |

## Criterios de evaluación

- Dado un conjunto de variables en 3 niveles distintos, predices el valor final sin ejecutar Ansible.
- Lees una plantilla Jinja2 y describes qué renderiza con un inventory dado.
- Entregas las dos actividades con sus validadores en verde (requiere `ansible` instalado localmente; el validador *skippea* si no lo está, pero el ejercicio en sí requiere ejecutarlo).

## Entregables

- Plantilla `vhost.conf.j2` reutilizable (sale de la actividad 01).
- Reporte `precedence-report.txt` que demuestra qué nivel ganó para cada variable (sale de la actividad 02).

## Costos

**Ninguno.** Todo corre en localhost. Herramientas: `ansible-core` (`pipx install ansible` o `pip install ansible-core`), `python3`, `bash`.

## Siguiente módulo

→ `ans-04-roles-structure-and-reuse` — encapsular lo anterior en roles reutilizables.
