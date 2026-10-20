# aws-02 — IAM Fundamentals

## Identificación

- **ID:** `aws-02-iam-fundamentals`
- **Curso:** `aws`
- **Nivel:** fundamentos
- **Duración estimada:** 5 h
- **Prerrequisitos:** `aws-01-model-regions-billing-and-free-tier` (cuenta con MFA, usuario admin, CLI configurada, presupuesto activo).

## Objetivo

Dominar los **primitivos de IAM** antes de tocar cualquier otro servicio de AWS. Al terminar deberías poder leer una política JSON y predecir el resultado de una llamada API; escribir una política de **mínimo privilegio** desde cero; distinguir un **trust policy** de una **permission policy**; y explicar por qué los **access keys de usuario** son casi siempre la peor opción frente a **roles + STS**, **IAM Identity Center** u **OIDC federado**.

## Alcance

Este módulo cubre:

- **Principals**: user, role, service, federated. Qué los distingue y cuándo elegir cada uno.
- **Policy JSON**: `Version`, `Statement`, `Effect`, `Action`, `Resource`, `Condition`, `Principal`, `NotAction` / `NotResource` / `NotPrincipal`.
- **Identity-based vs resource-based policies**: dónde se adjuntan, cómo se combinan.
- **Groups**: contenedor administrativo para humanos, no para servicios.
- **Managed vs inline policies**: cuándo reutilizar y cuándo pegar.
- **Variables de policy**: `${aws:username}`, `${aws:PrincipalTag/team}`.
- **Roles y STS**: `sts:AssumeRole`, `sts:AssumeRoleWithWebIdentity`; credenciales **temporales**; chain de roles.
- **Trust policy vs permission policy**: la primera dice *quién puede asumir el rol*; la segunda *qué puede hacer una vez asumido*. Son políticas distintas con sintaxis parecida.
- **Access keys** (long-lived) vs **IAM Identity Center / SSO** vs **OIDC federation** (GitHub Actions, GitLab, EKS/IRSA).
- **Lógica de evaluación**: default deny → explicit allow → **explicit deny gana siempre**. Cuando intervienen SCPs y resource policies, el álgebra se complica — se cubre completo en `aws-06-iam-advanced`; aquí basta con la versión para una sola cuenta.

Lo que **no** cubre (se verá después):

- SCPs, Permission Boundaries, session policies, cross-account avanzado → `aws-06-iam-advanced`.
- IAM database authentication → `aws-08`.
- Key policies de KMS (que confunden principal del rol vs principal del servicio) → `aws-09`.
- IRSA / EKS Pod Identity → `aws-11`.

Este módulo es **mayormente conceptual + ejercicios de JSON**. **No se provisiona infraestructura real** y **no cuesta nada**. Los ejemplos y actividades usan `aws iam simulate-principal-policy` cuando hay credenciales, pero el validador funciona *también sin credenciales* (modo doc-only).

## Materiales

- **`theory/lesson.md`** — lección profunda en 10 secciones.
- **`examples/`** — tres ejemplos documentales:
  - `01-least-privilege-s3-readonly/` — anatomía de una política S3 read-only bien escrita.
  - `02-role-assume-chain/` — un humano (SSO) → asume rol de operador → asume rol en otra cuenta. Qué hace STS en cada salto.
  - `03-oidc-trust-policy-for-github/` — trust policy que acepta un workflow de GitHub Actions sin access keys.
- **`activities/`** — dos actividades **independientes**:
  - `01-write-least-privilege-policy/` — reduce `"Action": "*"` a lo mínimo verificable con `simulate-principal-policy`.
  - `02-assume-role-cross-session/` — documenta y valida JSON una cadena de asumción de roles.
- **`resources/links.md`** — docs oficiales relevantes.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una frase por qué un rol es "una identidad asumible" y no "un usuario sin password". Distinguir trust policy de permission policy. Enunciar la lógica de evaluación completa para una sola cuenta. |
| Operativa | Escribir una política mínima S3 (list + get, un bucket, un prefijo). Escribir un trust policy que acepte un principal concreto. Pasar `aws iam simulate-principal-policy` para validar. |
| Arquitectónica | Elegir entre access key, SSO y OIDC federation para 3 escenarios distintos (CI, laptop del dev, EC2). Argumentar por qué 2 de los 3 nunca deberían ver un access key. |

## Criterios de evaluación

- Auditar una política `"Action": "*"` y proponer su versión mínima equivalente, documentando *por qué* cada permiso sobra o es necesario.
- Dado un escenario (GitHub Actions deploya a S3 en cuenta B), diseñar la cadena correcta: OIDC trust policy en cuenta B → rol asumible → política mínima de deploy.
- Explicar sin consultar notas por qué `AdministratorAccess` adjunta a un service role es casi siempre un bug de diseño.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- 3 políticas JSON documentadas (salen de las actividades y de los ejemplos revisados): la S3 least-privilege, el trust policy del rol asumible y la política de permisos del mismo rol.
- Notas con la cadena de asumción (SSO → operator role → cross-account role).

## Siguiente módulo

→ `aws-03-vpc-basics` — construir y entender una VPC multi-AZ segura, con separación pública/privada y VPC endpoints para evitar costos de NAT.
