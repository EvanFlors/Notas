# ans-08 — Testing con Molecule, lint y CI

## Identificación

- **ID:** `ans-08-testing-molecule-lint-and-ci`
- **Curso:** `ansible`
- **Nivel:** avanzado (advanced)
- **Duración estimada:** 4 h
- **Prerrequisitos:** `ans-04-roles-structure-and-reuse` (saber escribir y descomponer roles).

## Objetivo

Probar roles y playbooks **como se prueba código**: con un lint estricto, un ciclo de tests reproducibles en contenedores efímeros y una integración continua que ejecute una matriz de distros + versiones de `ansible-core`. Al terminar debes poder añadir Molecule a un role existente, escribir un *verifier* con Ansible asserts o Testinfra, y conectar el role a un pipeline de GitHub Actions que falle si rompe la idempotencia o si introduce antipatterns.

## Alcance

Este módulo cubre:

- **`ansible-lint`**: reglas estándar, perfiles (`min`, `basic`, `safety`, `shared`, `production`), configuración `.ansible-lint`, exclusiones responsables.
- **`yamllint`**: estilo YAML (indentación, line-length, truthy), por qué suele acompañar a `ansible-lint`.
- **Molecule**:
  - Drivers vigentes (**Docker** como default práctico, **Podman** como alternativa rootless; Vagrant y EC2 relegados a casos puntuales).
  - **Scenarios**: `default/` y adicionales por distro.
  - El ciclo `molecule test` → `destroy → create → prepare → converge → idempotence → verify → destroy`.
  - **Idempotence check** nativo: la segunda `converge` debe reportar `0 changed`.
  - **Verifier** con **Ansible asserts** (rápido, en el mismo lenguaje) o **Testinfra** (pytest-style, para infra que ya hace mocking fino).
- **CI con GitHub Actions**:
  - Matriz de **distros** (`ubuntu-22.04`, `debian-12`, `rockylinux-9`) y de versiones de `ansible-core`.
  - Caché de collections (`~/.ansible/collections`) y de Pip.
  - Publicación del role a Galaxy desde CI cuando se tagga `vX.Y.Z`.

Lo que **no** cubre (se verá después):

- Imágenes AMI construidas con Packer + Ansible → `ans-09`.
- Operación de AWX/AAP y Event-Driven Ansible → `ans-09`, `ans-10`.
- Contrato de uso de Ansible en la plataforma (cuándo sí, cuándo no) → `ans-10`.

Este módulo es **mayoritariamente práctico**. Requiere **Docker** disponible localmente para correr el ciclo completo de Molecule. Si no tienes Docker, los validadores comprueban igualmente la **estructura** del scenario y la configuración, pero el ciclo `molecule test` se omite (el validador avisa).

## Materiales

- **`theory/lesson.md`** — lección profunda en 9 secciones.
- **`examples/`** — ejemplos demostrativos:
  - `01-molecule-scenario-default/` — scenario `default/` mínimo pero completo para un role trivial, con driver Docker.
  - `02-testinfra-verifier/` — mismo role, pero el verifier es Testinfra (pytest) en vez de asserts.
  - `03-gha-matrix-role-ci/` — workflow de GitHub Actions con matriz de distros + `ansible-core` + publicación on tag.
- **`activities/`**:
  - `01-add-molecule-to-your-role/` — **guided-lab**: añadir Molecule (scenario `default`), `ansible-lint` y `yamllint` a un role dado y pasar el ciclo completo.
  - `02-ci-publish-on-tag/` — **independent**: diseñar un workflow de GH Actions (matriz + publicación en Galaxy on tag) y pasarlo por un validador estructural.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar las 7 fases del ciclo `molecule test`; qué significa que un role sea idempotente desde la óptica del test; diferencia entre lint, test de convergencia y test de idempotencia. |
| Operativa | Escribir un scenario `default/` con Docker; configurar `ansible-lint` con reglas razonables; añadir un verifier con asserts; interpretar un fallo de `idempotence`. |
| Arquitectónica | Diseñar la matriz CI de un role que soporta 3 distros + 2 versiones de `ansible-core`; cachear dependencias; publicar el role a Galaxy solo cuando el tag coincide con SemVer. |

## Criterios de evaluación

- Dado un role sin tests, añades `molecule/default/` con `molecule.yml`, `converge.yml`, `verify.yml` y el validador estructural pasa.
- Dado un workflow de GH Actions, identificas si la matriz es razonable y si el gate de publicación está bien condicionado al tag.
- Explicas por qué un role que pasa `converge` pero falla `idempotence` **no** está listo para producción.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- Role del laboratorio con `molecule/default/`, `.ansible-lint`, `.yamllint` y `requirements.txt` listos (sale de la actividad `01`).
- Workflow `.github/workflows/role-ci.yml` con matriz + publicación on tag (sale de la actividad `02`).

## Costos

**Ninguno.** Todo se corre en local con Docker. La publicación a Galaxy desde CI usa el `GALAXY_API_KEY` del repositorio (si decides activarla fuera del curso); en el laboratorio **no** se publica nada real.

## Siguiente módulo

→ `ans-09-hybrid-with-terraform-packer-and-awx-aap` — Packer + Ansible → AMI inmutable, Terraform usa la AMI, Event-Driven Ansible y AWX/AAP.
