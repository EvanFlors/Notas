# ans-05 — Collections, Ansible Galaxy y Automation Hub

## Identificación

- **ID:** `ans-05-collections-galaxy-and-automation-hub`
- **Curso:** `ansible`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `ans-04` (roles) y por tanto toda la cadena `ans-01..04`.

## Objetivo

Entender la **collection** como unidad moderna de distribución de Ansible (desde 2.10), consumir collections externas con `requirements.yml` + lockfile, decidir con criterio qué collection comunitaria adoptar, y producir una collection propia instalable localmente que empaquete roles, modules y plugins bajo un namespace estable.

## Alcance

Cubre:

- **Historia breve**: por qué el core de Ansible se partió en `ansible-core` + collections; cómo convive con los **roles** del módulo anterior.
- **Formato `collections` en `requirements.yml`**: nombres `namespace.name`, versión, `source`, `type: git|galaxy|url|dir`.
- **Lockfile** (`ansible-galaxy collection list` + `--requirements-file` para instalar reproducible desde `ansible-core` 2.17/2.18). Equivalente conceptual a `package-lock.json`.
- **Instalación local**: `ansible-galaxy collection install -r requirements.yml -p ./collections` para aislarla del sistema.
- **Namespaces comunes**: `ansible.posix`, `community.general`, `community.aws`, `amazon.aws`, `kubernetes.core`.
- **Creación de collection propia**: `ansible-galaxy collection init org.name` → estructura (`galaxy.yml`, `plugins/`, `roles/`, `playbooks/`, `meta/runtime.yml`).
- **Publicación**: Galaxy público vs **Automation Hub** (Red Hat, firmadas y certificadas) vs registry interno privado (p. ej. Pulp).
- **Criterios de adopción** de una collection comunitaria (mantenimiento, releases, issues abiertos, cobertura de módulos, licencia, dependencia de SDKs upstream).

Lo que **no** cubre (se verá después):

- Testing con **Molecule** sobre una collection → `ans-08`.
- Rotación de secretos consumidos por módulos de la collection → `ans-06`.
- CI publicando la collection a Galaxy en cada tag → `ans-08`.

Este módulo es **mayoritariamente estructural + ADR + validación de YAML/JSON**. Los dos entregables son archivos: `requirements.yml` + `galaxy.yml` + README, y un ADR comparando dos collections candidatas. El único *tooling* es `bash`, `yq` o `python3`, un editor y — si hay red — `ansible-galaxy`.

## Materiales

- **`theory/lesson.md`** — lección profunda (10 secciones) sobre collections, Galaxy, Automation Hub y criterios de adopción.
- **`examples/`** — demostraciones (lectura y análisis, no obligatorias ejecutar):
  - `01-requirements-yml-with-collections/` — `requirements.yml` real con 3 collections pineadas + explicación campo a campo.
  - `02-create-and-publish-collection/` — esqueleto de `galaxy.yml` + layout tras `ansible-galaxy collection init` + comando de build/publish anotado.
  - `03-automation-hub-walkthrough/` — walkthrough **conceptual** de Red Hat Automation Hub (certified vs validated vs community), captura textual del flujo de token y comparación con Galaxy público.
- **`activities/`** — dos actividades:
  - `01-adopt-community-aws-collection/` (**guided-lab**) — produces `collections/requirements.yml`, `galaxy.yml` para una collection propia y un `README.md` con el intent; validador estructural.
  - `02-collection-eval-adr/` (**independent**) — ADR comparando dos collections candidatas (`community.aws` vs `amazon.aws`) con 6 criterios de adopción; sin red requerida.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `ansible-core` y las collections viajan separadas; diferencia entre role y collection; diferencia entre Galaxy público, Automation Hub y registry privado. |
| Operativa | Escribir un `requirements.yml` de collections pineado y reproducible; inicializar una collection propia con `galaxy.yml` válido; instalar collections aisladas en `./collections`. |
| Arquitectónica | Decidir qué collection comunitaria adoptar con criterios explícitos; justificar un fork propio versus aceptar la upstream; dibujar la cadena `requirements.yml → lockfile → collection path → playbook` para un repo real. |

## Criterios de evaluación

- Entrega los dos entregables con sus validadores estructurales en verde.
- Explica por qué fijar la versión de una collection es la vía de rollback cuando aparece un bug en un módulo (p. ej. `community.aws.s3_object`).
- Nombra al menos 3 criterios para aceptar o rechazar una collection comunitaria.
- Describe la diferencia entre `community.aws` (comunitaria) y `amazon.aws` (certificada por Red Hat / mantenida por AWS).
- Diferencia `galaxy.yml` (manifiesto de collection) de `requirements.yml` (lista de dependencias a instalar).

## Entregables

- **`collections/requirements.yml`** válido con 3 collections pineadas por versión, más una collection **propia** (`galaxy.yml`) inicializada bajo un namespace propio con `plugins/`, `roles/`, `playbooks/` vacíos pero presentes (sale de la actividad `01`).
- **ADR** `ADR-COLLECTION-ADOPTION.md` comparando `community.aws` vs `amazon.aws` para un escenario dado, con 6 criterios de adopción (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos YAML/Markdown. No se requiere cuenta en Red Hat ni cuenta AWS activa. Si estás **offline**, el paso `ansible-galaxy collection install -r` del lab se marca como **SKIP** y el resto del validador sigue pasando: estructura, YAML válido y campos obligatorios se verifican sin red.

## Siguiente módulo

→ `ans-06-vault-and-secrets-management` — manejo de secretos con `ansible-vault`, múltiples IDs y lookup contra Secrets Manager / Vault.
