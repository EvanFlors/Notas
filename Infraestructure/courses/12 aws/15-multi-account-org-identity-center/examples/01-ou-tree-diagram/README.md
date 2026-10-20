# Ejemplo 01 — Árbol OU anotado

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria la **forma típica** de una organización pequeña/mediana y qué va en cada OU.

## 1. El árbol

```
Root (nodo lógico)
│
├── Security OU                       [SCPs: deny-disable-logging, deny-leave-org]
│   ├── 111111111111  log-archive     ← CloudTrail/Config logs centralizados
│   └── 222222222222  audit           ← GuardDuty, SecurityHub, consumer de logs
│
├── Workloads OU                      [SCPs: deny-regions, deny-leave-org]
│   ├── Workloads/Dev                 [SCPs extra: budget-cap, deny-prod-instance-sizes]
│   │   ├── 333333333333  app-A-dev
│   │   └── 444444444444  app-B-dev
│   ├── Workloads/Stg
│   │   ├── 555555555555  app-A-stg
│   │   └── 666666666666  app-B-stg
│   └── Workloads/Prod                [SCPs extra: deny-no-mfa-destructive, deny-public-s3]
│       ├── 777777777777  app-A-prod
│       └── 888888888888  app-B-prod
│
├── Sandbox OU                        [SCPs: deny-regions, deny-expensive-instances, budget-hard-cap]
│   └── 999999999999  sandbox-shared
│
├── Suspended OU                      [SCP: deny-all]
│   └── (cuentas en proceso de cierre)
│
└── Management (fuera de cualquier OU operativa)
    └── 000000000000  management-payer    ← NO hospeda workloads
                                          ← las SCPs NO le aplican
```

> **Nota didáctica**: los IDs de cuenta mostrados (`111111111111`, etc.) son **placeholders ficticios** usados por AWS en documentación oficial. **No** corresponden a ninguna cuenta real. En producción, los IDs son dígitos aleatorios de 12 cifras.

## 2. Lectura clave

1. **Security OU arriba y aparte.** Las cuentas `log-archive` y `audit` reciben una SCP que impide **a cualquiera** (incluido el admin) borrar logs o salir de la org. Blindaje de la auditoría.
2. **Workloads separa dev/stg/prod en OUs distintas.** Esto permite SCPs y Permission Sets distintos por entorno sin tocar nada por cuenta.
3. **Sandbox tiene su propio contenedor** con guardrails de costo y de recursos caros. Un sandbox que arranca un `p4d.24xlarge` 24 h cuesta más de 700 USD.
4. **Suspended OU** con `Deny *` protege cuentas en limbo (AWS tarda 90 días en cerrar una cuenta definitivamente; durante ese tiempo, mejor que esté muerta).
5. **Management fuera del árbol operativo.** Lo representa el diagrama con una ramificación aparte. Operativamente, cualquier recurso allí es un **riesgo**.

## 3. Qué va en cada cuenta de Security

| Cuenta | Qué hospeda | Quién la toca |
|--------|-------------|---------------|
| `log-archive` | Buckets S3 (`org-cloudtrail-logs-<orgid>`, `org-config-logs-<orgid>`), con *object lock* / *replication*. | **Nadie** operativamente. Solo IdC con `ReadOnlyAccess` para auditores. Write solo desde el servicio CloudTrail. |
| `audit` | GuardDuty (delegated administrator org-wide), SecurityHub, consola para analistas. | Equipo de seguridad con `SecurityAuditor` permission set. |

## 4. Qué va en cada cuenta de Workloads (ejemplo app-A-prod)

| Recurso | Patrón |
|---------|--------|
| VPC `app-A-prod-vpc` | /20 en 3 AZs, subnets privadas + públicas. |
| ECS/EKS/Lambda | La workload propiamente dicha. |
| RDS/DynamoDB | Datos de prod de la app A. |
| S3 bucket | Con policies que exigen cifrado y TLS. |
| IAM roles | Para las apps (`ecs-task-role`, `lambda-exec-role`), más el `AWSReservedSSO_*` materializado desde IdC. |

## 5. SCPs por OU (resumen)

| OU | SCPs atadas | Efecto neto |
|----|-------------|-------------|
| Root | (ninguna propia; sirve de ancla) | `FullAWSAccess` por defecto. |
| Security | `deny-leave-organization`, `deny-disable-logging` | Nadie puede sacar la cuenta de la org ni borrar la auditoría. |
| Workloads | `deny-leave-organization`, `deny-regions` (whitelist `eu-west-1`, `eu-central-1`) | Workloads solo en Europa. |
| Workloads/Prod | SCPs anteriores **+** `require-mfa-destructive`, `deny-public-s3-buckets` | Prod exige MFA para destrucciones; no se permiten buckets públicos. |
| Sandbox | `deny-leave-organization`, `deny-regions`, `deny-expensive-instance-types` | Sandbox barato y limitado. |
| Suspended | `deny-all` | Cuenta congelada hasta cierre. |

## 6. Preguntas de autocomprobación

1. ¿Por qué una SCP en el nivel `Workloads` también aplica a `Workloads/Prod`?
2. Si borrases la OU `Security` por accidente, ¿qué pasaría con las cuentas `log-archive` y `audit`?
3. ¿Por qué el management account aparece "fuera" en el diagrama y no bajo una OU?
4. Un developer dice: "necesito desplegar en `us-east-1` para probar un servicio nuevo". La SCP de Workloads lo deniega. ¿Qué opciones hay sin romper el baseline?
5. En Sandbox, un developer intenta lanzar un `p5.48xlarge`. La SCP lo deniega. ¿Dónde está escrita esa denegación y cómo la editarías para añadir un tipo nuevo a la whitelist?

Las respuestas se trabajan en la actividad `01-design-ou-structure-and-adr`.
