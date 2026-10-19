# aws-06 — IAM avanzado: SCPs, boundaries, cross-account y OIDC

## Identificación

- **ID:** `aws-06-iam-advanced`
- **Curso:** `aws`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `aws-02` (IAM fundamentos). Haber escrito y aplicado al menos una identity policy y una resource policy.

## Objetivo

Aplicar IAM **a escala**: ya no estamos escribiendo "una política para un usuario", sino **guardrails de organización** (SCPs), **techos de permisos** para delegación (permission boundaries), **confianza entre cuentas** sin credenciales de larga vida y **confianza desde CI/CD externo** (GitHub Actions) vía **OIDC**.

Al terminar deberías poder:

- Diseñar un **baseline SCP** para una organización (deny regiones no permitidas, deny apagar CloudTrail, exigir MFA para acciones destructivas, forzar tags).
- Decidir cuándo **permission boundary** es la respuesta correcta (patrón "developer-self-service con techo") y cuándo no.
- Escribir una **trust policy cross-account** correcta, con las condition keys que evitan el *confused deputy* (`aws:PrincipalOrgID`, `aws:SourceAccount`, `sts:ExternalId`).
- Reconocer el **flujo OIDC** entre GitHub Actions y un rol IAM, y leer un `terraform plan` que lo materializa sin introducir secretos en el repo.
- Reproducir mentalmente la **lógica de evaluación completa** (SCP → resource-based → identity → boundary → session) y saber por qué un `Deny` arriba no se "compensa" con un `Allow` abajo.

## Alcance

Este módulo cubre:

- **Service Control Policies (SCPs)** — qué son, dónde se aplican (OU, cuenta), por qué son *techo* y no *grant*, patrones canónicos (deny-region, deny-leave-org, require-mfa, deny-root).
- **Permission Boundaries** — segundo techo, esta vez sobre un principal (user/role) concreto. Patrón "delegación segura": el admin de cuenta deja que un developer cree roles, pero ninguno de esos roles podrá superar el boundary.
- **Session policies** — tercer techo, efímero, pasado en `AssumeRole`.
- **Cross-account trust** — rol en cuenta B con `AssumeRolePolicyDocument` que confía en principal de cuenta A. Rol principal mínimo + condition keys defensivas.
- **OIDC trust para GitHub Actions** — federar sin IAM User, sin claves largas; condition keys `token.actions.githubusercontent.com:sub` y `:aud`.
- **Lógica de evaluación** cuando intervienen SCP + resource-based + identity + boundary + session.
- **Validación estructural** de policies JSON (sin aplicarlas en AWS): `Version`, `Statement[*].Effect`, `Action`, `Resource`/`Principal`, condition keys bien formadas.

Lo que **no** cubre (se verá después):

- Access Analyzer *external access* y *unused access* (aparece como mención; herramienta real → módulo de operación IAM).
- Generación automática de política desde CloudTrail (técnica mencionada; actividad práctica → `aws-14`).
- `policy_sentry` y `iam-policy-json-to-terraform` — **se mencionan como opcionales y se saltan**: añaden dependencias Python/Node que no son necesarias para aprender la lógica. Si quieres probarlos tú, en `resources/links.md` hay los repos.
- Firma de requests, SigV4, STS internals (fuera de scope IAM pedagógico).

## Materiales

- **`theory/lesson.md`** — lección con la lógica de evaluación de IAM, SCPs, boundaries, cross-account y OIDC.
- **`examples/`** — cuatro ejemplos **para leer y analizar**, no para aplicar en una cuenta real:
  - `01-scp-deny-regions/` — SCP que deja fuera regiones no autorizadas excepto servicios globales.
  - `02-permission-boundary-for-developers/` — boundary que permite al developer crear roles de aplicación pero no escalar.
  - `03-cross-account-s3-trust/` — rol en cuenta B que confía en cuenta A para leer un bucket, con `aws:PrincipalOrgID` + `sts:ExternalId`.
  - `04-oidc-github-actions-trust-terraform/` — walkthrough + `terraform plan` que crea el rol OIDC. **No se aplica** en AWS.
- **`activities/`** — dos actividades independientes:
  - `01-write-scp-baseline/` — redactar 3 SCPs (deny regiones, deny apagar CloudTrail, require MFA para destructivas) y validarlas **estructuralmente** con `jq`.
  - `02-cross-account-and-boundary/` — escribir boundary para developers + trust policy cross-account bien defendida.
- **`resources/links.md`** — docs oficiales AWS y repos opcionales (`policy_sentry`, `iam-policy-json-to-terraform`).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar los **cinco techos** (SCP, resource-based deny, identity, boundary, session) y en qué orden se evalúan. Explicar por qué un `Deny` arriba gana siempre. |
| Operativa | Escribir un SCP sin equivocarte con `NotAction` ni con el formato de `Condition`. Escribir un boundary que **no** permita que el delegado remueva su propio boundary. Escribir una trust policy sin dejar el agujero del *confused deputy*. |
| Arquitectónica | Decidir, dado un escenario (ej. "quiero que GitHub Actions despliegue en mi cuenta sin IAM User"), si la respuesta es OIDC federado + rol temporal o algo distinto. Diseñar un baseline SCP para una OU "sandbox" vs una OU "prod". |

## Criterios de evaluación

- Clasifica correctamente 3 escenarios donde interviene SCP + identity: cuál gana y por qué.
- Escribe un SCP y un boundary válidos estructuralmente (`jq` + validadores pasan).
- Explica, con palabras propias, por qué OIDC federado es preferible a un IAM User con access keys para CI/CD externo.
- Nombra las 3 condition keys defensivas de una trust policy cross-account y qué ataque previene cada una.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- `baseline-scp/` con 3 SCPs documentadas (sale de la actividad `01-write-scp-baseline`).
- `cross-account-and-boundary/` con una boundary + una trust policy, cada una con su decisión y las condition keys justificadas (sale de la actividad `02`).

## Coste real

**Cero.** No se aplica nada en AWS. Las políticas se validan localmente con `jq`. El walkthrough de OIDC incluye `terraform plan` (nunca `apply`). No se crean roles, no se asumen roles, no se generan claves.

## Siguiente módulo

→ `aws-07-networking-advanced` — ALB, NLB, Route 53, PrivateLink, Transit Gateway.
