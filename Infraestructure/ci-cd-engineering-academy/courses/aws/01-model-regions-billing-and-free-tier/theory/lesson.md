# aws-01 — Lección: modelo de AWS, regiones, billing y Free Tier

> 12 secciones. Mezcla de concepto y práctica sin coste. Prerrequisito: nociones básicas de cloud.

---

## 1. La cuenta AWS: unidad de facturación, de aislamiento y de blast radius

Una **cuenta AWS** es a la vez tres cosas que a menudo se confunden:

1. **La unidad de facturación.** Cada cuenta tiene un `AccountId` numérico de 12 dígitos (en este módulo usaremos `123456789012` como placeholder siempre). Toda factura que AWS emite se emite por `AccountId`. Si tu organización tiene 20 cuentas, recibes 20 facturas (o una consolidada vía Organizations — ver §12).
2. **La unidad de aislamiento.** Por default, los recursos de la cuenta A **no son visibles** desde la cuenta B. Para compartir un bucket S3, una AMI, un KMS key o un rol, hace falta construir **explícitamente** permisos cross-account. Esto es un *feature*, no un defecto: la cuenta es tu **frontera de blast radius**. Si un atacante compromete una cuenta, no hereda nada de las otras.
3. **La unidad de "quién mandó esta API".** Todo request a AWS lleva una identidad asociada a **una** cuenta (la del principal que llama). Toda política IAM se evalúa en el contexto de **esa** cuenta.

Internamente, la cuenta nace con **una** identidad humana llamada **root**. El root es el email con el que se abrió la cuenta y tiene **todos** los permisos **imposibles de restringir** (sí, incluso una SCP puede ser revertida por root). Por eso la práctica profesional es:

- Habilitar **MFA** en root el primer día.
- **Nunca** crear access keys para root (si existen de un setup antiguo: borrarlas).
- Crear **otro** mecanismo de acceso (IAM user con MFA, o mejor: IAM Identity Center / SSO) y usar ese para el día a día.
- Dejar root bloqueado en una caja fuerte digital (password manager, con MFA en hardware token separado idealmente) para los pocos trámites que **solo** root puede hacer (cambiar plan de soporte, cerrar la cuenta, cambiar email root, etc.).

> **Mantra:** *root es como la llave del cuadro eléctrico del edificio. La necesitas tener. No la usas para abrir la puerta de tu casa cada día.*

---

## 2. Regiones y Availability Zones: geografía con criterio

Una **región** es un conjunto de **al menos 3 Availability Zones** físicamente separadas (edificios distintos, redes eléctricas distintas, conectadas entre sí con fibra de baja latencia). Ejemplos: `us-east-1` (Virginia del Norte), `eu-west-1` (Irlanda), `sa-east-1` (São Paulo), `ap-southeast-2` (Sídney).

Una **Availability Zone (AZ)** es un *clúster* de uno o varios datacenters dentro de la región, aislado eléctricamente y de red del resto. El identificador que ves (`us-east-1a`, `us-east-1b`) **es específico de tu cuenta** — la `us-east-1a` de tu cuenta puede ser físicamente distinta a la `us-east-1a` de otra cuenta. Para alinear AZs entre cuentas se usa el **AZ ID** (`use1-az1`, `use1-az2`), que **sí** es estable.

### Criterios reales para elegir región

