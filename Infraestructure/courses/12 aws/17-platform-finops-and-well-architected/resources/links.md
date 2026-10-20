# Recursos — aws-17

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso: AWS cambia pricing, nombres de servicios y features con frecuencia.

## Landing zone

- **AWS Organizations**: `https://docs.aws.amazon.com/organizations/latest/userguide/`
- **AWS Control Tower**: `https://docs.aws.amazon.com/controltower/latest/userguide/`
- **Landing Zone Accelerator on AWS**: `https://aws.amazon.com/solutions/implementations/landing-zone-accelerator-on-aws/`
- **Service Control Policies**: `https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html`
- **Transit Gateway**: `https://docs.aws.amazon.com/vpc/latest/tgw/`
- **Route 53 Resolver**: `https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html`

## FinOps

- **AWS Billing & Cost Management**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/`
- **Cost Explorer**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-what-is.html`
- **Cost Anomaly Detection**: `https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html`
- **Cost Allocation Tags**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html`
- **AWS Budgets**: `https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html`
- **Savings Plans**: `https://docs.aws.amazon.com/savingsplans/latest/userguide/`
- **Reserved Instances (EC2)**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html`
- **Spot Instances**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html`
- **Graviton**: `https://aws.amazon.com/ec2/graviton/`
- **Compute Optimizer**: `https://docs.aws.amazon.com/compute-optimizer/latest/ug/`

## FinOps Foundation (vendor-neutral)

- **FinOps Framework**: `https://www.finops.org/framework/`
- **FinOps Principles**: `https://www.finops.org/framework/principles/`
- **Unit economics (guía)**: `https://www.finops.org/wg/unit-economics/`

## DR y backup

- **AWS DR whitepaper (patrones)**: `https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html`
- **AWS Backup**: `https://docs.aws.amazon.com/aws-backup/latest/devguide/`
- **AWS Elastic Disaster Recovery**: `https://docs.aws.amazon.com/drs/latest/userguide/`
- **Resilience Hub**: `https://docs.aws.amazon.com/resilience-hub/latest/userguide/`

## Governance

- **AWS Config**: `https://docs.aws.amazon.com/config/latest/developerguide/`
- **Config Conformance Packs**: `https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html`
- **Security Hub**: `https://docs.aws.amazon.com/securityhub/latest/userguide/`
- **GuardDuty**: `https://docs.aws.amazon.com/guardduty/latest/ug/`

## Well-Architected Framework

- **WAF overview**: `https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html`
- **Operational Excellence pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/welcome.html`
- **Security pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html`
- **Reliability pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html`
- **Performance Efficiency pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html`
- **Cost Optimization pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html`
- **Sustainability pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/sustainability-pillar/welcome.html`
- **Well-Architected Tool**: `https://docs.aws.amazon.com/wellarchitected/latest/userguide/`

## ADR (formato)

- **Michael Nygard's ADR template**: `https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions`
- **adr.github.io** (varios formatos): `https://adr.github.io/`

## Checklist de verificación requerida en Fase 4

- Lista de **servicios cubiertos por Compute Savings Plan** vs EC2 Instance SP (Fargate y Lambda incluidos actualmente).
- Precios actuales de **NAT Gateway** y **Transit Gateway** por región (los números del lesson son órdenes de magnitud).
- Estado de **Resilience Hub** en tu región.
- Si **Prometheus OTLP ingest** afecta tu stack de observabilidad corporativo.
- Versiones vigentes de los **Conformance Packs** oficiales (CIS, PCI, HIPAA cambian).
