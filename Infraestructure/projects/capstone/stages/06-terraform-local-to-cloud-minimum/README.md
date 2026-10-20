# Capstone — Etapa 6: IaC con Terraform (local → cloud mínimo)

Primera etapa en la que el proyecto deja de ser puramente local: introducimos **Terraform** para describir los *cimientos* de la nube elegida (backend remoto para el `state`, red mínima y registro de contenedores) sin desplegar todavía la aplicación. El objetivo es que la infraestructura exista, se destruya, y evolucione por código — no que corra la app en la nube (eso es la etapa 7).

> Prosa en español, código / identificadores / nombres de recurso en inglés.
> **No se aplica contra una cuenta real como parte del lab**. Todas las validaciones son `terraform validate` / `fmt` / `init -backend=false` o se corren contra `LocalStack` opcional.

---

## 1. Resumen de la etapa

- **Objetivo**: definir, versionar y validar los módulos de infraestructura base (`backend`, `network`, `registry`) para los tres clouds principales — AWS (default demo), GCP y Azure — y escoger uno con una ADR firmada.
- **Delta vs. etapa 5**: en la etapa 5 el pipeline ya construye, escanea, firma y publica una imagen. Hasta ahora el *runtime* de esa imagen vivía solo en Docker Compose. Esta etapa introduce la *superficie cloud* mínima para que la etapa 7 pueda desplegarla.
- **Fuera de scope (siguiente iteración)**:
  - Desplegar la app sobre ECS/Cloud Run/Container Apps (etapa 7).
  - Base de datos cloud administrada (RDS/Cloud SQL/Azure DB) — por ahora el network tiene subnets *reservadas* para persistencia, pero no provisionamos la DB.
  - Observabilidad cloud (etapa 11).
  - Pipeline de Terraform (`plan` en PR, `apply` en merge) — se insinúa pero no se implementa; se activa realmente en la etapa 7.

---

## 2. Arquitectura al cierre de esta etapa

```
        ┌──────────────────── repo git ────────────────────┐
        │  app/            (FastAPI, de etapas 1-5)        │
        │  docker/         (Dockerfile, Compose dev)       │
        │  .github/        (CI de etapas 3 y 5)            │
        │  terraform/                                      │
        │    ├─ aws/       main · variables · outputs ·    │
        │    │             versions · backend              │
        │    ├─ gcp/       (idem)                          │
        │    └─ azure/     (idem)                          │
        │  docs/adr/0006-cloud-choice.md                   │
        └──────────────────────────────────────────────────┘
                              │
                              │  (terraform init / validate / plan)
                              ▼
       ┌──────────────── cloud elegido (AWS por default) ───┐
       │  Backend remoto del state                         │
       │    S3 bucket   (encrypted, versioned, blocked)    │
       │    DynamoDB    (locking)                          │
       │  Network mínima                                   │
       │    VPC + 2 public subnets + 2 private subnets     │
       │    IGW + NAT (single-AZ para ahorrar)             │
       │    Security Group base (egress only)              │
       │  Container registry                               │
       │    ECR private repo con lifecycle policy          │
       └───────────────────────────────────────────────────┘
```

- **Entra**: HCL versionado, variables por entorno, credenciales de CI vía **OIDC** (sin claves largas).
- **Sale**: outputs reusables por la etapa 7 — `vpc_id`, `private_subnet_ids`, `registry_url`, `state_backend_config`.
- **Resource list (AWS, default)**: 1 VPC, 2 subnets públicas, 2 privadas, 1 IGW, 1 NAT, 1 SG, 1 ECR, 1 S3 (state), 1 DynamoDB (lock). GCP/Azure quedan listos pero sin aplicar.

---

## 3. Prerrequisitos verificados

Checklist que la etapa 6 asume **cerrado**:

- [x] Etapa 1: `fastapi` corre local con tests verdes.
- [x] Etapa 2: tags SemVer en git (`v0.x.y`) y changelog por release.
- [x] Etapa 3: CI con lint + test + SAST + SCA + secret-scan en PR.
- [x] Etapa 4: imagen Docker reproducible y Compose dev funcional.
- [x] Etapa 5: pipeline de build + container-scan + SBOM + firma, imagen publicada a un registro accesible.
- [ ] Cuenta cloud *de laboratorio* disponible (opcional — este lab se puede completar entero sin aplicar nada).
- [ ] `terraform >= 1.6` instalado (`terraform -v`).
- [ ] Opcional: Docker + LocalStack si querés probar el backend AWS sin cuenta real.

