# Capstone Stage 07 — Despliegue cloud (ECS Fargate / Cloud Run / Container Apps)

## 1. Resumen de la etapa

Primer despliegue **cloud real** (opcional) de la imagen firmada en la etapa 5.
El estudiante elige **una** de las tres plataformas gestionadas de contenedores
—**ECS Fargate** (AWS), **Cloud Run** (GCP) o **Container Apps** (Azure)— y
publica la API FastAPI contra una base de datos **Postgres gestionada** del
mismo proveedor, usando el **secret manager** y la **identidad administrada /
rol IAM** del cloud. El pipeline de CI solo hace `terraform plan`; el `apply` es
**manual, con advertencia explicita de costo**.

**Delta vs etapa 06.** La etapa 06 dejo Terraform para `localstack` + Postgres
en Docker. La 07 reemplaza el *backend local* por un servicio real por nube,
agrega **IAM/Managed Identity** y lee credenciales de **Secrets Manager /
Secret Manager / Key Vault**. La aplicacion no cambia, solo su envoltorio.

**Fuera de esta etapa.** Kubernetes (etapa 08), Helm/Argo CD (09), multi-env
GitOps (10), observabilidad (11), DevSecOps completo (12). Aqui no se habilitan
multi-region, blue/green ni autoscaling complejo mas alla del minimo que la
plataforma ofrece por defecto.

## 2. Arquitectura al cierre de esta etapa

```
                   +-------------------------+
                   | GitHub Actions (CI)     |
                   |  - lint/test/build/scan |
                   |  - cosign sign (st.5)   |
                   |  - terraform plan ONLY  |
                   +-----------+-------------+
                               | plan artifact
                               v
   developer -- manual apply --> cloud (one of 3)
                               |
      +------------------------+------------------------+
      |                        |                        |
      v                        v                        v
  +--------+              +---------+              +-----------+
  |  AWS   |              |   GCP   |              |   Azure   |
  | ECS/   |              | Cloud   |              | Container |
  | Fargate|  <-- image   | Run v2  |              | Apps      |
  | + ALB  |     signed   |         |              |   + env   |
  +---+----+              +----+----+              +-----+-----+
      |                        |                        |
      v                        v                        v
   RDS Postgres          Cloud SQL Postgres        Azure DB for
   (private)              (private IP)             PostgreSQL
      ^                        ^                        ^
      |                        |                        |
   Secrets Mgr             Secret Mgr                Key Vault
   (DSN secret)            (DSN secret)              (DSN secret)
      ^                        ^                        ^
      |                        |                        |
   Task IAM role           Runtime SA              Managed Identity
```

Entradas: trafico HTTPS publico (`/health`, `/items`).
Salidas: logs al servicio nativo del cloud (CloudWatch / Cloud Logging / Log
Analytics). Metricas basicas de plataforma.

Resource list por cloud (minimo viable):

| AWS | GCP | Azure |
|-----|-----|-------|
| `aws_ecs_cluster`, `aws_ecs_service`, `aws_ecs_task_definition`, `aws_lb`, `aws_lb_target_group`, `aws_lb_listener`, `aws_db_instance` (Postgres), `aws_secretsmanager_secret`, `aws_iam_role` (execution + task), `aws_cloudwatch_log_group` | `google_cloud_run_v2_service`, `google_sql_database_instance` (Postgres), `google_secret_manager_secret`, `google_service_account`, `google_project_iam_member` | `azurerm_container_app`, `azurerm_container_app_environment`, `azurerm_postgresql_flexible_server`, `azurerm_key_vault`, `azurerm_key_vault_secret`, `azurerm_user_assigned_identity`, `azurerm_log_analytics_workspace` |

## 3. Prerrequisitos verificados

- [ ] Etapas 1-6 cerradas y verdes en CI.
- [ ] Imagen OCI publicada y **firmada con cosign** (etapa 05) en un registry
      accesible al cloud elegido (ECR, Artifact Registry o ACR).
