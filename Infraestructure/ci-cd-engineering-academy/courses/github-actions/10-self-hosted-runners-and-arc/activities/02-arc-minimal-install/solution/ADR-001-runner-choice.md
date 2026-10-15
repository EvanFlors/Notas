# ADR-001 — Elección de infraestructura de runners para Acme Logistics

Status: Accepted
Date: 2025-01-01
Author: Platform Team

## Contexto

Acme Logistics es un SaaS mediano con un **monorepo privado** (`acme/platform`)
que mueve ~1.800 workflow runs/mes. Los jobs más caros son builds de imagen de
contenedor (~12 min, 8 GB RAM) y suites de integración con Postgres+Redis en
sidecars. Los deploys deben acceder a RDS en una **VPC privada** sin IP pública.
El equipo plataforma (4 personas) ya opera un cluster EKS en producción para la
app, por lo que la operación de Kubernetes es carga marginal. Compliance SOC2
requiere evidencia de que nadie corre código en nuestra infraestructura sin
aprobación. La factura actual de Actions hosted es ~USD 1.100/mes y crece
linealmente con el equipo.

## Opciones evaluadas

1. **GitHub-hosted** estándar — cero operación, excelente seguridad por default,
   pero **no accede a la VPC** (necesitaríamos abrir RDS a internet detrás de un
   bastion, lo que debilita el perímetro), y el coste proyecta a > USD 2.5k/mes
   en 12 meses.
2. **Larger runners** hosted — resuelve el tamaño del build (RAM/CPU), misma
   seguridad y cero ops, pero **sigue sin acceso a la VPC** y encarece la
   factura aún más (~1.6x–3x por minuto).
3. **Self-hosted VMs** administradas — resuelve VPC y coste, pero añade
   operación significativa (patches, actualización del binario `actions-runner`,
   escalado manual, imágenes). Riesgo de runners **no efímeros** compartidos
   entre jobs (contaminación, lesson §2.3). SOC2: harder evidencia.
4. **ARC en Kubernetes** sobre el EKS existente — pods **efímeros** por job,
   `scale-from-zero`, acceso a la VPC natural (está en el mismo VPC que RDS),
   coste proporcional al uso. Operación: el equipo ya opera EKS; añadir ARC es
   un operator más, con upgrades vía Helm. Compliance: todos los jobs corren en
   nuestra cuenta, con logs ya centralizados en el stack existente.

## Decisión

Adoptamos **ARC en el EKS existente** con un `AutoscalingRunnerSet` por
sensibilidad (`default`, `deploy-prod`), autenticación por **GitHub App** con
permisos mínimos (`Administration: R/W` scope repo), `minRunners: 0`,
`maxRunners: 10`.

## Consecuencias

- **Operación**: +1 operator a mantener (upgrades trimestrales), +un chart por
  scale set. Documentar en el runbook del equipo plataforma. Imágenes de runner
  construidas internamente y pre-tiradas en los nodos vía DaemonSet para
  mitigar la latencia de cold start.
- **Coste estimado**: USD 300–500/mes (nodos EKS existentes absorben los pods;
  solo pagamos autoscaling marginal). Ahorro proyectado > USD 20k/año a 12
  meses frente a hosted standard, > USD 50k/año frente a larger.
- **Seguridad / compliance**: pods efímeros + runner group `deploy-prod`
  restringido a pipelines con environment `prod` + GitHub App con permisos
  mínimos. SOC2: evidencia por audit log de EKS + Actions. Regla dura
  cumplida: el repo es privado y los runners **no** están expuestos a workflows
  públicos.
- **Plan si crece 10x**: subir `maxRunners`, agregar node group dedicado con
  taints, considerar warm pool (`minRunners: 2-3`) si la latencia de cold
  start pasa a doler en p95.
- **Riesgo residual**: dependencia operativa de EKS; si EKS cae, el CI cae.
  Plan de contingencia: workflow fallback con `runs-on: ubuntu-latest`
  disponible para pipelines críticos (deploy).
