# Examen de certificación — Curso AWS

- **Curso:** `courses/aws`
- **Nivel evaluado:** intermedio-avanzado (cubre `aws-02` a `aws-17`, con base en `aws-01..05`).
- **Dimensiones:** conceptual + operativa + arquitectónica (`todas`).
- **Duración total:** 90–120 min.
- **Umbral de aprobación:** 70%.
- **Modalidad:** take-home con validación en vivo (follow-ups).
- **Entorno de validación:** `LocalStack` **o** `terraform plan` offline. **No** se evalúa en una cuenta AWS real; si no hay LocalStack disponible, los ejercicios operativos se validan con `terraform validate` + `terraform plan` y lectura estática del código.
- **Account IDs:** usa siempre `123456789012` (y `210987654321` para cross-account). Cualquier ID real se considera `red flag`.
- **Prosa en español, código/CLI en inglés.**

## Distribución de puntos

| Dimensión | Peso |
|-----------|------|
| Conceptual (Q1–Q13) | 35% |
| Operativa (`operative/`) | 35% |
| Arquitectónica (`architectural/scenario.md`) | 30% |

Mínimo por dimensión: 50% (no se puede compensar un cero en operativa con exceso en conceptual).

---

## Sección 1 — Preguntas conceptuales (35%)

Respuestas cortas, 3–8 líneas salvo que se indique otra cosa. **No** se evalúa recordar nombres de flags; se evalúa el *por qué*.

### Q1 — Evaluación de políticas IAM (C1) [peso 4]

Una cuenta `210987654321` pertenece a una OU con esta SCP:

```json
{
  "Effect": "Deny",
  "Action": "s3:*",
  "Resource": "*",
  "Condition": {"StringNotEquals": {"aws:RequestedRegion": "us-east-1"}}
}
```

El rol `data-engineer` en esa cuenta tiene adjunta `AmazonS3FullAccess` y una **permission boundary** que permite `s3:GetObject` y `s3:ListBucket` sólo sobre `arn:aws:s3:::reports-*`. El bucket `reports-prod` está en `eu-west-1` y tiene una **bucket policy** que hace `Allow s3:GetObject` al rol.

¿Qué puede hacer el rol? Explica el orden de evaluación y por qué.

### Q2 — Qué pasaría si… (C1) [peso 3]

En el escenario de Q1, el administrador de la cuenta `210987654321` agrega `AdministratorAccess` al rol. ¿Cambia algo respecto a `reports-prod`? Justifica.

### Q3 — OIDC trust policy para GitHub Actions (C2) [peso 4]

Un junior propone este trust policy para que GitHub Actions despliegue a AWS:

```json
{
  "Effect": "Allow",
  "Principal": {"Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"},
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"}
  }
}
```

Explica **qué le falta** y por qué, en términos del claim `sub` y de superficie de ataque. Da un ejemplo de condición `sub` correctamente pinneada para `main` del repo `acme/platform` y para el env `prod`.

### Q4 — SG vs NACL + endpoints (C3) [peso 3]

Diferencia Security Group vs NACL en: statefulness, orden de reglas y granularidad (instance vs subnet). Después responde: ¿por qué un **Gateway Endpoint** a S3 es gratis pero un **Interface Endpoint** a Secrets Manager cobra por hora + por GB? ¿Qué cambia en tu factura si rutas tráfico a S3 por NAT vs por Gateway Endpoint?

### Q5 — IMDSv1 vs IMDSv2 (C4) [peso 3]

Una app corriendo en EC2 tiene un endpoint vulnerable a SSRF que permite al atacante hacer `GET http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>`. Explica qué obtiene el atacante con IMDSv1 habilitado y por qué IMDSv2 (session token obligatorio) mitiga el ataque pero **no** lo elimina. ¿Qué controles adicionales recomendarías?

### Q6 — KMS key policy vs IAM policy (C5, C12) [peso 3]

Un rol tiene `kms:Decrypt` en su identity policy, pero al descargar un objeto cifrado con una CMK en otra cuenta recibe `AccessDenied`. ¿Dónde está el problema? Explica envelope encryption en 2–3 líneas y describe qué debe decir la **key policy** de la CMK para que el rol pueda descifrar.

### Q7 — ALB vs NLB vs CloudFront (C6) [peso 3]

Tres escenarios. Elige y justifica (ALB, NLB o CloudFront + origin):

1. API HTTPS pública que requiere routing por path y auth con Cognito.
2. Servicio TCP interno expuesto a otra VPC vía PrivateLink con IP estática.
3. SPA estática servida globalmente desde S3 con TLS en `app.example.com`.