| Criterio | Qué pesar | Trampa típica |
|----------|-----------|---------------|
| **Latencia a usuarios** | Elegir la región más cercana al grueso de usuarios. CloudFront puede mitigar pero no para APIs mutantes. | Elegir `us-east-1` "porque sí" cuando tus usuarios están en Europa. |
| **Compliance / soberanía** | Si tienes GDPR / LGPD / residencia obligatoria, la región elegida restringe. | Multirregión por "resiliencia" sin notar que replicas PII fuera de la jurisdicción. |
| **Precio** | Precios varían por región. `us-east-1` suele ser la más barata para la mayoría de servicios; regiones nuevas o remotas son hasta 30 % más caras. | Comparar solo EC2 e ignorar egress, NAT, snapshots. |
| **Disponibilidad del servicio** | **No todos los servicios están en todas las regiones**. Bedrock, servicios nuevos de ML, o features específicas pueden tardar meses en llegar a una región. | Diseñar en `us-east-1`, mover a `sa-east-1`, descubrir que el servicio que usas no está. |
| **Blast radius de AWS mismo** | `us-east-1` es la región más grande y la que más veces ha caído de forma visible. Los *control planes* globales de muchos servicios viven ahí (IAM, Route 53 health checks). Si cae `us-east-1`, cosas "globales" se degradan. | Asumir que multirregión te salva de un fallo global cuando el control plane sigue siendo `us-east-1`. |

**Regla práctica:** elige la región más cercana a tus usuarios **que tenga los servicios que necesitas y cumpla compliance**, no la más barata por defecto. El ahorro del 10 % en EC2 no compensa 200 ms más de latencia percibida.

---

## 3. Servicios globales vs regionales: lo que el ARN te dice

Un **ARN** (Amazon Resource Name) sigue el formato:

```
arn:aws:<service>:<region>:<account-id>:<resource>
```

Si el `<region>` está **vacío**, es porque **el recurso es global**. Los servicios realmente globales son pocos y conviene memorizarlos:

- **IAM** — usuarios, grupos, roles, policies. `arn:aws:iam::123456789012:user/alice` (no hay región).
- **Route 53** — zonas hosted y records (los health checks sí tienen región para los endpoints que miden).
- **CloudFront** — distribuciones CDN. Único: solo se gestiona desde `us-east-1`, aunque el edge sea global.
- **Organizations** — la estructura de cuentas de una organización.
- **WAF (classic / global)** y **ACM para CloudFront** — también solo en `us-east-1`.
- **Billing** y **Cost Explorer** — datos agregados por cuenta y por organización.

Casi todo lo demás (EC2, S3 — aunque el nombre del bucket sea global, el bucket vive en una región —, Lambda, RDS, DynamoDB, SNS, SQS, KMS, Secrets Manager…) es **regional**. Esto implica:

- Un bucket S3 creado en `eu-west-1` **no existe** desde la perspectiva de `us-east-1` como recurso regional, aunque su **nombre** esté reservado globalmente.
- Un endpoint de API tiene **host por región**: `s3.eu-west-1.amazonaws.com`, `ec2.us-east-1.amazonaws.com`. Si configuras la CLI con `--region eu-west-1`, tus llamadas van a los endpoints de esa región.
- Replicar entre regiones **cuesta** (egress inter-regional) y **es asíncrono**: cross-region replication de S3 no es "copy pegado instantáneo".

### Por qué CloudFront vive en `us-east-1`

Es un accidente histórico: CloudFront nació como servicio global gestionado desde `us-east-1`, y moverlo rompería ARNs y automatizaciones. Hoy la gestión (crear distribuciones, invalidaciones) sigue siendo `us-east-1`, pero el **tráfico** se sirve desde los **cientos** de edge locations distribuidos. Lo mismo aplica para ACM si quieres un certificado que use CloudFront.

---

## 4. SigV4: por qué toda llamada AWS va firmada

Cuando tú (o la CLI, o un SDK) llamas a `s3.amazonaws.com/mi-bucket/foo.txt`, no es un GET HTTP cualquiera. AWS exige que todo request esté **firmado** con **Signature Version 4 (SigV4)**:

1. Tomas la request canónica (método, path, query string ordenado, headers canónicos, hash del body).
2. La combinas con credenciales (`access_key`, `secret_key`) **y** metadatos de la request (fecha, región, servicio).
3. Produces una firma HMAC-SHA256 que viaja en el header `Authorization: AWS4-HMAC-SHA256 Credential=... Signature=...` (o en query string para presigned URLs).
4. AWS, del otro lado, recalcula la firma con tu `secret_key` almacenada y la **compara**. Si coincide, el request es auténtico; si no, 403.

