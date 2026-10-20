# tf-11 — Remote backends y locking

## Identificación

- **ID:** `tf-11-remote-backends-and-locking`
- **Curso:** `terraform`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `tf-05-state-basics`, `tf-08-environments-workspaces-vs-directories`.

## Objetivo

Operar el state de Terraform de forma **remota, cifrada y con locking** para trabajo en equipo. Al terminar deberías poder: diseñar un layout de backends por bounded context, hacer bootstrap de un backend S3 + DynamoDB (o equivalente), migrar un stack local a remoto con `-migrate-state`, y recuperar un lock colgado con criterio sin romper el state ni el apply en curso de otro ingeniero.

## Alcance

Este módulo cubre:

- Backends soportados nativamente: `s3` (+ DynamoDB para lock, o S3 native locking reciente), `gcs`, `azurerm`, `http` (GitLab/GitHub managed state), `remote`/`cloud` (HCP Terraform / Terraform Cloud), `kubernetes` (secret).
- Encriptación at-rest, versionado del bucket y políticas IAM mínimas.
- Split del state por **bounded context** para reducir blast radius.
- Mecánica del lock: cómo se toma, cómo se libera, qué pasa cuando `apply` muere a mitad.
- Recuperación con `terraform force-unlock` y los riesgos asociados.
- Rol de HCP Terraform / OpenTofu Cloud: no solo backend, también gestión de runs.

Lo que **no** cubre (se verá después):

- Pipeline CI/CD con OIDC a cloud y `plan` como artefacto → `tf-13`.
- Policy-as-code sobre el plan remoto → `tf-12`.

## Materiales

- **`theory/lesson.md`** — 12 secciones.
- **`examples/`**:
  - `01-s3-backend-with-dynamodb-lock/` — configuración mínima de un backend `s3` con bloqueo en DynamoDB, dual-mode (localstack | AWS real).
  - `02-split-state-by-context/` — layout de monorepo con un state por bounded context (network, platform, app-*).
- **`activities/`**:
  - `01-bootstrap-remote-backend/` (guided-lab, dual-mode local | live) — crear bucket + tabla, configurar backend, migrar state con `-migrate-state` y verificar.
  - `02-recover-stuck-lock/` (independent) — simular un lock colgado y recuperarlo con criterio.
- **`resources/links.md`** — documentación oficial y lecturas.

## Temas y subtemas

1. Backends: concepto y matriz
   - Local vs remoto; `terraform { backend "x" {} }`.
   - `s3`, `gcs`, `azurerm`, `http`, `remote` / `cloud`, `kubernetes`.
2. Mecánica del lock
   - Qué es un lock, qué información lleva, qué lo libera.
   - `s3` + DynamoDB (`LockID` como PK); S3 native locking (versiones recientes).
   - `terraform force-unlock <LOCK_ID>` y cuándo es correcto usarlo.
3. Protección del state en reposo
   - Encriptación del bucket (SSE-S3 / SSE-KMS).
   - Bucket versioning (recuperación ante corrupción).
   - Public access block + bucket policy restrictiva.
   - IAM mínimo para el principal que ejecuta Terraform.
4. Split por bounded context
   - Un bucket (o key) por ambiente, por context.
   - `terraform_remote_state` como contrato de lectura entre states.
   - Antipatrón del state monolítico.
5. HCP Terraform / OpenTofu Cloud
   - `cloud` block vs `remote` backend.
   - Gestión de runs, variables, workspaces y VCS integration.
   - Cuándo tiene sentido vs backend "a mano".

## Conceptos internos (fundamentos)

- Un backend es más que "dónde se guarda el `tfstate`": también define **cómo se adquiere el lock** y **quién puede leerlo/escribirlo**. Separar backends por ambiente separa también credenciales y permisos.
- Un state monolítico para 50 microservicios implica que **cualquier `plan` toca todo el grafo** (refresh de todos los recursos), el lock bloquea a todo el mundo, y un apply mal timado afecta el blast radius entero. Split por context es, antes que estético, una decisión de **disponibilidad**.
- El lock no es "mágico": en `s3` es una fila en DynamoDB con `LockID = <bucket>/<key>-md5`. Si el proceso muere antes de borrarla, queda colgada. `force-unlock` no revierte apply en curso: solo borra la fila. Si el otro proceso sigue vivo, obtienes dos apply en paralelo (corrupción).
- Terraform guarda **lo que lee del provider** en el state, incluyendo valores sensibles en claro. El cifrado en reposo del backend no es "lujo", es higiene mínima.
- `terraform init -migrate-state` es la vía ortodoxa: Terraform lee el state actual (local), llama al backend nuevo, hace un `PutObject` del state y verifica. Si el bucket no existe o IAM no permite escribir, aborta sin dejar el state local corrupto.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `remote` backend "a mano" (S3+DDB) y `cloud` (HCP). Explicar qué información lleva un lock y por qué `force-unlock` es peligroso. |
| Operativa | Bootstrap de bucket + tabla; migrar state de local a remoto con `-migrate-state`; recuperar un lock colgado sin romper otro apply. |
| Arquitectónica | Diseñar un layout de buckets/keys para una org con N ambientes y M bounded contexts; justificar el trade-off entre un state por microservicio vs un state por grupo. |

## Entregables

- Stack migrado de local a remoto con locking funcional. Evidencia: `terraform init -migrate-state` ejecutado, `tfstate` en el bucket, lock visible en DynamoDB durante un `apply` artificialmente lento.
- Documento (puede ser una sección del README personal) con **tu** estrategia de splitting de state para una organización con 50 microservicios: cuántos buckets, cuántas keys, qué criterio de agrupación, cómo entregas valor compartido entre states.
- Las dos `tests/validate.sh` de las actividades deben pasar (o `SKIP` graceful en entornos sin docker/aws).

## Criterios de evaluación

- Diseñar la estrategia de splitting del state para una org de 50 microservicios con justificación (criterio de agrupación, política de contratos entre states, política de rollback por context).
- Diagnosticar un lock colgado y decidir si usar `force-unlock` o esperar; defender la decisión por escrito.
- Enumerar los controles mínimos del bucket que aloja el state (encriptación, versionado, public access block, IAM, lifecycle) y justificar cada uno.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-s3-backend-with-dynamodb-lock/` en modo `local` (localstack).
3. Lee `examples/02-split-state-by-context/` y dibuja el grafo mental del layout.
4. Haz `activities/01-bootstrap-remote-backend/`.
5. Haz `activities/02-recover-stuck-lock/`.
6. Escribe tu ADR de splitting de state para 50 microservicios.

## Siguiente

→ `tf-12-testing-and-policy-as-code`: ahora que tu state es defendible, blindamos el **plan** con policy-as-code y tests.