- [ ] `terraform` >= 1.5 instalado localmente.
- [ ] CLI del cloud elegido autenticada **solo para `plan` en CI y `apply` manual**:
      - AWS: `aws sts get-caller-identity`
      - GCP: `gcloud auth application-default print-access-token`
      - Azure: `az account show`
- [ ] Un **presupuesto de corte** definido (ver seccion 8).

Si algo falta, cierra primero la etapa correspondiente antes de continuar.

## 4. Implementacion guiada

### 4.1 Elegir UNA nube

Esta etapa no es un *multi-cloud lab*: elige **una** de las tres y recorre su
modulo bajo `terraform/<cloud>/<servicio>/`. Las otras dos quedan como lectura.

### 4.2 Variables sensibles

Nunca pongas la contrasena de la BD en `terraform.tfvars`. El flujo correcto:

1. Terraform **crea** el secreto vacio (resource `*_secret`) y la BD con una
   contrasena aleatoria generada por `random_password`.
2. Terraform **escribe** la DSN final en el secret manager como `secret_version`.
3. El contenedor **lee** la referencia al secreto por nombre; la identidad del
   runtime la resuelve en el arranque.

Esto evita `terraform.tfstate` plano con la clave de la BD.

### 4.3 Ciclo de trabajo

```bash
# dentro de terraform/<cloud>/<servicio>/
terraform init -backend=false      # backend local; en CI lo veremos luego
terraform validate                 # NO llama al cloud
terraform plan -out=tfplan         # SI llama al cloud (lectura)
# revisar el plan a ojo
terraform apply tfplan             # MANUAL, cuesta dinero
# ... usar el servicio ...
bash ../../../scripts/cleanup-<cloud>.sh
```

### 4.4 CI (`plan`-only)

Pipeline sugerido en GitHub Actions:

```yaml
jobs:
  tf-plan:
    runs-on: ubuntu-latest
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      # OIDC login al cloud elegido (sin claves largas).
      - run: terraform init -backend=false
      - run: terraform validate
      - run: terraform plan -no-color -input=false -out=tfplan
      - uses: actions/upload-artifact@v4
        with: { name: tfplan, path: tfplan }
```

`apply` se ejecuta manualmente desde la laptop del operador o desde un *workflow
dispatch* protegido, nunca al mergear a `main`.

### 4.5 Decisiones materiales

| Pregunta | Decision por defecto | Razon |
|----------|----------------------|-------|
| `apply` automatico en CI? | **No** | Un merge accidental no debe gastar dinero. |
| Backend remoto para `tfstate`? | Opcional en esta etapa | Se trabaja en 1 operador; en la etapa 09/10 pasara a S3/GCS/Azure Storage con locking. |
| Imagen pinada por tag o por digest? | **Digest (`@sha256:...`)** | Firma de cosign se verifica contra el digest; un `latest` rompe la cadena. |
| Postgres publico? | **No** | Siempre acceso privado (VPC/subred/private IP). |

## 5. Actividades del estudiante

- `activities/01-deploy-fastapi-to-one-cloud/` — guided-lab: completar los
  TODO del modulo Terraform de la nube elegida y pasar el validador
  estructural. Sin tocar la nube real.

## 6. Entregables

- `terraform/<cloud>/<servicio>/` apply-eable (plan verde en CI).
- Secreto creado en el secret manager con la DSN de la BD.
- URL publica de la API respondiendo `GET /health` -> `200`.
- ADR corto (1 pag.) justificando la nube elegida frente a las otras dos.
- Captura del `terraform destroy` limpio al final de la sesion.

## 7. Pruebas y criterios de aceptacion

- `terraform validate` pasa en los 3 modulos.
- `bash activities/01-deploy-fastapi-to-one-cloud/tests/validate.sh` imprime
  `RESULT: 0 issue(s).`.
- La API publica responde `200` en `/health` cuando el apply se hace.
- `terraform destroy` deja la cuenta como estaba (verificado desde la consola
  del cloud).