**Qué garantiza SigV4:**

- **Autenticidad**: solo quien tiene el `secret_key` pudo firmar.
- **Integridad**: si cambias un byte del body o del path tras firmar, la firma falla.
- **Freshness**: la firma incluye timestamp y expira (típicamente 5 min de clock skew tolerado). Esto bloquea replay attacks.
- **Scoping por servicio y región**: la misma `secret_key` firma distinto para `s3` en `us-east-1` que para `s3` en `eu-west-1`. Un attacker que te robe una firma concreta no puede reutilizarla contra otro endpoint.

**Qué NO garantiza:**

- Confidencialidad del body — eso lo da **TLS**, que AWS exige en todos sus endpoints públicos.
- Que el `secret_key` sea tuyo "para siempre". Las credenciales **temporales de STS** (vía rol asumido) tienen un token extra (`SessionToken`) y expiran en minutos u horas.

### Credenciales temporales (STS) vs long-lived access keys

- **Access keys estáticas** (`AKIA...`): sin expiración. Si fugan, el atacante tiene acceso **para siempre** (hasta que las revoques). Son el modelo antiguo, útil solo para scripts triviales en entornos locales y **nunca** para producción.
- **Credenciales temporales** (`ASIA...` + `SessionToken`): emitidas por **STS** (Security Token Service) al asumir un rol o vía IAM Identity Center. Expiran en 15 min – 12 h. Son el modelo moderno y es el que usarás a partir de `aws-02`.

Para este módulo basta saber: **toda llamada va firmada**, y **saber quién estás firmando como** es el primer check. Ese check es `aws sts get-caller-identity`.

---

## 5. `aws sts get-caller-identity`: el "whoami" de AWS

```
$ aws sts get-caller-identity
{
    "UserId": "AIDAEXAMPLEUSERID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/alice"
}
```

Qué te dice este comando:

- **`Account`**: en qué cuenta estás operando ahora. **Confirma siempre que es la que crees.** Un comando ejecutado contra la cuenta equivocada en IAM o S3 puede ser irreversible.
- **`Arn`**: qué principal estás usando. Si es `:user/...` eres un IAM user. Si es `:assumed-role/...` estás usando credenciales temporales de un rol asumido (el caso normal cuando usas SSO). Si es `:root` **para y investiga por qué estás como root**.
- **`UserId`**: identificador interno estable del principal (menos usado en el día a día).

Este es el comando que se recomienda ejecutar **antes** de cualquier operación destructiva (`terraform apply`, `aws s3 rm`, cambios en IAM). Un alias útil:

```bash
alias whoaws='aws sts get-caller-identity --output table'
```

**Por qué este comando siempre funciona si tienes credenciales:** `sts:GetCallerIdentity` es la **única** acción de IAM que **no requiere permisos**. AWS lo diseñó así precisamente para que puedas depurar *"¿quién soy ahora?"* sin arriesgarte a un `AccessDenied` que te confunda.

---

## 6. AWS CLI v2: perfiles, config y credenciales

La **AWS CLI v2** es el cliente oficial moderno (la v1 está en soft-deprecation; usar siempre v2). Dos archivos clave:

- **`~/.aws/credentials`** — pares `aws_access_key_id` / `aws_secret_access_key` (y `aws_session_token` si son temporales). Un bloque por perfil:

  ```ini
  [default]
  aws_access_key_id = AKIAEXAMPLE
  aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

  [sandbox]
  aws_access_key_id = AKIAOTHER
  aws_secret_access_key = ...
  ```

