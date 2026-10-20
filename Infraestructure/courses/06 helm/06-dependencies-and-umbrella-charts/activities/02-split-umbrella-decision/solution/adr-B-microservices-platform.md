# ADR B — Charts separados en el monorepo de microservicios

## Status
Accepted

## Context
Operamos 40 microservicios en un cluster compartido. Un equipo de plataforma es dueño de ingress-nginx, cert-manager, Prometheus y la base de datos central (Postgres gestionado en RDS). Los equipos de producto despliegan sus propios servicios con cadencia diaria usando Argo CD; los upgrades de la plataforma los coordina SRE en ventanas separadas. El ownership operacional está claramente dividido entre varios equipos; cada componente se versiona por su cuenta y las ventanas de mantenimiento difieren por orden de magnitud (minutos para una app, horas para la plataforma).

## Decision
Mantenemos **charts separados** por servicio. Cada microservicio es un `Application` de Argo CD independiente con su propio chart. Los componentes de plataforma viven en charts upstream (ingress-nginx, cert-manager, kube-prometheus-stack) consumidos directamente, cada uno como un `Application` separado. La DB central no se gestiona con Helm porque es un servicio gestionado del cloud: vive en Terraform.

## Consequences
Positivas:
- **Ownership alineado**: cada equipo opera sus charts y asume sus upgrades. No hay un umbrella que un equipo tenga que "autorizar" para mover una pieza propia.
- **Blast radius acotado**: un rollback de un microservicio no toca a los demás ni a la plataforma. Un fallo de upgrade de ingress-nginx no bloquea despliegues de producto.
- **Cadencia independiente**: los equipos liberan a su ritmo; SRE orquesta ventanas de plataforma sin coordinarse con 40 PRs de producto.

Negativas / riesgos aceptados:
- **Más Applications que mantener en Argo CD**: lo mitigamos con *ApplicationSets* y una convención de monorepo.
- **Sin "instalación atómica"**: nadie necesita una; dev local usa un umbrella separado (ver Escenario C si aplica) que no se publica a prod.

## Alternatives considered
- **Umbrella de plataforma + umbrella de apps**: acopla lifecycles entre equipos y rompe el modelo de Argo CD por `Application`. Rechazado por acoplamiento innecesario.
- **Un umbrella por equipo**: viable pero añade un nivel de indirección que no aporta en un flujo GitOps donde cada app ya está versionada; introduce ambigüedad sobre quién posee el umbrella.
