# Ejercicio arquitectónico — Contrato Ansible bajo presión

## Contexto

Eres el **platform engineer** de una empresa con la siguiente stack vigente:

- Infraestructura cloud en AWS gestionada por **Terraform** (módulos propios, state en S3+DynamoDB, pipeline con OIDC).
- Workloads de aplicaciones en **EKS**, desplegadas con **Helm** + **Argo CD** (GitOps).
- Un parque residual de **40 VMs EC2 long-lived** heredadas, aún no migradas a K8s, con nginx + un servicio Python por systemd. Estas VMs se configuran con **Ansible** (roles propios en un repo `ansible-platform`).
- Un bastión bare-metal en un datacenter secundario (red interna, acceso vía VPN) que **no está en cloud**.
- Secretos: **AWS Secrets Manager** para apps en K8s; para las VMs legacy, actualmente conviven secretos en `ansible-vault` (clave compartida entre 4 personas vía 1Password).

## El pedido

Dos equipos levantan tickets el mismo día:

1. **Equipo `payments-platform`** quiere desplegar su **nueva app en EKS** usando **Ansible** porque "el equipo ya conoce Ansible mejor que Helm y así reusamos los roles de instalación de dependencias". Prototipo listo: un playbook que corre `kubectl apply` contra el cluster desde un runner de GHA.

2. **Equipo `security-ops`** pide **estandarizar `ansible-vault`** para todos los secretos de VMs y bastión, y además adoptarlo "a futuro" para los secretos de las apps K8s porque "centralizar la gestión de secretos en un solo tooling simplifica auditoría".

El CTO te pide una decisión por escrito **esta semana**.

## Lo que debes entregar

Un ADR (`architectural/adr-ansible-boundary.md`) de **400–800 palabras** con la estructura:

1. **Título y estado** (p. ej. `Accepted`, con fecha y revisor).
2. **Contexto**: qué entiendes del pedido y del estado actual.
3. **Decisión**: qué apruebas, qué rechazas, qué apruebas con condiciones. Debe cubrir ambos pedidos.
4. **Consecuencias**: positivas y negativas, con énfasis en los costos.
5. **Alternativas consideradas**: al menos dos por cada pedido, con el motivo del descarte.
6. **Boundary explícito**: una tabla o lista corta de "Ansible SÍ / Ansible NO" aplicable a toda la organización, que el ADR deja como regla.
7. **Plan de secretos**: cómo luce el camino hacia una solución única (lookup a Secrets Manager / Vault en tiempo de ejecución, workload identity del runner, rotación, `no_log`), y qué pasa con los `ansible-vault` existentes mientras tanto.
8. **Fecha de revisión**: cuándo revisitarás esta decisión y qué evidencia la cambiaría.

## Restricciones y criterios de evaluación

- Debes **tomar una posición**; "depende del equipo" sin criterio no aprueba.
- Debes citar al menos **un trade-off cuantificable o medible** (p. ej. tiempo de rollback, número de secretos a migrar, SLO de disponibilidad del secret manager).
- No se permite introducir herramientas nuevas que la organización aún no usa salvo que justifiques explícitamente adopción, costo y propiedad.
- Red flags que anulan el ADR: aprobar el deploy de la app K8s con Ansible sin plan de migración y sin fecha; promover `ansible-vault` como estrategia única para prod; dejar la clave del vault documentada en el propio ADR.

Ver rúbrica en `../EXAM.md § Ejercicio arquitectónico`.
