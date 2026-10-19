# Starter — aws-03-01-provision-vpc-via-tf-module

Esta actividad es **plan-only**: nunca ejecutes `terraform apply`. No se crea infraestructura en AWS.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el workspace:
   ```bash
   mkdir -p /tmp/aws-03-vpc-module
   cd /tmp/aws-03-vpc-module
   ```
3. Escribe `main.tf` siguiendo los requisitos del README (sección 5.2).
4. Escribe `DESIGN.md` con las secciones **CIDR**, **Diagrama**, **Decisiones**.
5. Valida offline:
   ```bash
   terraform init -backend=false
   terraform validate
   terraform plan -out=plan.out
   ```
6. Ejecuta el validador estructural:
   ```bash
   bash <ruta-repo>/courses/aws/03-vpc-basics/activities/01-provision-vpc-via-tf-module/tests/validate.sh /tmp/aws-03-vpc-module
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Qué NO hacer

- No ejecutes `terraform apply`.
- No pegues credenciales AWS reales en `main.tf` (usa el provider con `access_key = "mock"` como se indica en el README).
- No añadas NAT Gateway real: coméntalo en `DESIGN.md` si quieres, pero no lo despliegues.
