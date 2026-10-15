# Lección: Remote backends y locking

> **ID:** `tf-11-remote-backends-and-locking` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `tf-05-state-basics`, `tf-08-environments-workspaces-vs-directories`.

---

## 1. Introducción intuitiva

Hasta ahora tu `terraform.tfstate` ha vivido en tu laptop. Funciona para aprender, no para un equipo. En cuanto una segunda persona corre `terraform apply` sobre la misma infraestructura pasan tres cosas a la vez:

1. Cada quien tiene **su propia copia** del state, divergentes a los segundos. La verdad se parte.
2. Si ambos aplican a la vez, Terraform no puede evitar que **dos apply concurrentes** emitan requests contradictorios al provider. El resultado es un state corrupto y recursos huérfanos.
3. Un `plan` requiere la última versión del state. Si la tuya tiene 10 minutos de desfase, tu plan está mintiendo.

La solución tiene dos piezas separadas que a veces se confunden:

- **Backend remoto** — mueve el fichero `tfstate` a un almacenamiento compartido (S3, GCS, Azure Blob, HCP, un servidor HTTP…). Resuelve el problema del "¿dónde vive la verdad?".
- **State locking** — un mecanismo que garantiza que solo un `apply` esté en vuelo a la vez contra ese state. Resuelve el problema de la concurrencia.

No todos los backends traen locking. S3 "a secas" no bloqueaba hasta que apareció S3 Conditional Writes y el soporte nativo reciente; históricamente la pareja fue **S3 + DynamoDB** (DynamoDB sostiene el lock). HCP Terraform y `gcs` tienen locking integrado. El backend `http` depende de que el servidor implemente los endpoints `LOCK`/`UNLOCK`. El backend `local` también hace locking… pero sobre un fichero en tu disco, inútil para dos máquinas distintas.

Este módulo cubre tres cosas:

1. **Qué backend elegir** y por qué.
2. **Cómo migrar** sin perder state.
3. **Qué hacer cuando algo se rompe** (el lock se queda colgado, el bucket pierde la última versión, el state diverge).

Y una decisión arquitectónica que casi todo el mundo pospone demasiado: **no tengas un solo state para todo**. Divídelo por bounded context. Un state por bounded context, por ambiente.

---

## 2. Fundamentos: qué es un backend

En HCL un backend se configura dentro del bloque `terraform`:

```hcl
terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "acme-tf-state-dev"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "acme-tf-lock-dev"
  }
}
```

Lo que hace un backend, por contrato, es exponer:

- **Get / Put del state**: lectura y escritura del JSON.
- **Lock / Unlock**: adquisición y liberación de un lock exclusivo con un `LockID`.
- **List versiones** (opcional, si el almacenamiento es versionado): para rollbacks.

Terraform solo exige las dos primeras capacidades funcionales (Get/Put + Lock/Unlock). El resto —cifrado, auditoría, retención— lo delega al backend.

Un detalle importante: la **configuración del backend es parcial** en el bloque. Si pones todo ahí, acoplas el código al ambiente. El patrón habitual es:

```hcl
terraform {
  backend "s3" {}   # vacío a propósito
}
```

Y pasas los parámetros con `terraform init -backend-config=...`:

```bash
terraform init \
  -backend-config="bucket=acme-tf-state-dev" \
  -backend-config="key=network/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=acme-tf-lock-dev"
```

O con un fichero `backend.hcl` por ambiente:

```bash
terraform init -backend-config=env/dev/backend.hcl
```

Así el mismo código corre contra `dev`, `stg` o `prod` cambiando solo el `-backend-config`.

---

## 3. Matriz de backends soportados

| Backend | Dónde vive el state | Locking | Encriptación | Cuándo usarlo |
|---------|---------------------|---------|--------------|---------------|
| `local` | Fichero `terraform.tfstate` en disco | File lock (OS) | — | Solo para aprender o para un stack personal. |
| `s3` | Objeto en bucket S3 | DynamoDB (histórico) o S3 native locking (reciente, con `use_lockfile = true`) | SSE-S3 / SSE-KMS | Default razonable en AWS. |
| `gcs` | Objeto en bucket GCS | Nativo (object generation) | GMEK / CMEK | Default en GCP. |
| `azurerm` | Blob en Storage Account | Nativo (blob lease) | SSE | Default en Azure. |
| `http` | Servidor HTTP arbitrario | Lo implementa el servidor (`LOCK`/`UNLOCK`) | Depende | GitLab/GitHub managed state, servicios caseros. |
| `remote` / `cloud` | HCP Terraform / Terraform Cloud | Nativo | Nativo | Equipos que quieren también gestión de **runs**, no solo state. |
| `kubernetes` | Secret en el cluster | Nativo (lease) | Solo si cifras etcd | Nicho. Útil si Kubernetes es tu "fuente de verdad" operacional. |
| `oss` / `cos` / `tencentcloud` / … | Equivalentes de otras clouds | Nativo | Nativo | Mismo criterio por cloud. |

