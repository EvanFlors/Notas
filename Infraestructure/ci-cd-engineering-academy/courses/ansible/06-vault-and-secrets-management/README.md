# ans-06 — Vault y gestión de secretos en Ansible

## Identificación

- **ID:** `ans-06-vault-and-secrets-management`
- **Curso:** `ansible`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `ans-02` (playbooks), curso **devsecops** ≥ `sec-02`.

## Objetivo

Entender qué resuelve y qué **no** resuelve `ansible-vault`, usarlo correctamente para proteger variables sensibles en el repo, y saber **cuándo migrar** a un secret manager externo (AWS Secrets Manager, HashiCorp Vault) o a herramientas de encriptado declarativo (SOPS, External Secrets Operator en Kubernetes). Al terminar deberías poder encriptar/desencriptar archivos y strings con `ansible-vault`, operar con **múltiples vault IDs** (dev/prod separados) y defender por escrito por qué `ansible-vault` **no basta** a escala.

## Alcance

Este módulo cubre:

- `ansible-vault create|edit|encrypt|decrypt|view|rekey` sobre archivos completos.
- `ansible-vault encrypt_string` para encriptar **campos individuales** y pegarlos dentro de `group_vars/host_vars`.
- **Vault password sources**: archivo (`--vault-password-file`), script (`--vault-id key@script.sh`), múltiples IDs (`dev@...`, `prod@...`).
- `no_log: true` para evitar leaks en el output de `ansible-playbook`.
- Integración con **secret managers externos** vía lookup plugins: `aws_secret`, `hashi_vault`, `azure_keyvault_secret`, `gcp_secret_manager`.
- Comparación conceptual **ansible-vault vs SOPS vs External Secrets Operator vs secret manager nativo**.
- Limitaciones del vault: encriptación **simétrica**, rotación manual, el password es un secreto más que necesitas custodiar.

Lo que **no** cubre:

- Rotación automática de credenciales en RDS/Secrets Manager (lo ves en `aws-09`).
- Políticas IAM finas para que un rol de EC2 lea un `aws:secretsmanager:*` (lo ves en `aws-06`).
- GitOps con External Secrets Operator en Kubernetes (lo ves en el curso **kubernetes**).

Este módulo es **mayoritariamente práctico local**: `ansible-vault` corre offline, sin conexión a AWS. La comparación con secret managers es conceptual + un ADR.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos demostrativos y ejecutables localmente:
  - `01-vault-encrypt-string/` — encriptar un string suelto y pegarlo en `group_vars/`.
  - `02-multi-vault-id/` — flujo con dos vault IDs (`dev@`, `prod@`) y cómo Ansible resuelve cuál usar.
  - `03-sops-vs-external-secrets/` — tabla comparativa y walkthrough conceptual: `ansible-vault` vs **SOPS** (Mozilla) vs **External Secrets Operator** vs secret manager nativo.
- **`activities/`**:
  - `01-encrypt-sensitive-vars/` — **guided-lab** práctico con `ansible-vault encrypt/decrypt/view` sobre `group_vars/prod.yml` (secretos **fake** — nunca reales).
  - `02-migrate-vault-to-sm/` — **independent**: ADR justificando migración de `ansible-vault` a un secret manager externo + diseño del lookup.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `ansible-vault` es un bastión mínimo y no sustituye a un secret manager; qué resuelve SOPS que `ansible-vault` no; cuándo External Secrets Operator aplica (K8s) y cuándo no. |
| Operativa | Encriptar un archivo YAML completo y un string individual; operar con múltiples vault IDs; usar `no_log: true` en tasks sensibles. |
| Arquitectónica | Decidir **vault-en-repo vs lookup-desde-SM** para 3 escenarios distintos; diseñar la rotación de la vault password. |

## Criterios de evaluación

- Ejecutas `ansible-vault encrypt/decrypt/view` sin consultar `--help`.
- Lees un archivo con `$ANSIBLE_VAULT;1.1;AES256` arriba y sabes qué es.
- Justificas por qué no commiteas la password del vault junto al archivo encriptado.
- Entregas las dos actividades con sus validadores en verde.

## Entregables

- `group_vars/prod.yml` encriptado con `ansible-vault` y descifrable con la password proporcionada (actividad `01`).
- `ADR-SECRETS-MIGRATION.md` justificando el camino de migración (actividad `02`).

## Costos

**Ninguno.** `ansible-vault` corre localmente contra archivos. La discusión de secret managers es conceptual. **Nunca** se usan secretos reales en este módulo: todos los valores son del tipo `fake-password-not-real`.

## Siguiente módulo

→ `ans-07-idempotency-deep-and-advanced-patterns` — idempotencia profunda, `delegate_to`, `serial`, `block/rescue`, estrategias.