Si falta algo de 1-5, cerrarlo antes de abrir esta etapa.

---

## 4. Implementación guiada

### 4.1. Decidir el cloud (ADR primero, código después)

1. Leé `terraform/README.md` — es la ADR de elección de cloud.
2. Completá los campos *contexto* y *decisión* en la copia del equipo (actividad `01-choose-cloud-adr`).
3. Marcá el cloud elegido. Por defecto el lab asume **AWS** porque es el stack más común en el programa; cambiarlo solo afecta qué carpeta de `terraform/` se usa primero.

### 4.2. Esqueleto de módulos (los tres clouds)

Cada carpeta `terraform/<cloud>/` contiene siempre los mismos cinco archivos:

| archivo        | propósito                                             |
|----------------|-------------------------------------------------------|
| `versions.tf`  | pins de `terraform` y del provider.                   |
| `backend.tf`   | `backend "s3" {}` / `"gcs"` / `"azurerm"` — sin valores embebidos; se pasan por `-backend-config`. |
| `variables.tf` | región, nombre de proyecto, CIDR, tags.               |
| `main.tf`      | tres bloques lógicos: `backend` (state infra), `network`, `registry`. |
| `outputs.tf`   | lo que la etapa 7 consume: `vpc_id`, `subnets`, `registry_url`. |

> El `backend.tf` está *parcial* a propósito: se completa con `terraform init -backend-config=...` para no comitear nombres de bucket reales.

### 4.3. Validación local sin cuenta cloud

Esto es el *flujo por defecto* del lab:

```bash
cd terraform/aws
terraform fmt -check -recursive
terraform init -backend=false   # no toca el backend remoto
terraform validate              # chequea sintaxis + referencias
```

Repetir en `gcp/` y `azure/`. Ningún recurso creado, cero costo.

### 4.4. Validación "más real" opcional con LocalStack (solo AWS)

Opt-in. Útil para ejercitar `terraform init` real con S3+DynamoDB sin AWS verdadero:

```bash
docker run --rm -d -p 4566:4566 --name ls localstack/localstack
cd terraform/aws
terraform init \
  -backend-config="bucket=cap-state-local" \
  -backend-config="dynamodb_table=cap-lock-local" \
  -backend-config="region=us-east-1" \
  -backend-config="endpoints={ s3=\"http://localhost:4566\", dynamodb=\"http://localhost:4566\" }"
# cleanup
docker stop ls
```

### 4.5. OIDC para CI → cloud (sin aplicar en este lab)

El `terraform/README.md` describe cómo cada cloud expone **OIDC federation** para GitHub Actions:

- **AWS**: `aws_iam_openid_connect_provider` + `aws_iam_role` con `assume_role_policy` que confía en `token.actions.githubusercontent.com`. En CI se usa `aws-actions/configure-aws-credentials@vN` sin secretos largos.
- **GCP**: Workload Identity Federation + `google_iam_workload_identity_pool` + `_provider`. En CI, `google-github-actions/auth@vN`.
- **Azure**: *Federated credentials* en un `azuread_application`. En CI, `azure/login@vN`.

Para esta etapa escribimos los recursos (comentados en los `main.tf` donde aplique) pero **no los aplicamos**; se activan en la etapa 7 cuando corramos `terraform apply` por primera vez.

### 4.6. Diagrama de módulos

Un solo stack por cloud. No separamos `envs/` todavía — eso llega cuando la etapa 7 nos obligue a distinguir `dev` de `prod`.

---

## 5. Actividades del estudiante

Dos actividades. El `id` sigue el patrón `cap-06-NN-slug` para no colisionar con los activities de `courses/terraform/`.

| # | id                               | tipo          | foco                                                   |
|---|----------------------------------|---------------|--------------------------------------------------------|
| 1 | `cap-06-01-choose-cloud-adr`     | architecture  | redactar la ADR 0006, justificar AWS/GCP/Azure con criterios. |
| 2 | `cap-06-02-bootstrap-backend-local` | guided-lab | correr `terraform validate` en los tres y, opcional, `init` real contra LocalStack. |

Al menos una no-guiada: la ADR cuenta como `architecture`.

---

## 6. Entregables

- `terraform/aws/`, `terraform/gcp/`, `terraform/azure/` con los cinco archivos cada una.
- `terraform/README.md` como ADR 0006 (elección de cloud) firmada por el estudiante.
- `docs/adr/0006-cloud-choice.md` (o el link al README anterior si se mantiene centralizado) en el repo propio del estudiante.
- `activities/01-choose-cloud-adr/decision.md` con la decisión del equipo.
- Captura o salida de `terraform validate` verde en los tres clouds.