- **`~/.aws/config`** — configuración por perfil (región, output, `role_arn`, SSO):

  ```ini
  [default]
  region = us-east-1
  output = json

  [profile sandbox]
  region = eu-west-1
  output = yaml

  [profile prod-admin]
  sso_start_url = https://miorg.awsapps.com/start
  sso_region = eu-west-1
  sso_account_id = 123456789012
  sso_role_name = AdministratorAccess
  region = eu-west-1
  ```

Nota la rareza: en `credentials` los perfiles son `[nombre]`; en `config` son `[profile nombre]` (excepto `default`). Es un detalle histórico.

### Precedencia de credenciales (de mayor a menor prioridad)

1. **Flags en línea** (`--profile`, `--region`).
2. **Variables de entorno** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_PROFILE`, `AWS_REGION`).
3. **Shared credential file** (`~/.aws/credentials`).
4. **Shared config file** (`~/.aws/config`).
5. **Container credentials** (ECS task role via metadata endpoint).
6. **Instance Metadata Service** (IMDS, para EC2 con instance profile — ver `aws-04`).

Conocer esta cadena es crucial para debug: si `aws sts get-caller-identity` muestra una identidad que no esperas, casi siempre es porque **una variable de entorno `AWS_*` olvidada** gana a tu perfil configurado.

### Comandos esenciales

```bash
aws configure --profile sandbox          # setup interactivo
aws configure sso --profile prod-admin   # setup SSO/Identity Center
aws sts get-caller-identity --profile sandbox
aws s3 ls --profile sandbox              # usar un perfil puntual
AWS_PROFILE=sandbox aws s3 ls            # vía env var
```

### IAM Identity Center (SSO) — el camino moderno

En vez de IAM users con access keys estáticas, la práctica moderna es **IAM Identity Center** (antes "AWS SSO"):

- Un **directorio de usuarios** central (o integrado con tu IdP corporativo).
- Un portal web que lista las cuentas y roles a los que cada usuario tiene acceso.
- `aws sso login --profile prod-admin` abre el navegador, autentica, y la CLI obtiene **credenciales temporales** por N horas, rotadas sin intervención.
- Cero access keys estáticas que puedan fugarse.

Este módulo usa IAM users como ejemplo *mínimo* (es más fácil de montar en una cuenta personal), pero la actividad 02 te empuja a documentar por qué SSO sería preferible.

---

## 7. Free Tier: tres tipos, no uno

El **AWS Free Tier** se vende como "gratis", pero son **tres cosas distintas** y conviene distinguirlas:

| Tipo | Qué incluye (ejemplos) | Caducidad | Trampa |
|------|-------------------------|-----------|--------|
| **12 meses gratis** | 750 h/mes de `t2.micro` o `t3.micro`, 5 GB de S3 Standard, 15 GB egress, 750 h de RDS `db.t2.micro`. | 12 meses desde que abres la cuenta. | Al mes 13 empieza a cobrar sin aviso. |
| **Always Free** | 1 M requests/mes de Lambda, 25 GB de DynamoDB, 10 GB de egress de CloudFront, SNS 1 M publishes. | Nunca caduca. | Pasarte del límite se cobra sin aviso previo. |
| **Trials** | Promociones de servicios específicos (p. ej. 2 meses gratis de Inspector, 30 días de GuardDuty). | Variable por servicio. | Caducan silenciosamente y empiezan a cobrar al día siguiente. |

**Cosas que NO están en Free Tier (y son fuente #1 de facturas sorpresa):**

- **NAT Gateway**: ~0.045 USD/h + 0.045 USD/GB procesado. **Siempre cobra.** Tener uno "olvidado" en una VPC te genera ~32 USD/mes solo por existir.
- **Elastic IPs no asociadas**: cobran por hora cuando **no** están attached a una instancia.
- **EBS snapshots** acumulados: se cobran por GB almacenado, muy barato pero acumulativo.
- **Egress a internet**: 100 GB gratis/mes a nivel global, luego ~0.09 USD/GB. Un microservicio chatty puede quemar esto rápido.
- **CloudWatch Logs**: ingest ~0.50 USD/GB + storage. Un `print("debug")` en loop es un cargo real.
- **Load Balancers idle**: ALB/NLB cobran por hora **aunque no sirvan tráfico**.

**Conclusión práctica:** el Free Tier **no es un seguro contra facturas**. El seguro contra facturas se llama **AWS Budgets con alertas** y lo configuras tú en §9.

---

## 8. Billing & Cost Management: qué miras y en qué orden

AWS expone tres superficies de billing que conviene no confundir:

### 8.1 Billing & Cost Management (consola)

El dashboard de facturación. Muestra:

- **Factura del mes en curso** (estimada) y de meses pasados.
- **Breakdown por servicio** (quién te está cobrando qué).
- **Credit balance** (créditos promocionales si tienes).
- Acceso a Budgets y Cost Explorer.

**Primera higiene**: habilitar *"IAM access to billing"* para que un rol delegado (no root) pueda ver la factura. Por default solo root ve billing.

### 8.2 AWS Budgets

**Alertas proactivas**. Defines un presupuesto (ej.: "no más de 50 USD/mes en total") y una regla de alerta (ej.: "avísame por email si llegas al 80 % del presupuesto o si la previsión supera el 100 %"). Es **la primera cosa que configuras en una cuenta nueva**, antes de provisionar nada.

Tipos de budget:

- **Cost budget**: dólares (lo que casi todos quieren).
- **Usage budget**: cantidad del recurso (ej. 100 GB de S3).
- **Reservation budget / Savings Plans budget**: tracking de utilización de descuentos reservados.

Alertas:

- Por email (hasta 10 destinatarios).
- Vía SNS → cualquier cosa (Lambda, Slack, PagerDuty).

Importante: Budgets **avisa**, no **frena**. Pasar del presupuesto no apaga nada. Si quieres apagado automático, lo construyes tú con una Lambda suscrita al tópico SNS que, por ejemplo, deshabilite autoscaling o apague EC2s.

### 8.3 Cost Explorer

**Análisis retrospectivo**. UI para explorar costos pasados por servicio, cuenta, tag, región, etc. Útil para:

- Entender *qué* ha subido este mes.
- Detectar recursos huérfanos (EBS orphans, snapshots viejos).
- Preparar un *rightsizing*.

Tiene su propia API (`ce:GetCostAndUsage`) que puedes consumir desde scripts.

### 8.4 Pricing Calculator

Herramienta pública (sin cuenta necesaria): `calculator.aws`. Modelas un workload (N EC2s de tipo X durante Y horas, Z GB de egress) y te da una **estimación mensual**. Es tu herramienta antes de proponer una arquitectura: *"¿cuánto va a costar esto si lo construimos así?"*

---

## 9. El runbook de cuenta nueva (orden exacto)

Este es el **orden** canónico de cosas que haces el día 1 de una cuenta AWS nueva, **antes** de provisionar nada:

1. **MFA en root**. Entras una vez con el email+password del root, vas a *My Security Credentials*, activas MFA (TOTP o hardware). Cierras sesión.
2. **Borrar access keys de root si existen**. En la misma pantalla. Si no hay, mejor.
3. **Habilitar "IAM access to Billing"** (consola de account settings). Permite que roles no-root vean la factura.
4. **Crear un presupuesto con alerta** (Budgets, email al grupo responsable). Un budget típico: 20 USD/mes con alerta al 50 %, 80 % y 100 % actual + previsión. **No provisiones nada antes de este paso.**
5. **Crear el acceso humano no-root**:
   - Opción minimal: IAM user con MFA + política `AdministratorAccess` + sin access keys estáticas (solo consola).
   - Opción recomendada: habilitar **IAM Identity Center** y crear un permission set `AdministratorAccess` asignado a un usuario del directorio.
6. **Cerrar sesión de root** y a partir de aquí trabajar con el humano no-root.
7. (Opcional pero muy recomendable) activar **CloudTrail** en todas las regiones para tener auditoría. Es Free Tier para el primer trail de management events.
8. (Opcional) **IAM Access Analyzer** habilitado para detectar accesos externos no previstos.

Si saltas los pasos 1-5 y vas directo a provisionar, estás un `secret_key` filtrado de distancia de minar bitcoin a tu costa.

---

## 10. Diagnóstico: identidad, región y perfil equivocado

Los 3 errores más comunes de principiantes con la CLI:

### 10.1 "No tengo permisos" cuando debería

```
An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied
```

Causas probables:

- Estás en el perfil equivocado. **Verifica con `aws sts get-caller-identity --profile X`.**
- Una variable de entorno `AWS_ACCESS_KEY_ID` olvidada está secuestrando tu perfil.
- Las access keys están rotadas / revocadas en consola.

### 10.2 "No encuentro el recurso" cuando lo acabas de crear

```
An error occurred (NoSuchBucket) when calling the HeadBucket operation
```

Casi siempre es **región equivocada**. Creaste el bucket en `eu-west-1` y la CLI está apuntando a `us-east-1`. Verifica con `aws configure get region --profile X` o pasa `--region` explícito.

### 10.3 "Cobra sin que yo haga nada"

Verifica en Cost Explorer. Causas típicas:

- NAT Gateway o Load Balancer olvidados.
- EBS volumes no attached pero no borrados.
- Snapshots acumulándose.
- CloudWatch Logs retention `Never Expire`.
- Un recurso que creaste en una región remota y no revisas (olvidar un `apply` en `ap-south-1`).

---

## 11. Herramientas de "cuenta sin AWS real": LocalStack y Terraform `plan`

Para este módulo (y para los primeros del curso) usaremos dos herramientas que te permiten practicar **sin coste y sin arriesgar** una cuenta real:

### 11.1 LocalStack

LocalStack simula una buena parte de los servicios de AWS en un contenedor Docker local. La AWS CLI (y Terraform, y los SDKs) apuntan a `http://localhost:4566` en vez de a `amazonaws.com` y creen que están hablando con AWS. Cubre S3, DynamoDB, SNS, SQS, Lambda, IAM (parcial), STS, EC2 (parcial), y más.