- Ningun secreto en Git (grep de `password =`, `secret =`, `BEGIN PRIVATE KEY`).
- Imagen desplegada por **digest**, no por `latest`.

## 8. Costos y limpieza

Estimacion `$ / mes` **si olvidas apagarlo** (us-east equivalente, orden de
magnitud, puede variar `+/- 30%`):

| Recurso | AWS (ECS Fargate) | GCP (Cloud Run) | Azure (Container Apps) |
|---------|-------------------|-----------------|------------------------|
| Plano de datos containers | `~$15` (0.25 vCPU, 0.5 GB, 1 task 24/7) | `$0` idle + `~$0.00002400/vCPU-s` activo | `~$10` (0.5 vCPU, 1 Gi, min-replicas=1) |
| Load balancer / ingress | `~$18` (ALB) | incluido | incluido |
| Postgres gestionado | `~$15` (db.t4g.micro) | `~$9` (db-f1-micro) | `~$12` (B1ms flexible) |
| Secrets / KV | `~$0.40/secreto/mes` | `~$0.06/version/mes` | `~$0.03/op/10k` |
| Logs | depende | depende | depende |
| **Total aproximado 24/7** | **`~$50/mes`** | **`~$10/mes` idle** | **`~$25/mes`** |

**Guard-rails obligatorios antes de `apply`:**

- AWS: `aws budgets create-budget --budget BudgetName=capstone-07,BudgetLimit={Amount=20,Unit=USD},TimeUnit=MONTHLY,BudgetType=COST`.
- GCP: Billing budget con alerta a 50% / 90% / 100% de **$10/mes**.
- Azure: `az consumption budget create` con `--amount 20`.

**Cleanup estricto:**

```bash
# tras la demo, SIEMPRE:
bash scripts/cleanup-aws.sh      # o cleanup-gcp.sh / cleanup-azure.sh
```

Los scripts hacen `terraform destroy -auto-approve` y luego verifican con la
CLI del cloud que **no quedan recursos tagueados `capstone=07`**. Si quedan,
fallan ruidosamente con `exit 1`.

## 9. Riesgos y mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Olvido de `destroy` -> factura inesperada. | Script `cleanup-<cloud>.sh` + budget alert configurado antes del primer apply. |
| Secreto filtrado en `terraform.tfstate`. | Secreto creado vacio por Terraform; valor inyectado via `random_password` y leido por el runtime. `tfstate` jamas commiteado. |
| `apply` accidental en CI. | CI hace solo `plan`. `apply` requiere credenciales que CI no tiene, o un `workflow_dispatch` con approval. |
| Imagen `:latest` rompe cosign. | Modulos TF usan variable `image_digest` (no `image_tag`). El starter lo marca TODO. |
| Postgres expuesto a internet. | Variables de red por defecto: `publicly_accessible = false`, private IP. Validador estructural lo exige. |

Hints progresivos si el estudiante se atora:

1. "Lee los `TODO` del modulo de tu nube elegida."
2. "Mira el `solution/` **solo** si llevas 15 min sin avanzar."
3. "Pega el error exacto antes de pedir ayuda."

## 10. Puente con la siguiente etapa

- La imagen desplegada aqui es la misma que correra en Kubernetes en la etapa 8.
- La separacion `execution role` / `task role` (AWS) o `runtime SA` (GCP) o
  `managed identity` (Azure) **se mapea 1:1** a `ServiceAccount` + IRSA /
  Workload Identity / AAD Pod Identity en K8s.
- El secreto queda en el secret manager; la etapa 12 (ESO) lo sincronizara a
  Kubernetes sin re-escribirlo.
- Cliffhanger: "Tu API corre con 1 replica detras de un LB gestionado. ¿Que
  cambia cuando necesitas 3 replicas con afinidad por zona, PDB, HPA custom y
  un Istio injection? Spoiler: todo lo que esta etapa oculto."

---

Convenciones: ver `../../../README.md`.