Dos criterios para elegir:

- **Dónde vive tu organización**. Si todo es AWS, `s3` sin fricción. Si todo es GCP, `gcs`. Mezclar backends por "preferencia personal" complica el on-call.
- **¿Necesitas gestionar runs centralmente?** Si la respuesta es sí (equipo grande, política de approvals, variables de ambiente centralizadas, audit log de quién aplicó qué), **HCP Terraform** paga su coste. Si no, un bucket + DDB es más que suficiente.

Nota sobre `kubernetes`: durante años fue "no recomendado" por la propia doc; verifica el estado actual antes de adoptarlo en producción. Para learning sigue siendo útil.

---

## 4. S3 + DynamoDB a profundidad

Es el patrón más común, y vale la pena entenderlo bien.

### 4.1 Qué guarda el bucket

Un único objeto por state:

```
s3://acme-tf-state-dev/network/terraform.tfstate
```

Si el bucket tiene **versioning activado**, cada escritura genera una nueva versión; las anteriores quedan recuperables. Esto es una red de seguridad real: si un `apply` corrupto escribe un state malo, puedes volver a la versión anterior.

### 4.2 Qué guarda DynamoDB

Una tabla con **PK = `LockID`** (tipo string). El contenido de una fila mientras el lock está tomado se parece a:

```json
{
  "LockID":   "acme-tf-state-dev/network/terraform.tfstate-md5",
  "Info":     "{\"ID\":\"abc123…\",\"Operation\":\"OperationTypeApply\",\"Who\":\"alice@laptop\",\"Version\":\"1.6.4\",\"Created\":\"2026-10-15T12:34:56Z\",\"Path\":\"acme-tf-state-dev/network/terraform.tfstate\"}"
}
```

El `LockID` es la ruta `bucket/key` con `-md5` detrás; el campo `Info` lleva **quién** tomó el lock, con qué versión, cuándo y qué operación. Cuando Terraform termina (bien o mal) hace `DeleteItem` y la fila desaparece. Si el proceso muere entre `PutItem` y `DeleteItem` (SIGKILL, laptop cerrada, CI runner reciclado), la fila **se queda**. Eso es lo que llamamos "lock colgado".

### 4.3 S3 native locking

Desde que S3 soporta **Conditional Writes** (`If-Match` sobre ETag) de forma consistente, Terraform tiene una vía para hacer locking **sin DynamoDB**. Se activa con `use_lockfile = true`:

```hcl
backend "s3" {
  bucket       = "acme-tf-state-dev"
  key          = "network/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true   # S3 native locking, sin DynamoDB
}
```

Terraform crea un objeto adicional `terraform.tfstate.tflock` y usa escrituras condicionales. Ventaja: una pieza menos de infra. Desventaja: menos observable (DynamoDB se puede inspeccionar con la consola; el `.tflock` también, pero menos natural). Verifica la versión mínima de Terraform/OpenTofu que soporta esto antes de adoptarlo.

### 4.4 IAM mínimo para el principal

