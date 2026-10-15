# ADR-001: Upgrade de EKS 1.28 → 1.31 vía blue/green cluster (una ventana de corte)

## Status

Accepted

## Context

BillCo opera un único cluster EKS en `eu-west-1`, versión 1.28, que debe estar en 1.31 en menos de 8 semanas por EOL de EKS y por requisito del auditor SOC2. Los 30 microservicios son stateless y vienen gestionados por Argo CD desde Git, lo que hace barata la "reinstalación" en otro cluster. Postgres y Redis están **dentro** del cluster pero no son el sistema crítico (billing crítico vive en RDS externo); aun así, tienen datos útiles.

El SLO es 99.9% mensual (43 min/mes), con error budget de ~15 min durante la ventana. Hay 2 ventanas de mantenimiento (domingos 02:00–06:00 UTC) disponibles antes del plazo. La organización tolera ~20% de sobrecosto durante la operación. Nunca se ha restaurado un backup Velero en producción, por lo que el DR real no está verificado.

## Decision

Ejecutar un **blue/green cluster**: crear un cluster EKS 1.31 nuevo (`prod-eu-green`) en la misma región, instalar add-ons y policies, dejar que Argo CD lo reconcilie desde el repo, validar durante una ventana de observación, migrar DNS en la ventana de corte y mantener el `prod-eu-blue` 7 días para rollback antes de destruirlo.

## Consequences

- **Positiva 1**: rollback real y limpio en < 10 min (DNS flip) si rompe el green.
- **Positiva 2**: aprovechamos para subir add-ons (VPC CNI, EBS CSI) y migrar ingress-nginx → Gateway API — deuda arquitectónica largamente pospuesta.
- **Positiva 3**: el DR Velero queda **ejercitado** como efecto colateral (restore de Postgres/Redis al green = test real).
- **Negativa 1**: 2 clusters corriendo durante ~2 semanas → ~15–18% de sobrecosto, dentro del 20% tolerado pero cerca del techo.
- **Negativa 2**: complejidad de red (dos LBs, dos sets de certs, DNS externo apuntando a uno u otro). Riesgo de secreto / rate limit de Let's Encrypt durante la coexistencia.
- **Negativa 3**: Postgres y Redis in-cluster requieren plan de migración de datos (snapshot CSI + restore en green, o replica streaming). Es la parte frágil.

## Alternatives Considered

- **In-place en 3 saltos (1 por ventana, 3 ventanas totales)**: descartada porque solo hay 2 ventanas antes de EOL. Pediríamos una excepción al calendario, y el rollback real no existe en in-place (restore de etcd no está disponible en EKS). Riesgo asimétrico.
- **In-place en 2 saltos (1.28→1.29 ventana 1, 1.29→1.30 y 1.30→1.31 en ventana 2)**: posible pero el segundo salto doble en una sola ventana (4 h) es ajustado considerando upgrade de control plane + addons + 3 node groups con drain respetando PDBs. Baja probabilidad de completar sin desbordar el error budget.
- **Managed service migration a GKE/AKS**: descartado por costo organizacional (SAs, IRSA → WLI, etc.) y porque no resuelve el problema de versión; solo cambia el problema de proveedor.

## RPO and RTO

- **RPO objetivo durante la operación**: 15 min (Velero schedule cada 15 min durante la ventana green-up).
- **RTO objetivo en caso de rollback**: 10 min (TTL DNS 60 s + propagación LB + validación).
- **RTO objetivo si se requiere restaurar al green desde snapshots**: 60 min.
- Justificación: el SLO permite 43 min/mes; un rollback de 10 min deja 33 min de margen para errores subsiguientes dentro del mismo mes.

## Rollback Plan

1. **Detección**: alerta en Grafana — tasa de 5xx > 2× baseline o p99 > 2× baseline durante > 5 min.
2. **Decisión go/no-go** por el ingeniero de guardia (criterio documentado en el runbook `platform-ops`).
3. **DNS flip** (Route53 weighted → 100% blue, 0% green) vía Terraform `terraform -chdir=infra/dns apply -var weights=100-0`.
4. **Esperar propagación** (TTL 60 s + 2 min de margen).
5. **Confirmar en Grafana**: tasa de errores vuelve a baseline.
6. **Post-mortem** obligatorio en 48 h.
7. **Green queda intacto** para analizar la causa raíz; se destruye tras post-mortem.

## Success Metrics

- Tasa de errores 5xx post-corte ≤ tasa pre-corte + 10% durante las primeras 24 h.
- p99 latency de los 5 endpoints críticos ≤ 1.2× la p99 de la semana previa.
- 0 restarts anómalos (`kubectl get pods -A --field-selector=status.phase!=Running | grep -v Completed` vacío) en 24 h.
- 0 alertas PagerDuty P1/P2 nuevas atribuibles al upgrade durante 72 h.
- Documentación interna de "versión actual" actualizada a 1.31 en el wiki y en el repo de IaC.
- Backup Velero del blue retenido en bucket cross-region 30 días antes de destruir el cluster.