Para `sts get-caller-identity` basta:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url=http://localhost:4566 sts get-caller-identity
```

Devuelve `arn:aws:iam::000000000000:user/test` o similar. Suficiente para aprender la mecánica del comando.

**Limitaciones:**

- No todos los servicios están ni todos sus features.
- Billing, Budgets, Organizations, Identity Center **no** están (o están muy simplificados). Para esos, los ejercicios se quedan en Terraform `plan` o documento escrito.

### 11.2 Terraform `plan` sin `apply`

Terraform acepta **credenciales ficticias** si solo haces `plan` sin `apply`. Puedes modelar un `aws_budgets_budget`, un `aws_sns_topic`, un `aws_iam_user`, y leer el plan completo — es un ejercicio de leer el *shape* del recurso sin crear nada. **No** apliques nunca con credenciales reales en este módulo.

---

## 12. Puente a los siguientes módulos

A partir de aquí, cada módulo del curso **asume** que la cuenta está en el estado del runbook del §9: root blindado, admin humano con MFA, presupuesto con alerta.

El próximo módulo (`aws-02 — IAM Fundamentals`) te enseña **cómo** se construye el admin humano con permisos mínimos, cómo son las políticas JSON, qué es un rol, qué es STS en detalle, y por qué los access keys son el *smell* número uno de auditoría. A partir de `aws-03` (VPC) empieza a aparecer infra que **sí** cuesta dinero, y el presupuesto que creas en este módulo es tu red de seguridad.

**Si no has hecho la actividad 02 de este módulo (MFA en root + admin user), no continúes al siguiente módulo.** Es la única actividad del curso declarada como **obligatoria pre-cualquier-otra-cosa**.