Para el caso 3, ¿en qué región **debe** emitirse el certificado ACM y por qué?

### Q8 — IRSA vs Pod Identity (C7) [peso 3]

Explica cómo un pod en EKS obtiene credenciales IAM temporales con **IRSA** (OIDC + token projection) y con **EKS Pod Identity** (agente). ¿Cuándo preferirías Pod Identity? ¿Qué pasa si olvidas crear el OIDC provider en IAM al usar IRSA?

### Q9 — Herencia de permisos del nodo (C8) [peso 2]

Un pod sin IRSA ni Pod Identity termina pudiendo leer un bucket S3 que *no* debería. ¿Por qué puede pasar esto en EKS? Describe la causa raíz y la mitigación mínima.

### Q10 — Observabilidad y costo (C9) [peso 3]

Un equipo tiene 2 TB/mes de logs en CloudWatch Logs con retención infinita y alarmas que disparan email cada minuto para cada 5xx. Describe 3 cambios concretos que reduzcan factura **sin** perder señal, y explica por qué anomaly detection + composite alarms es mejor que alarmas estáticas para APIs con estacionalidad.

### Q11 — SCP baseline (C10) [peso 3]

Diseña (en pseudocódigo o lista) 4 SCPs baseline para una Organization de 5 cuentas, y explica qué invariante protege cada una. Al menos una debe prevenir "disable logging" y otra debe acotar regiones.

### Q12 — Envelope encryption en profundidad (C12) [peso 2]

¿Por qué KMS no cifra directamente el payload? ¿Qué pasa cuando una app descifra 100 GB desde S3 con SSE-KMS: cuántas llamadas a `kms:Decrypt` se hacen y por qué?

### Q13 — Factura sorpresa (C14) [peso 2]

Un cliente ve $2,400/mes inesperados. La cuenta tiene: 6 NAT Gateways (uno por AZ en 2 regiones), VPC Flow Logs a CloudWatch con retención de 365 días, y CloudTrail con data events habilitados para 20 buckets S3. Nombra los 3 drivers probables ordenados por impacto y la primera acción para cada uno.

---

## Sección 2 — Ejercicio operativo (35%)

Ver `operative/README.md`. Tareas:

- **OP-task-1:** Terraform de bucket S3 seguro + validación `terraform plan` + comprobación LocalStack opcional.
- **OP-task-2:** Auditar y corregir un pipeline GitHub Actions → AWS (trust policy OIDC, secretos, imagen).
- **OP-task-3:** Diseñar y entregar política de retención/filtrado de CloudWatch Logs + alarma composite para la app del capstone.

Validación automática en `operative/validate.sh` (los tres pasos deben ejecutarse sin red externa a AWS real).

---

## Sección 3 — Ejercicio arquitectónico (30%)

Ver `architectural/scenario.md`. Entregable: diseño + ADR + diagrama (ascii o mermaid) + tabla de trade-offs + presupuesto estimado.

---

## Rúbrica resumen (ver detalle por ejercicio en `operative/` y `architectural/`)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---------|------------------|------------|----------------|-------------|
| **Corrección técnica** | Respuesta incorrecta o inventada | Idea general correcta con errores de detalle | Correcta y defendible | Correcta + anticipa casos límite y los descarta con criterio |
| **Justificación / razonamiento** | "Porque sí" o cita de doc sin entender | Nombra el concepto pero no lo aplica al caso | Conecta concepto → consecuencia → decisión | Compara al menos 2 alternativas y descarta con trade-off medible |
| **Seguridad** | Introduce un `red flag` (ver matriz) | Omite controles obvios (BPA, MFA, pinning) | Aplica least-privilege y defaults seguros | Modela amenaza explícita (STRIDE/attack path) |
| **Costo (cuando aplica)** | Ignora costo o afirma falsamente que "es gratis" | Menciona driver sin cuantificar | Estima orden de magnitud correcto | Propone alternativa con ahorro cuantificado y trade-off |
| **Operabilidad / IaC** | Clicks en consola; sin Terraform | TF que `plan`ea pero no `validate` | TF idempotente, módulos, variables tipadas | TF con tests smoke / `terraform plan` reproducible + diff review |

Umbral de aprobación global: **70%**, con mínimo **50%** en cada una de las tres dimensiones.

---

## Guía de corrección (instructor-only)

### Respuestas modelo — Sección 1

