# Ejemplo 03 — Patrón DR Pilot Light paso a paso

> Lectura y análisis. Sin ejecución. Los costes son **relativos**, no cifras reales en dólares.

## 1. Qué es Pilot Light

En **pilot-light** se mantiene en la región secundaria:

- Las **bases de datos replicadas** continuamente (RDS/Aurora cross-region read replica, DynamoDB global tables, S3 cross-region replication).
- La **infraestructura de red y seguridad** aprovisionada (VPC, subnets, SGs, KMS, Route 53 health checks) y lista.
- **Las imágenes/artefactos** desplegables (AMIs, imágenes ECR, código Lambda) replicados.
- **Compute apagado** (ASGs a 0, servicios ECS a 0, Lambda sin tráfico).

En caso de desastre regional, el *runbook* **enciende el compute** (escalar ASG, levantar servicios, cambiar DNS). RTO típico: **10–60 min**, dominado por el tiempo de arrancar servicios y warm-up de caches.

## 2. Diagrama

```
    Región primaria (us-east-1)                 Región secundaria (us-west-2)
    ─────────────────────────────                ─────────────────────────────
    ALB ──► ECS/EKS/ASG (RUN)  ──► RDS primary ──► cross-region replica ──► RDS replica
                      │                                                     │
                      └──► S3 bucket  ──► CRR  ──────────────────────────► S3 bucket
                                                                            │
    Route 53 (health check)                                                 │
         │                                                                  │
         └── primary record  ─────┐                      ┌── secondary ─────┘
                                   ▼ (failover routing)  ▼
                                   DNS failover a secundaria
    ECR us-east-1 ─────────► ECR replicated ─────────► ECR us-west-2 (imagen lista)

    En estado normal:                            En failover:
    ─────────────────                            ─────────────
    ECS secundario: 0 tasks                      ECS secundario: scale a N tasks
    ASG secundario: desired=0                    ASG secundario: desired=X
    Costo compute secundario: ~0                 Costo compute secundario: =primario
```

## 3. RPO y RTO

| Dimensión | Pilot Light típico |
|-----------|--------------------|
| **RPO (data loss admisible)** | Segundos a minutos — determinado por la **replicación** de RDS/Aurora/DynamoDB. Replicación asíncrona ⇒ hay un pequeño lag. |
| **RTO (tiempo hasta recuperar)** | 10–60 min — levantar compute + DNS failover + warm-up. |

Si el negocio exige **RTO < 5 min**, pilot-light **no basta** y hay que ir a **warm standby** (compute corriendo con capacidad reducida) o **active-active**.

## 4. Factura relativa (vs baseline región única)

```
Baseline (solo primaria)             : 1.00×
Pilot light (secundaria compute off) : ~1.3–1.6×
  ├─ RDS replica                     : ~0.6× del coste del primario (misma clase)
  ├─ S3 CRR (storage + transfer)     : variable; suele 0.05–0.15×
  ├─ ECR replication                 : marginal
  ├─ Network (VPC, TGW, NAT secund.) : 0.05–0.15×
  └─ Compute secundario (idle)       : ~0
Warm standby (compute reducido on)   : ~2.0–2.5×
Active-active                        : ~2.5–4.0×
```

**Lectura clave:** la base de datos replicada es el componente que domina el delta de factura entre single-region y pilot-light.

## 5. Runbook de failover (resumen)

1. **Decisión humana** (`sev-1` confirmado, región primaria caída según AWS Service Health Dashboard o métricas externas).
2. **Promover** el read replica RDS en la secundaria a primary (o apuntar la app al cluster Aurora secundario si usas Aurora Global).
3. **Escalar** ASGs/ECS en la secundaria al tamaño objetivo (mínimo el 70 % del primario para absorber tráfico).
4. **Cambiar Route 53** al registro secundario (health check en primario ya habría disparado el failover automático; verificar).
5. **Warm-up** de caches aplicativas (CloudFront, ElastiCache, in-memory).
6. **Comunicar**: status page externa, canal interno `#incidents`.
7. **Monitorear SLOs** del workload en la secundaria y confirmar.

## 6. Qué se olvida (siempre)

- **Secretos**: ¿están replicados a Secrets Manager en la secundaria? KMS keys multi-región bien configuradas?
- **Cuentas IAM / SSO**: los roles asumidos por los servicios tienen que existir en la secundaria.
- **Observabilidad**: dashboards, alertas, CloudWatch log groups específicos de la secundaria. Si solo tienes el panel apuntado a primaria, estás ciego durante el failover.
- **Terraform state**: si el state solo vive en S3 de la primaria, no puedes operar en la secundaria. Replicar también el bucket de state.
- **CI/CD**: ¿puedes deployar hotfix a la secundaria? ¿Pipelines apuntan a `us-east-1` por defecto?
- **DNS TTLs**: TTL alto en Route 53 significa que el cambio tarda en propagar. Bajar TTL a 60 s para el record afectado como preparación.

## 7. Test obligatorio

Un pilot-light **no probado = backup/restore disfrazado con factura más alta**. El test mínimo:

- Trimestral: **DNS failover y vuelta** (sin tráfico real).
- Semestral: **game day** completo — forzar el failover, correr tráfico sintético, medir RTO real.
- Anual: **región primaria completa fuera** (simulación coordinada con negocio).

## 8. Cuándo pilot-light **no** es la respuesta

- Workloads con **RTO < 5 min** → warm standby.
- Workloads **batch** donde la ventana de 24 h es aceptable → backup+restore.
- Workloads **stateless, baratos** donde incluso active-active cuesta poco → active-active y simplifica.
- Workloads sin **replicación cross-region soportada** por el servicio → otro patrón o cambio arquitectónico.

## 9. Preguntas de autocomprobación

1. ¿Por qué el RPO depende sobre todo del motor de base de datos y no del compute?
2. Si subes el tamaño del RDS primario, ¿qué pasa con el coste pilot-light?
3. ¿Qué prueba realmente un game day que no prueba un ejercicio de tabletop?
4. Dado un workload crítico 24×7 con RTO 5 min, ¿cuál es la justificación de ir warm standby en vez de active-active (que parece "mejor")?

Respuestas abiertas; se trabajan en la actividad `03-well-architected-review-and-dr-plan/`.
