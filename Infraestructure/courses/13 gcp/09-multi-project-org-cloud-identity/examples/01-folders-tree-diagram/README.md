# Ejemplo 01 — Árbol Organization → Folders → Projects anotado

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria la forma típica de un tenant GCP y qué va en cada folder.

## 1. El árbol

```
Organization: ejemplo.com                           [Org Policies baseline aplicadas aquí]
│
├── Folder: Security                                [Org Policies extra: deny-sa-key, deny-external-ip]
│   ├── Project: logging-prod                       ← sinks de Cloud Logging centralizados a BigQuery/GCS
│   └── Project: security-audit                     ← Security Command Center, SIEM consumer
│
├── Folder: Shared                                  [Org Policies: restrictSharedVpcHostProjects]
│   ├── Project: shared-vpc-host                    ← VPC Shared host, firewall rules, DNS zone
│   ├── Project: artifact-registry-corp             ← Artifact Registry (docker, maven, python) corporativo
│   └── Project: tools-shared                       ← CI/CD runners, Terraform state bucket
│
├── Folder: Workloads
│   │
│   ├── Folder: Workloads/Prod                      [VPC-SC perimeter 'prod_data_perimeter' + require-os-login]
│   │   ├── Project: checkout-prod
│   │   └── Project: analytics-prod
│   │
│   ├── Folder: Workloads/Stg
│   │   ├── Project: checkout-stg
│   │   └── Project: analytics-stg
│   │
│   └── Folder: Workloads/Dev                       [Budget alerts agresivas: 50 USD/mes/project]
│       ├── Project: checkout-dev
│       └── Project: analytics-dev
│
├── Folder: Sandbox                                 [Budget hard cap 20 USD/mes, deny external IP]
│   └── Project: sandbox-shared                     ← experimentación personal, un project para toda la empresa
│
└── Project: org-admin                              ← fuera de folders operativos
                                                    ← hosts WIF pools, Terraform de bootstrap
                                                    ← NO hospeda workloads
```

> **Nota didáctica**: los nombres de project (`checkout-prod`, etc.) son placeholders. En producción se usa un **project ID** único globalmente, típicamente con prefijo de org: `acme-checkout-prod-7f3`. **Nunca** pegues un project ID real de un tenant ajeno; son identificadores públicos.

## 2. Lectura clave

1. **Security arriba y aparte.** Los projects `logging-prod` y `security-audit` reciben Org Policies más estrictas y bindings restrictivos: solo el equipo de seguridad escribe allí; el resto solo lee (y a veces ni eso).
2. **Shared tiene su propio folder** para separar red compartida, artifact registry y tooling de las cargas que los consumen. Facilita cambiar provider o versión sin tocar workloads.
3. **Workloads separa Prod/Stg/Dev en subfolders**, lo que permite:
   - Aplicar VPC-SC perimeter solo a Prod.
   - Aplicar budget alerts más agresivas en Dev.
   - Dar `roles/editor` a los developers en Dev y solo `roles/viewer` en Prod.
4. **Sandbox tiene su propio folder** con budget hard cap para que nadie arranque una VM `n2-standard-96` por error y le explote la factura.
5. **`org-admin` project fuera del árbol operativo.** Reservado para automatización (Terraform de bootstrap, Workload Identity Pools de `gcp-10`). Nunca hospeda workloads.

## 3. Qué va en cada project de Security

| Project | Qué hospeda | Quién lo toca |
|---------|-------------|---------------|
| `logging-prod` | Buckets GCS y datasets BigQuery de los sinks de Cloud Logging agregados; retención larga. | **Nadie** operativamente. Sink como principal escribe; `gcp-security@` lee. |
| `security-audit` | Security Command Center (si Enterprise), consola de analistas, dashboards. | `gcp-security@` con custom role. |

## 4. Qué va en cada project de Workloads (ejemplo `checkout-prod`)

| Recurso | Patrón |
|---------|--------|
| VPC `checkout-prod-vpc` (si no usa Shared VPC) | Subnets regionales, firewall rules basadas en service account. |
| Cloud Run `checkout-api` | La workload propiamente dicha, con min-instances y traffic splitting. |
| Cloud SQL `checkout-db` | HA regional, backups, acceso solo vía Cloud SQL Auth Proxy. |
| Secret Manager | Secretos de la app, consumidos por IAM desde Cloud Run. |
| Bucket GCS | Con `publicAccessPrevention=enforced` (vía Org Policy heredada). |

## 5. Herencia de Org Policies — ejemplo visual

```
Organization  ─── storage.publicAccessPrevention=enforced
                  iam.disableServiceAccountKeyCreation=enforced
                  iam.allowedPolicyMemberDomains=[customer-id-ejemplo]
                  │
                  └── Folder Workloads/Prod  ─── compute.requireOsLogin=enforced
                                                 (VPC-SC perimeter aplicado aquí)
                                                 │
                                                 └── Project checkout-prod
                                                     ← hereda las 3 de Org
                                                     + 1 de Workloads/Prod
                                                     = 4 constraints activas
```

Si un developer intenta crear un bucket público en `checkout-prod`: la API `storage.googleapis.com` lo rechaza con `googleapi: Error 403: ... constraint storage.publicAccessPrevention ...`. Y no hay nada que pueda hacer el owner del project — la Org Policy está por encima.

## 6. Qué NO está en el diagrama (a propósito)

- **Projects de clientes finales** (si fueras un SaaS que crea un project por tenant): va en un folder aparte `Customers/`, pero fuera de scope para una org de 20 personas.
- **Projects temporales** para PoCs: viven en `Sandbox` con TTL manual, o se crean con un prefijo `poc-` y una pipeline los borra tras N días.

## 7. Checklist mental al mirar un árbol de otra org

1. ¿Hay un folder `Security` con projects aparte? Si no, ¿dónde están los logs centralizados?
2. ¿Hay un project `org-admin` separado o están pegando scripts al management?
3. ¿Cuántas Org Policies hay en Organization? ¿Están las 4 del baseline?
4. ¿Los projects productivos están en un folder propio o mezclados con dev?
5. ¿Existe un folder `Sandbox` con budget cap, o la gente experimenta en projects random?

Si falla alguna, hay deuda arquitectónica.