**Q1.** `AccessDenied`. Orden: (1) SCP evaluada primero sobre la cuenta → `Deny` para cualquier `s3:*` fuera de `us-east-1`; `reports-prod` está en `eu-west-1` → **cortado aquí**. Aunque la bucket policy permita y la permission boundary permita y la identity policy permita, un `Deny` explícito gana sobre cualquier `Allow`, y un `Deny` en SCP no se puede sobrescribir. Debe nombrar: default deny → union de allows → explicit deny gana → SCP acota lo que las identity policies pueden conceder (no concede nada por sí mismo). *Parcial:* dice "no puede" sin explicar el rol de la SCP (1pt). *Experto:* señala que la bucket policy sola tampoco salvaría porque la SCP opera sobre el principal de la cuenta origen.

**Q2.** No cambia nada. `AdministratorAccess` es una identity policy; la SCP sigue denegando. Debe decir explícitamente "SCP no concede, acota" y que `AdministratorAccess` ya era redundante con lo que la boundary + SCP permiten.

**Q3.** Falta pinnear `sub`. Sin eso, **cualquier** workflow de **cualquier** repo que use ese provider puede asumir el rol. Ejemplo correcto:

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
  "token.actions.githubusercontent.com:sub": "repo:acme/platform:environment:prod"
}
```

Alternativa para branch: `"repo:acme/platform:ref:refs/heads/main"`. *Red flag:* usar `StringLike` con `*` sobre `sub`. *Experto:* menciona el `aud` ya está, pero `sub` sin pinnear equivale a access-key compartida con todo GitHub.

**Q4.** SG: stateful (respuesta vuelve automáticamente), evaluado como conjunto allow-only, aplica a ENI. NACL: stateless (regla de retorno explícita), evaluada en orden por `rule_number`, permite deny, aplica a subnet. Gateway Endpoint (S3/DynamoDB): se implementa como entrada en route table, no hay ENI, no cobra. Interface Endpoint: ENI por AZ + resolución DNS, cobra ~$0.01/h por AZ + por GB. Impacto: ruta por Gateway Endpoint evita cargo NAT (~$0.045/GB) y lo cambia por $0 (más la hora del endpoint, pero el endpoint por sí mismo es gratis).

**Q5.** Con IMDSv1: `GET` directo retorna el JSON con `AccessKeyId`/`SecretAccessKey`/`Token`; el atacante los exfiltra y asume el rol. Con IMDSv2: necesita primero `PUT /latest/api/token` con `X-aws-ec2-metadata-token-ttl-seconds` y header, y SSRF que sólo hace GET falla. Mitiga pero **no** elimina: si la vuln permite métodos arbitrarios o si la app proxea el `PUT`, el ataque reaparece. Controles extra: `http_endpoint = enabled`, `http_tokens = required`, `http_put_response_hop_limit = 1` (bloquea contenedores que intenten saltar), network egress restringido, mínimo privilegio en el instance profile.

**Q6.** La IAM policy no basta: también necesita permiso en la **key policy** de la CMK (la key policy es *resource-based* sobre la clave; en cross-account es obligatoria además de la IAM). Envelope encryption: KMS genera una data key, cifra el payload con la data key (local, rápido), y cifra la data key con la CMK; el objeto cifrado viaja con la data key cifrada. Para descifrar, hace falta `kms:Decrypt` sobre la CMK + la key policy debe incluir al rol/cuenta en `Principal` con esa acción.

**Q7.** (1) ALB (L7, path, Cognito OIDC integration). (2) NLB (L4, static IP, única opción productora para PrivateLink). (3) CloudFront + S3 origin con OAC. ACM debe estar en **`us-east-1`** porque CloudFront es servicio global y sólo lee certs de `us-east-1`.

**Q8.** IRSA: SA anotada con role ARN; webhook muta el pod con proyección del service account token; el pod llama `sts:AssumeRoleWithWebIdentity` usando el OIDC provider de EKS (hay que crearlo en IAM, apuntando al issuer URL del cluster) y la trust policy del rol valida el `sub` del token (`system:serviceaccount:<ns>:<sa>`). Pod Identity: un agente DaemonSet escucha requests "IMDS-like" del pod en `169.254.170.23`, consulta a EKS por el role mapping del SA y devuelve credenciales. Pod Identity: cuando no quieres mantener un OIDC provider por cluster, cuando necesitas cambiar de rol sin recrear el SA, o soporte multi-rol más limpio. Si falta OIDC provider en IRSA: `AssumeRoleWithWebIdentity` falla con `InvalidIdentityToken`.

**Q9.** El pod hereda las credenciales del **node IAM role** vía IMDS del host; si el nodo tiene permisos amplios, cualquier pod sin IRSA/Pod Identity los usa. Mitigación: bloquear acceso de pods a IMDS (`http_put_response_hop_limit=1` en el launch template o políticas de red), y aplicar IRSA/Pod Identity para dar permisos **por workload**, dejando el node role con el mínimo (CNI, ECR pull, logs).

**Q10.** (a) Aplicar retention por log group (p. ej. 30 días en apps, 400 días en auditoría); (b) metric filter para extraer sólo lo que alimenta alarma + subscription a S3/Glacier para auditoría barata; (c) **composite alarm** que combine 5xx-rate + latency P99 (reduce ruido) y **anomaly detection** para APIs con estacionalidad (p. ej. tráfico diurno). Alarma por minuto por cada 5xx = fatiga + sin contexto; composite + anomaly dispara cuando la señal se separa del baseline.

**Q11.** Ejemplos aceptables (al menos 4):

- `DenyRegions`: deny `*` fuera de `us-east-1`/`eu-west-1` con `aws:RequestedRegion`.
- `DenyLeaveOrg`: deny `organizations:LeaveOrganization`.
- `DenyDisableLogging`: deny `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, `config:DeleteConfigurationRecorder`, `config:StopConfigurationRecorder`.
- `DenyRootUser`: deny `*` cuando `aws:PrincipalArn` es root de cualquier cuenta member.
- `DenyIAMUserCreation`: deny `iam:CreateUser` / `iam:CreateAccessKey` (fuerza SSO).

