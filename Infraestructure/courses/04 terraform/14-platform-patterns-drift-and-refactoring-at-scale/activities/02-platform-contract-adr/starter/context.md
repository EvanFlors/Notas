# Context — Acme Payments

Fintech, ~180 ingenieros, ~60 microservicios en AWS (eu-west-1, us-east-1).

## Estado actual

- **Terraform ≥ 1.5** usado en todos los equipos; no hay HCP Terraform.
- **State** en S3 por equipo + DynamoDB para locking.
- **Módulos**: ~3 copias semejantes-pero-distintas de "VPC", 2 de "ECS service", 1 "golden" semi-oficial de la antigua platform team (desatendido hace 8 meses).
- **CI/CD**: GitHub Actions con OIDC a AWS. Cada equipo tiene su propio workflow.
- **Policy-as-code**: `checkov` en algunos repos, no consistente. Nada de Rego/OPA.
- **Drift**: nadie lo mide. Un `plan` casual mostró drift en 20/60 stacks.
- **Gobernanza**: cualquier miembro del equipo puede mergear a `main` y disparar `apply` en prod.

## Problemas reportados en el último trimestre

1. Incidente P1: un dev bumpeó `aws` provider a mano en prod, un stack vecino rompió al próximo apply.
2. Equipo de Security tardó 6 semanas en auditar un cambio en IAM (buscó por grep en 60 repos).
3. Onboarding de un nuevo microservicio: 3 semanas de ticket (networking, cluster assign, DNS, monitors).
4. Un bucket S3 quedó público durante 4 días hasta que un scan lo detectó.

## Restricciones

- No hay presupuesto para HCP Terraform este año.
- Security exige: cifrado en reposo obligatorio, no S3 público, policy-as-code *demostrable* en PRs.
- Product exige: time-to-prod de nuevo microservicio < 2 días.
- Finance exige: visibilidad de tags `cost-center` y `owner`.

## Lo que te piden

Un ADR corto que fije el contrato de plataforma IaC: dónde vive el registry, cómo se versiona, qué expone el golden module, cómo se trata el drift, quién aprueba apply en prod, y qué métricas se van a medir. Debe ser defendible frente a trade-offs reales.
