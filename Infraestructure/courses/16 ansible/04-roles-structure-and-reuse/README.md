# ans-04 — Roles: estructura y reutilización

## Identificación

- **ID:** `ans-04-roles-structure-and-reuse`
- **Curso:** `ansible`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `ans-01` (inventario y ad-hoc), `ans-02` (playbooks, handlers), `ans-03` (vars, facts, Jinja2).

## Objetivo

Dejar de escribir **playbooks monolíticos** y empezar a empaquetar la lógica en **roles**: unidades reutilizables con `defaults/`, `tasks/`, `handlers/`, `templates/`, `files/`, `meta/` y `README.md`. Al terminar deberías poder extraer un role desde un playbook existente, encadenar roles con dependencias en `meta/main.yml`, y decidir con criterio entre `import_role` (eager) e `include_role` (lazy).

## Alcance

Este módulo cubre:

- Estructura canónica que produce `ansible-galaxy role init` y el rol de cada carpeta.
- **`defaults/` vs `vars/`**: por qué `defaults/main.yml` es el más bajo en precedence (sobreescribible por el consumidor) y `vars/main.yml` el más alto dentro del role (configuración interna).
- **Dependencies** entre roles en `meta/main.yml`: cuándo son útiles, por qué muchas orgs las evitan (acoplamiento oculto) y cuándo preferir composición explícita.
- **`import_role` (eager, en tiempo de parse) vs `include_role` (lazy, en tiempo de ejecución)**: implicaciones para `tags`, `when`, `loop` y errores.
- Roles por responsabilidad (anti-pattern: role monolítico `setup-everything`): principio de "una responsabilidad clara".
- Documentación del role como contrato: variables esperadas, defaults, OS soportados, ejemplos de uso.
- Publicación local (ruta `roles/` del repo), `ansible.cfg` con `roles_path`, y referencia a Galaxy / repos privados (sin publicar aquí).

Lo que **no** cubre:

- Collections como unidad moderna de distribución (empaquetar varios roles + modules + plugins) → `ans-05`.
- Testing automatizado con **Molecule** y `ansible-lint` → `ans-08`.
- Vault y secretos → `ans-06`.

Este módulo es **mayoritariamente local**: todo corre contra `localhost` con `connection: local`. No se requiere infra remota.

## Materiales

- **`theory/lesson.md`** — lección profunda: estructura de un role, precedence local, dependencies, `import` vs `include`, documentación como contrato.
- **`examples/`** — ejemplos de lectura:
  - `01-role-init-skeleton/` — qué genera `ansible-galaxy role init` y qué significa cada carpeta.
  - `02-role-nginx/` — un role real `nginx` con `defaults`, `tasks`, `handlers`, `templates`, `meta`.
  - `03-import-vs-include-role/` — mismo escenario con las dos formas, diferencias observables en tags y errores.
- **`activities/`**:
  - `01-extract-role-from-playbook/` (guided-lab) — refactorizar un playbook monolítico a un role `webserver` reutilizable.
  - `02-role-dependency-chain/` (independent) — construir tres roles encadenados (`common` → `webserver` → `fastapi-app`) y decidir dependencies vs composición.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar `defaults` vs `vars`; `import_role` vs `include_role`; por qué un role bien diseñado se usa sin modificar en otra org. |
| Operativa | Generar un role con `ansible-galaxy role init`, moverle tasks/handlers/templates desde un playbook, y correrlo con `ansible-playbook` contra `localhost`. |
| Arquitectónica | Criticar un role "mega" y proponer descomposición por responsabilidad; decidir dependencies en `meta/main.yml` vs composición en el playbook. |

## Criterios de evaluación

- Dado un role existente, identificar qué variables son `defaults`, cuáles `vars` y por qué.
- Diseñar un README de role que sirva de contrato (variables, OS soportados, ejemplo).
- Entregar un playbook refactorizado a role que pase validación estructural + `--syntax-check`.
- Encadenar 3 roles con `meta/main.yml` **o** justificar por escrito por qué no usar dependencies.

## Entregables

- Role `webserver` extraído de un playbook monolítico, con `defaults/`, `tasks/`, `handlers/`, `templates/`, `meta/` y README (actividad 01).
- Chain de 3 roles (`common`, `webserver`, `fastapi-app`) con `meta/main.yml` que declare dependencies o site.yml que las componga, documentando la decisión en `README-INTENT.md` (actividad 02).

## Costos

**Ninguno.** Todo corre localmente contra `localhost` con `connection: local`. Si no tienes `ansible-core` instalado, los validadores reportan el fallo de dependencia y saltan los pasos de ejecución; la validación estructural de archivos y YAML sí corre.

## Siguiente módulo

→ `ans-05-collections-galaxy-and-automation-hub` — empaquetar roles + modules + plugins en collections, lockfiles, publicación.
