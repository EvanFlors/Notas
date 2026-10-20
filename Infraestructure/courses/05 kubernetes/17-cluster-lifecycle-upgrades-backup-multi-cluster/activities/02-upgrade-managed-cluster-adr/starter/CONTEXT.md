# Perfil organizacional — escenario base

## Empresa

- **Nombre ficticio**: BillCo.
- **Dominio**: SaaS B2B de facturación recurrente para pymes europeas.
- **Tamaño**: 50 ingenieros total, 4 en el equipo de plataforma.
- **Clientes**: ~2 000 cuentas pagas.
- **Hora pico**: 09:00–18:00 UTC+1, lunes–viernes.

## Cluster actual

- **Proveedor**: AWS EKS en `eu-west-1`.
- **Versión actual**: `1.28`.
- **Versión objetivo**: `1.31`.
- **Node groups**: `system` (2× m5.large), `app` (6× m5.xlarge), `batch` (0–20× c5.2xlarge spot via Karpenter).
- **Addons gestionados**: VPC CNI, kube-proxy, CoreDNS, EBS CSI driver.

## Workloads

- 30 microservicios **stateless** (Deployments con HPA), lenguajes Go y Python, latencia media < 100 ms.
- 1 StatefulSet **Postgres** (3 réplicas, operador CNPG) para datos auxiliares (no para billing crítico — ese está en RDS externo).
- 1 StatefulSet **Redis** (3 réplicas, operador Redis OSS) para caché y rate-limiting.
- **Kafka** externo (AWS MSK managed), consumido desde el cluster.

## SLOs

- **SLO público**: 99.9% mensual → **43 min 49 s** de downtime tolerado por mes.
- Error budget para la ventana de upgrade: hasta 15 min siempre que el mes vaya "verde".

## Ventanas y plazos

- **Ventana de mantenimiento acordada**: domingos 02:00–06:00 UTC (4 h).
- **Ventanas disponibles antes de la EOL de 1.28 en EKS**: 2 (dentro de 8 semanas).
- **Factor regulatorio**: estar en versión soportada es requisito de un auditor externo contratado para SOC2.

## Operaciones

- **GitOps**: Argo CD gestiona el 100% de workloads desde `git@github.com:billco/platform` (monorepo platform + app-of-apps).
- **Observabilidad**: Prometheus Operator, Grafana, Loki, Tempo. Alertas en PagerDuty.
- **Secretos**: External Secrets Operator apuntando a AWS Secrets Manager.
- **Backups**: Velero con schedule diario, bucket cross-region (`eu-central-1`). **Nunca** se ha restaurado en producción.
- **Equipos de guardia**: rotación 24/7 de plataforma, 1 persona primary + 1 backup.

## Restricciones de costo

- Presupuesto adicional tolerable para la operación de upgrade: hasta **~20% del gasto mensual del cluster** durante la ventana. Permanente no se tolera incremento.

## Preguntas abiertas que el ADR debe resolver

1. ¿In-place o blue/green cluster?
2. ¿Un solo upgrade de 3 saltos en 2 ventanas, o 1 salto por ventana (3 ventanas, pero una se pediría como excepción)?
3. ¿Qué se hace con Postgres y Redis en el cluster?
4. ¿Cómo se prueba el DR *antes* del upgrade?
5. ¿Cuál es el plan de rollback si el salto 1.30 → 1.31 rompe algún operator?