**Q12.** KMS tiene throughput y tamaño limitado (4 KB por operación directa); envelope evita el round-trip por byte. En descarga S3 SSE-KMS de 100 GB: típicamente **1** `kms:Decrypt` por objeto para desencriptar la data key; esa data key luego desencripta el objeto localmente. Si son 100 objetos: ~100 llamadas (ojo cuota `kms:Decrypt`).

**Q13.** (1) NAT Gateways: 6 × ~$32/mes fijo + $0.045/GB → auditar con VPC Flow Logs qué se puede mover a VPC endpoints (S3, DynamoDB, ECR, Logs). (2) VPC Flow Logs 365d en CW: reducir retention + mover histórico a S3 con lifecycle a Glacier. (3) CloudTrail data events S3: cobrar por evento, cortar a buckets sensibles o mover a trails selectivos; para el resto, Basic management events (gratis).

### Correción del ejercicio operativo

Ver `operative/README.md` sección "Rúbrica" y `operative/validate.sh` para los checks automáticos.

### Correción del ejercicio arquitectónico

Ver `architectural/scenario.md` sección "Rúbrica" y "Puntos clave que debe tocar el ADR".

### Señales de "respondió sin entender"

- Copia-pega de un ejemplo con `account-id` o nombre de bucket del material sin adaptar.
- Repite el nombre del servicio como respuesta ("CloudFront es un CDN" no explica *por qué* ACM debe estar en us-east-1).
- Dice "least privilege" sin mostrar la política.
- Trust policy con `*` en `sub` justificado como "para desarrollo".
- Diagrama de VPC sin indicar AZs ni route tables.
- Estimación de costo sin unidades (`"es caro"`).

### Preguntas de seguimiento (live)

- "Si te dicen que la SCP de Q1 debe permitir *leer* desde `eu-west-1` sólo para `data-engineer`, ¿cómo lo harías sin perder el guardrail global?"
- "Enséñame cómo validarías tu trust policy antes de mergearlo: ¿qué logs mirarías en CloudTrail después del primer run?"
- "Si Pod Identity está disponible, ¿por qué podrías aun así preferir IRSA?" (señales: ya tengo OIDC compartido con otra identidad federada, portabilidad entre non-EKS clusters, maturity de módulos TF).
- "En Q13, antes de borrar nada, ¿qué chequearías para no romper compliance?"
- "Me enseñas tu trust policy del OP-task-2 y me dices qué pasa si cambio el `sub` por el de un fork?"
- "En el escenario arquitectónico, ¿qué parte del diseño caería primero si la cuenta `log-archive` se cae?"

### Red flags (instant-fail la respuesta implicada)

Ver `competency-matrix.yaml` → `red_flags`. Resumen de los más críticos:

1. Access keys IAM humanas / de pipeline.
2. Trust policy OIDC sin `sub` pinneado.
3. Account IDs reales en el entregable.
4. `"Action":"*"` + `"Resource":"*"` sin justificación.
5. S3 sin Block Public Access.
6. Workload role con `AdministratorAccess` o `cluster-admin`.
7. Secretos hardcodeados (en TF, user-data, task definitions o repo).
8. `cosign verify --insecure-ignore-tlog`.