El rol/usuario que corre Terraform **solo** necesita, para el backend:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateObject",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::acme-tf-state-dev/network/*"
    },
    {
      "Sid": "StateBucketList",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::acme-tf-state-dev"
    },
    {
      "Sid": "StateLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:us-east-1:111122223333:table/acme-tf-lock-dev"
    }
  ]
}
```

Nota las dos partes:

- **Objeto específico** (`.../network/*`) — no `s3:*` sobre todo el bucket. Un stack solo debe poder escribir su propio state.
- **Tabla específica** de DDB, no toda la cuenta.

Y naturalmente los permisos **del provider** (los recursos que creas: EC2, RDS, etc.) van aparte y los montamos con assume-role o con credenciales de otro principal.

### 4.5 Controles mínimos del bucket

Cinco cosas, no negociables, para un bucket que alberga state:

1. **Public Access Block** a nivel bucket y a nivel cuenta.
2. **Versioning** activado (red de seguridad ante corrupción).
3. **Encriptación por default** (SSE-S3 con AES256 como mínimo; SSE-KMS si quieres rotación y audit log por key).
4. **Bucket policy** denegando acceso que no venga de los principales esperados.
5. **Lifecycle** para expirar versiones viejas (p. ej. 90 días) y evitar que el bucket crezca sin control.

El `access logging` del bucket es un sexto item muy barato que vale la pena para audits.

---

## 5. Mecánica del lock paso a paso

Suponiendo S3 + DynamoDB:

1. `terraform apply` arranca.
2. Antes de leer el state, Terraform hace `PutItem` en la tabla con **condición** `attribute_not_exists(LockID)`. Si existe → aborta con "Error acquiring the state lock".
3. Si lo adquiere, lee el state (`GetObject` desde S3), hace refresh, genera plan y lo aplica.
4. Al terminar, hace `PutObject` del nuevo state y luego `DeleteItem` sobre la fila de la tabla.

Observa que el **lock se toma antes de leer el state**. Esto es clave: aunque dos ingenieros arranquen `plan` a la vez, solo uno adquiere el lock; el otro ve el error.

Flags útiles:

- `-lock-timeout=10m` — espera hasta 10 minutos a que el lock se libere, en vez de abortar inmediatamente.
- `-lock=false` — **no uses esto nunca en apply**. Está diseñado para `terraform state` operaciones locales con backup local.
- `terraform force-unlock <LOCK_ID>` — borra la fila de DDB. Sin preguntas. Volvemos a esto en la sección 10.

---

## 6. Migración de local a remoto

Flujo canónico, en ese orden:

1. **Hacer bootstrap del backend fuera de Terraform** (o con un Terraform aparte "chicken-and-egg"). Es decir: crear el bucket y la tabla con un script o con un `main.tf` que **usa backend local** y vive en `./bootstrap/`.
2. **Añadir el bloque `backend`** al stack principal.
3. Correr `terraform init -migrate-state`. Terraform detecta que había state local y pregunta si lo migra al nuevo backend. Respondes `yes`.
4. Verificar: `terraform state list` debe mostrar los mismos recursos. Mirar el objeto en el bucket.
5. **Borrar el `terraform.tfstate` local** (y `terraform.tfstate.backup`) una vez verificado. Añadirlos al `.gitignore` si no lo estaban.

Trampas:

- Si el bucket no existe cuando corres `-migrate-state`, Terraform **no crea el bucket por ti**. Aborta. Por eso el bootstrap va antes.
- Si tienes workspaces (`terraform workspace`), cada workspace tiene su propio prefijo (`env:/<name>/<key>`). La migración los mueve a todos.
- Si cambias de backend sin `-migrate-state`, Terraform asume que el nuevo backend ya tiene state. Si no lo tiene, verás un plan de "crear toda la infra desde cero". Casi siempre no es lo que quieres.

Para **ir de un remoto a otro** (p. ej. mover un state entre dos buckets) la mecánica es la misma: cambias la config, `init -migrate-state`.

---

## 7. Split por bounded context

El antipatrón clásico: un único `terraform/` monorepo con un único state para 50 microservicios + VPC + IAM + DNS. Problemas:

- Un `plan` tarda minutos (refresca cientos de recursos aunque no toques nada).
- El lock bloquea a toda la organización.
- Un apply errático en un microservicio puede corromper o afectar accidentalmente el resto.
- Nadie se atreve a tocar nada en vísperas de release.

El patrón sano: **un state por bounded context, por ambiente**. Ejemplo para una org:

```
network/        → state con VPC, subnets, NAT, route tables.
platform/       → state con cluster EKS, IRSA, DNS, cert-manager.
data/           → state con RDS, ElastiCache, S3 buckets de aplicación.
app-payments/   → state del microservicio Payments (service + ALB rule + IAM role).
app-orders/     → state del microservicio Orders.
...
```

Cada uno con su `backend.hcl` apuntando a:

```
s3://acme-tf-state-dev/network/terraform.tfstate
s3://acme-tf-state-dev/platform/terraform.tfstate
s3://acme-tf-state-dev/data/terraform.tfstate
s3://acme-tf-state-dev/app-payments/terraform.tfstate
```

Y una vez separados, los states dependientes se "hablan" con `terraform_remote_state` (modo lectura):

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "acme-tf-state-dev"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_security_group" "app" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
```

**Criterios para decidir dónde cortar**:

- **Ritmo de cambio**: lo que cambia junto, vive junto. Lo que casi nunca cambia, aparte.
- **Blast radius**: lo que puede tumbar producción debe tener su propio state.
- **Ownership**: un state = un equipo responsable (idealmente).
- **Dependencias**: el state A puede leer outputs del state B, pero evita ciclos.
- **Granularidad**: un state por microservicio puede ser demasiado fino (sobrecarga de pipelines); agrupar por "familia" (3-5 microservicios con el mismo owner) suele ser más defendible.

Para 50 microservicios una respuesta razonable: **1 state network + 1 state platform + 1 state data + N states de "familia" de microservicios** (5-10 familias). No 50 states, no 1 state.

---

## 8. Backend `http` y `remote`/`cloud`

### 8.1 `http`

Pensado para servidores que implementan `GET`/`POST` del state y `LOCK`/`UNLOCK` como verbos HTTP custom. GitLab y GitHub lo implementan como "Terraform state managed" integrado con el repo. Para proyectos pequeños es excelente: no necesitas AWS/GCP ni DynamoDB. Para proyectos grandes queda corto (no hay versionado profundo ni gestión de runs).

Configuración típica:

```hcl
terraform {
  backend "http" {
    address        = "https://gitlab.example.com/api/v4/projects/42/terraform/state/network"
    lock_address   = "https://gitlab.example.com/api/v4/projects/42/terraform/state/network/lock"
    unlock_address = "https://gitlab.example.com/api/v4/projects/42/terraform/state/network/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    username       = "<token-user>"
    password       = "<token>"
  }
}
```

Puedes también montar un servidor casero (hay implementaciones de referencia en Python/Go). Útil para labs locales sin docker.

### 8.2 `remote` y `cloud` (HCP Terraform / Terraform Cloud / OpenTofu Cloud)

El `cloud` block es la forma moderna:

```hcl
terraform {
  cloud {
    organization = "acme"
    workspaces { name = "network-dev" }
  }
}
```

Hace tres cosas que `s3` no hace:

- Ejecuta los `plan` y `apply` **en los runners de HCP** (modo remote execution), no en tu laptop. Credenciales viven ahí.
- Gestiona variables (incluyendo sensibles) por workspace.
- Audit log de quién lanzó qué run y aprobaciones manuales (gated applies).

A cambio es un servicio externo, con su propio pricing. Para una organización pequeña con bajo volumen es gratis; para una org grande toca pagar o auto-hospedar Terraform Enterprise. OpenTofu Cloud está trayendo el mismo modelo en el ecosistema OpenTofu.

Regla práctica: si ya tienes buena higiene de CI/CD con OIDC + runners efímeros, un backend `s3` + un pipeline bien hecho cubre el 80% de lo que da HCP. Si no, HCP te la hace fácil.

---

## 9. Encriptación, versionado y auditoría

### 9.1 Encriptación

- **En reposo (bucket)**: SSE-S3 (AES256) es el mínimo. SSE-KMS con una CMK dedicada añade control de acceso por key, rotación programada y entries en CloudTrail.
- **En tránsito**: TLS. S3 ya lo exige si usas el endpoint estándar y no permites HTTP.
- **A nivel Terraform**: OpenTofu tiene **state encryption nativa** (encripta el contenido del state con un passphrase antes de subirlo). Es independiente del cifrado del backend. Útil para que ni el admin del bucket pueda leer el state en claro. Terraform (HashiCorp) va detrás en esta feature; verifica estado al adoptarlo.

### 9.2 Versionado

Activar bucket versioning no es opcional para un bucket de state. Políticas típicas:

- Retener versiones no actuales 90 días.
- Expirar delete markers 7 días.
- Transicionar a Glacier Deep Archive las versiones > 1 año (si el compliance lo exige).

### 9.3 Auditoría

- **CloudTrail** debería capturar `GetObject` / `PutObject` / `DeleteObject` sobre el bucket (data events, no viene por default — configurar).
- **DynamoDB Streams** no es necesario, pero `PutItem`/`DeleteItem` también quedan en CloudTrail (management events).
- Preguntas típicas que debes poder responder: "¿quién aplicó el 2026-10-14 a las 15:03?" → log CT + `Info` field del lock.

---

## 10. Lock colgado: anatomía y recuperación

### 10.1 Cómo se cuelga

- Laptop cerrada a mitad del apply.
- Runner de CI reciclado (SIGKILL en < 30s en algunos CI providers).
- Pérdida de red justo entre `PutItem` del lock y `DeleteItem`.
- `terraform apply` muere con exit code != 0 en una fase donde ya aplicó parte y no completó la escritura final del state.

Resultado: la próxima vez que alguien corra `apply`, verá:

```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed

Lock Info:
  ID:        f3a1c9e2-...
  Path:      acme-tf-state-dev/network/terraform.tfstate
  Operation: OperationTypeApply
  Who:       alice@laptop
  Version:   1.6.4
  Created:   2026-10-15 12:34:56 UTC
  Info:
```

### 10.2 Protocolo de recuperación

1. **Confirmar que el proceso original está muerto**. Pregunta a Alice. Mira el runner de CI. **No** hagas `force-unlock` si el apply original sigue vivo.
2. **Verificar el estado real** del state en el bucket (`aws s3 ls`, `aws s3api list-object-versions`). ¿Hubo escritura reciente?
3. **Si el state refleja lo esperado y nadie está aplicando**, correr:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```
   Confirma con `yes`. Esto borra la fila de la tabla. **No** toca el state.
4. **Si el state parece corrupto** (p. ej. incompleto, con recursos duplicados), antes de `force-unlock` restaura la versión anterior del bucket:
   ```bash
   aws s3api list-object-versions --bucket acme-tf-state-dev --prefix network/terraform.tfstate
   aws s3api copy-object --copy-source "acme-tf-state-dev/network/terraform.tfstate?versionId=<ID_PREVIO>" ...
   ```
5. Documenta en el post-mortem **por qué** se colgó, no solo cómo lo arreglaste.

### 10.3 Riesgos

- `force-unlock` sobre un apply vivo → dos apply en paralelo → state corrupto y recursos duplicados o huérfanos. **Irreversible sin intervención manual pesada**.
- `force-unlock` sin confirmar que el state es consistente → el próximo apply usa un state malo como base y empeora la situación.
- Habilitar `-lock=false` como "parche" → desactiva todo el mecanismo. Es la peor opción.

Regla: **antes de `force-unlock`, pregunta y verifica**. Si no puedes confirmar en 15 minutos, es mejor esperar que romper.

---

## 11. Antipatrones

- **Un único bucket + un único state para toda la org.** Ingobernable a los 6 meses.
- **Backend diferente por ambiente (`s3` en dev, `cloud` en prod).** Multiplica caminos de código y rutas de debug.
- **`terraform.tfstate` versionado en Git.** Secretos filtrados y conflictos de merge imposibles. Siempre `.gitignore`.
- **Credenciales del provider dentro del bloque `backend`.** Las credenciales van en el entorno/perfil del shell, no en HCL.
- **Bucket público "temporalmente" para debug.** No existe el "temporalmente".
- **`-lock=false` en `apply`.** Nunca.
- **`force-unlock` como primera línea de triage** cuando aparece el error. Primera línea: investigar.
- **State encryption como sustituto del control de acceso al bucket**. Son capas distintas; necesitas ambas.

---

## 12. Resumen y lo que sigue

- Un backend remoto resuelve "dónde vive la verdad". El locking resuelve "cómo evitamos apply concurrentes".
- `s3` + DynamoDB (o S3 native locking) es el default razonable en AWS. `gcs` en GCP. `azurerm` en Azure. HCP cuando quieres también gestión de runs.
- Migración: bootstrap del backend aparte → `backend {}` → `terraform init -migrate-state`.
- Split por bounded context: un state por contexto por ambiente. Para 50 microservicios, agrupa por familia; no 50 states, no 1 state.
- IAM del principal: mínimo necesario sobre el objeto específico del bucket y la fila específica de la tabla.
- Lock colgado: investigar primero, `force-unlock` después. Nunca sobre un apply vivo.

En el próximo módulo (`tf-12`) blindamos el **contenido** del plan con policy-as-code: ahora que el state está defendido operacionalmente, protegemos lo que puede entrar en él.

### Preguntas de evaluación (sin consultar)

1. Explica qué información lleva la fila de DDB cuando el lock está tomado y qué pasa paso a paso cuando corres `terraform apply`.
2. ¿Cuándo `force-unlock` es correcto y cuándo es catastrófico?
3. Diseña el layout de buckets y keys para una org con 3 ambientes y 50 microservicios. Justifica el criterio de agrupación.
4. ¿Por qué `-lock=false` en `apply` es tan peligroso?
5. ¿Qué diferencia operativa real da HCP Terraform frente a `s3` + DDB bien montado?