No hay que entregar ningún recurso realmente creado en la nube.

---

## 7. Pruebas y criterios de aceptación

Automáticas:

- `terraform fmt -check -recursive` en los tres clouds.
- `terraform init -backend=false && terraform validate` verde en los tres.
- `bash activities/02-bootstrap-backend-local/tests/validate.sh` → `RESULT: PASS`.
- `bash activities/01-choose-cloud-adr/tests/validate.sh` → `RESULT: PASS` (verifica que la ADR fue completada, no quedó como plantilla).
- `python scripts/validate-activities.py` → `0 issue(s)` sobre todo el repo (los `activity.yaml` de esta etapa no viven bajo `courses/`, así que no cuentan; verificar que ninguno del resto se rompió).

Cualitativas:

- Ningún `backend "s3"` / `"gcs"` / `"azurerm"` tiene valores hardcodeados (bucket, cuenta, project).
- Ninguna credencial, ARN, tenant id o project id *real* en los `.tf`.
- La ADR 0006 nombra los tres clouds y justifica la elección con al menos tres criterios (costo, familiaridad del equipo, servicios disponibles para la etapa 7, etc.).
- OIDC descrito, no claves largas.

---

## 8. Costos y limpieza

**Lab por defecto**: `$0`. Nada se aplica.

Si el estudiante decide aplicar en una cuenta real (fuera del scope del lab, bajo su responsabilidad), estimación mensual aproximada (`us-east-1` / `us-central1` / `eastus`):

| recurso                          | AWS            | GCP               | Azure                 |
|----------------------------------|----------------|-------------------|-----------------------|
| State backend (bucket + lock)    | ~$0.10         | ~$0.05            | ~$0.10                |
| VPC / subnets / IGW              | $0             | $0                | $0                    |
| NAT Gateway (single AZ)          | ~$32           | ~$32 (Cloud NAT)  | ~$30 (NAT Gateway)    |
| Container registry (1 repo, bajo tráfico) | ~$0.10 | ~$0.10            | ~$0.10                |
| **Total aprox.**                 | **~$32/mes**   | **~$32/mes**      | **~$30/mes**          |

El NAT es el gasto dominante; en lab se recomienda **destruir al final del día**.

Limpieza (si aplicaste):

```bash
cd terraform/<cloud>
terraform destroy -auto-approve
# backup extra: borrar manualmente el bucket/table del state si quedó
```

Guard-rails recomendados:

- Budget alert en el cloud a **$5/mes** sobre el proyecto del lab.
- Lifecycle policy en el bucket del state (versioning + 30-day expiration de versiones antiguas).
- En ECR/GAR/ACR, retention de 10 imágenes por tag.

---

## 9. Riesgos y mitigaciones

| # | riesgo                                                 | mitigación |
|---|--------------------------------------------------------|------------|
| 1 | Comitear nombres reales de bucket / project / tenant.  | `backend.tf` queda *parcial*; se pasa por `-backend-config` o `*.tfbackend` ignorado en git. Hook `gitleaks` ya corre desde etapa 3. |
| 2 | Costo olvidado del NAT Gateway.                        | Lab por defecto no aplica; si se aplica, destroy obligatorio + budget alert. |
| 3 | OIDC mal configurado deja CI sin poder desplegar en etapa 7. | Esta etapa escribe los recursos *comentados* y los documenta; etapa 7 los activa con un test de `aws sts get-caller-identity` (equivalente en GCP/Azure) antes de intentar `apply`. |

Hints progresivos si el estudiante se traba:

1. `terraform validate` falla → leer el mensaje; típico es provider sin `source =`.
2. `terraform init` falla con backend → confirmar que `-backend-config` tiene *todas* las claves (bucket/table/region).
3. ADR en blanco → arrancar por "¿qué cloud ya conocés mejor?" y después revisar costos.

---

## 10. Puente con la siguiente etapa

- **Habilita**: la etapa 7 toma `vpc_id`, `private_subnet_ids`, y `registry_url` como *inputs* y añade un módulo de *runtime* (ECS/Cloud Run/Container Apps).
- **Queda corriendo**: nada por defecto. Si se aplicó, el estudiante decide — recomendamos **destruir** entre sesiones de trabajo.
- **Cliffhanger**: *"la infra base ya existe en código, pero ninguna imagen corre. ¿Cómo pasa la imagen firmada de la etapa 5 a correr en el cloud sin introducir claves largas en CI?"* — la etapa 7 responde con OIDC + un servicio de runtime administrado.
