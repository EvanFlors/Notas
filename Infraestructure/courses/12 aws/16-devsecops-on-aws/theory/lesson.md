# aws-16 — Lección: DevSecOps en AWS

> 12 secciones. **Sin despliegues reales**. Prerrequisitos: `aws-02`, `aws-10`, `aws-11`, `aws-15`. Cursos **github-actions** y **docker** Nivel 4.

---

## 1. El principio: cero access keys humanas

Antes de hablar de servicios, el principio: **ninguna persona ni pipeline debería necesitar un `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` de larga duración**. La razón es trivial de enunciar y difícil de aplicar:

- Toda key larga es un secreto que **vive en algún sitio** (Vault, 1Password, GitHub Secrets, el `.aws/credentials` de alguien).
- Ese "sitio" tiene su propia superficie de ataque, su propia rotación (que no se hace), su propia audit trail (que nadie mira).
- El día de la fuga, la pregunta "¿quién tenía esta key?" no tiene respuesta rápida.

Las alternativas modernas son todas la **misma idea**: una identidad **ya autenticada** (un workflow de GitHub Actions con su JWT firmado por GHA, un Pod de EKS con su ServiceAccount, un rol IAM asumido por otro rol) hace `AssumeRole*` y obtiene **credenciales de 1 hora o menos**. Si la credencial fuga, el daño es acotado y el blast radius es rastreable en CloudTrail.

Este módulo recorre esas alternativas: **OIDC federation** para pipelines, **IRSA / Pod Identity** para workloads EKS, **IAM roles for EC2** (ya cubierto en `aws-02`), y **Secrets Manager rotation** para las credenciales que **sí** son inevitables (DB passwords).

---

## 2. OIDC federation GitHub Actions → AWS

### 2.1 El flujo

GitHub Actions emite, para cada job que pide `permissions.id-token: write`, un **JWT firmado por GitHub** (`token.actions.githubusercontent.com`). Ese token contiene *claims* como:

- `iss`: `https://token.actions.githubusercontent.com`
- `sub`: `repo:owner/repo:ref:refs/heads/main` (o `repo:owner/repo:environment:prod`, o `repo:owner/repo:pull_request`)
- `aud`: por defecto `sts.amazonaws.com` cuando usas la action oficial
- `repository`, `job_workflow_ref`, `actor`, ...

AWS acepta ese JWT vía `sts:AssumeRoleWithWebIdentity` si:

1. Existe un **IAM OIDC Identity Provider** en la cuenta con `url = https://token.actions.githubusercontent.com` y el *thumbprint* del certificado (AWS calcula el thumbprint automáticamente desde 2023, pero sigue siendo requerido en el recurso).
2. Existe un **IAM Role** cuya `trust policy` tiene `Principal.Federated = <ARN del OIDC provider>`, `Action = sts:AssumeRoleWithWebIdentity`, y una `Condition` que pinnea claims.

Flujo end-to-end:

```
   GHA job (permissions.id-token: write)
       │
       │  1. requiere OIDC token
       ▼
   token.actions.githubusercontent.com  ──► JWT firmado
       │
       │  2. action aws-actions/configure-aws-credentials@v4
       ▼
   sts:AssumeRoleWithWebIdentity (JWT + RoleArn)
       │
       │  3. AWS valida firma + condition
       ▼
   credenciales STS (AccessKey + Secret + SessionToken) — 1 h por defecto
       │
       ▼
   job hace llamadas AWS normales
```

### 2.2 El pinning del `sub` claim: la frontera de seguridad

Una `trust policy` **mal escrita** permite que *cualquier* repo de GitHub asuma tu rol:

```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:*"
    }
  }
}
```

Esto es equivalente a tener una password pública. Cualquier atacante que cree un repo público puede obtener un JWT con `sub: repo:atacante/malware:ref:refs/heads/main` y asumir tu rol.

La policy **correcta** pinnea `sub` a un **repo exacto** y a un **ref exacto** (branch, tag o environment):

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:miorg/mirepo:ref:refs/heads/main"
    }
  }
}
```

**Reglas prácticas** para escribir el `sub`:

| Caso de uso | `sub` recomendado |
|-------------|-------------------|
| Deploy desde main | `repo:ORG/REPO:ref:refs/heads/main` |
| Deploy desde tag `v*` | `repo:ORG/REPO:ref:refs/tags/v*` (usa `StringLike`) |
| Deploy desde un GitHub Environment protegido | `repo:ORG/REPO:environment:prod` |
| PR previews | `repo:ORG/REPO:pull_request` (**scope mínimo**: solo lectura, nunca deploy) |

**Patrón recomendado**: un rol por **environment × repo**. `role-github-actions-mirepo-prod` solo lo puede asumir el environment `prod` del repo `mirepo`. Esto reduce el blast radius de una fuga de token a "lo que ese environment puede hacer".

### 2.3 Dos errores típicos

1. **Usar `StringLike` cuando quieres `StringEquals`.** `StringLike` interpreta `*` como wildcard; `StringEquals` no. Si pones `"sub": "repo:miorg/mirepo:*"` con `StringLike`, cualquier branch (incluyendo PRs de forks) matchea. Casi nunca es lo que quieres.
2. **Olvidar la condición de `aud`.** Si solo pinneas `sub`, un token con `aud` arbitrario asumido por otra integración podría colarse. `aud = sts.amazonaws.com` cierra ese flanco.

---

## 3. IRSA y Pod Identity en EKS

Dos modelos AWS-nativos para que un **Pod** obtenga credenciales IAM sin tocar access keys.

### 3.1 IRSA (IAM Roles for Service Accounts)

Modelo clásico, GA desde 2019. Mecanismo:

- Cada cluster EKS expone un **OIDC provider** (`oidc.eks.<region>.amazonaws.com/id/<cluster-id>`) que firma JWTs para cada ServiceAccount.
- Creas un **IAM OIDC Identity Provider** apuntando a ese URL en la cuenta.
- Creas un **IAM Role** con `trust policy` que acepta `AssumeRoleWithWebIdentity` **si** el `sub` del JWT es `system:serviceaccount:<namespace>:<serviceaccount>`.
- Anotas la ServiceAccount con `eks.amazonaws.com/role-arn = <ARN del role>`.
- El Pod monta el token proyectado (`AWS_WEB_IDENTITY_TOKEN_FILE`) y el AWS SDK hace el `AssumeRoleWithWebIdentity` transparentemente.

Es el mismo patrón que OIDC-GHA, pero con el OIDC provider del cluster como emisor.

### 3.2 Pod Identity (nuevo)

Modelo nuevo (lanzado 2023, cada vez más regiones). Mecanismo:

- Instalas el addon `eks-pod-identity-agent` en el cluster. Es un DaemonSet que corre un servidor local en `169.254.170.23`.
- Creas una `aws_eks_pod_identity_association` que vincula `(cluster, namespace, serviceaccount) → role_arn`.
- El SDK consulta `169.254.170.23` como si fuera IMDS; recibe credenciales temporales.

### 3.3 ¿Cuál elegir?

| Dimensión | IRSA | Pod Identity |
|-----------|------|--------------|
| Antigüedad | GA 2019 | GA 2023 |
| OIDC provider por cluster | Sí (uno) | **No** necesario |
| Cambiar rol de SA sin recrear Pod | Hay que recrear | **Sí** (editas la association) |
| Trust policy por rol | Específica del cluster (OIDC provider del cluster) | **Genérica** (`pods.eks.amazonaws.com`) |
| Soporte multi-cluster | Un rol por cluster | **Un rol** reusable en varios clusters |
| Compatibilidad regional | Todas | Verificar en Fase 4 (algunas regiones faltan) |
| Compatibilidad K8s | Todas las versiones soportadas | Verificar — nuevas versiones mejor |

**Recomendación práctica**: para **nuevos** clusters y nuevas cargas, **Pod Identity**. Para clusters existentes con IRSA ya en producción, **no migrar por migrar** — IRSA sigue soportado. Para workloads que necesitan asumir el mismo rol desde varios clusters (p. ej. una plataforma compartida), Pod Identity es claramente superior.

> **Checklist Fase 4**: confirmar matriz de compatibilidad regional de Pod Identity y versiones mínimas de EKS, pueden haber cambiado.

---

## 4. Secrets Manager con rotación automática

Las passwords de bases de datos **son** secretos de larga duración. No se pueden eliminar; solo se pueden **rotar**.

### 4.1 Mecánica

- Creas un `aws_secretsmanager_secret` para la DB credential.
- Creas un `aws_secretsmanager_secret_rotation` que apunta a una **Lambda rotator** y define `rotation_rules.automatically_after_days` (p. ej. 30).
- AWS provee **Lambda rotators oficiales** para RDS (MySQL, Postgres, Oracle, SQL Server, MariaDB) desde el AWS Serverless Application Repository.
- La Lambda implementa 4 pasos definidos por Secrets Manager: `createSecret`, `setSecret`, `testSecret`, `finishSecret`. Cada paso es idempotente — si falla a mitad, Secrets Manager reintenta sin dejar el secreto en estado inconsistente.

### 4.2 Costo

- Secret: ~$0.40/mes por secreto almacenado.
- API: $0.05 por 10,000 llamadas.
- Lambda rotator: su propio costo (invocaciones + duración), despreciable para rotación mensual.

### 4.3 Patrón recomendado

- **Nunca** poner una DB password en un `aws_db_instance.password` hardcodeada o en una variable de GHA.
- La app lee la password **en runtime** desde Secrets Manager via SDK con `GetSecretValue`.
- El permiso `secretsmanager:GetSecretValue` lo da el **IRSA/Pod Identity role** del workload — no una access key.

---

## 5. ECR scanning: básico vs enhanced

ECR tiene dos niveles de scanning de vulnerabilidades, con costos y profundidad distintos.

### 5.1 Basic scanning (gratis)

- Usa la CVE DB de **Clair** (CoreOS).
- Scan **on push** o manual.
- Resultados vía `aws ecr describe-image-scan-findings`.
- **Costo: $0** (solo pagas el storage de ECR, que es $0.10/GB-mes).
- Limitaciones: no detecta vulnerabilidades en librerías de lenguaje (pip, npm, Go modules), solo paquetes de OS. No continuo (si una CVE nueva aparece después del push, no se reescanea).

### 5.2 Enhanced scanning (Inspector v2)

- Se activa a nivel de cuenta/región.
- **Continuo**: cuando aparece una CVE nueva, reescanea las imágenes existentes.
- Detecta vulnerabilidades en **librerías de lenguaje** (Python, JS, Java, Go, .NET, Ruby).
- Findings van también a **Security Hub** y pueden disparar EventBridge.
- **Costo (verificar en Fase 4, estos son valores de referencia 2024-2025)**:
  - Container image scanning: **~$0.09 por imagen por mes** (continuo).
  - On-push scan: incluido.
- Es la opción recomendada para producción. En desarrollo/sandbox, basic suele bastar.

### 5.3 Patrón de gate en pipeline

```
build ──► docker push ──► wait for scan ──► describe-image-scan-findings
                                                     │
                                                     ▼
                           count(CRITICAL + HIGH) > 0 ?
                                     │
                                     ├─ sí  ──► fail job, bloquea deploy
                                     └─ no  ──► deploy
```

El `wait for scan` es importante: push y scan son asíncronos. Hay que esperar a que `imageScanStatus.status == "COMPLETE"` antes de pedir findings. Con enhanced, el scan es más rápido (y continuo), pero el patrón sigue aplicando.

### 5.4 Trivy local como pre-check

Independiente de ECR scanning, es buena práctica correr **Trivy** (open source, de Aqua) **antes** del push. Trivy escanea la imagen local, falla rápido y no genera costo en AWS. ECR scanning queda como la segunda red (y la red *continua*).

---

## 6. GuardDuty, Config, Security Hub — la trinidad "siempre encendida"

### 6.1 GuardDuty

- **Qué hace**: detección de amenazas basada en findings. Analiza **VPC Flow Logs, DNS logs, CloudTrail management + data events, EKS audit logs, S3 data events, RDS auth logs**.
- **Qué detecta**: tipos de findings documentados — p. ej. `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS`, `Recon:EKS/MaliciousIPCaller`, `CryptoCurrency:EC2/BitcoinTool.B!DNS`, etc.
- **Activación**: por región, un click. En organización, desde la cuenta `security-tooling` se delega la administración.
- **Costo (referencia)**: proporcional a los eventos ingeridos. VPC Flow Logs ~$1-5/GB. CloudTrail events ~$4 por millón. Para una cuenta pequeña, decenas de dólares/mes; para una grande, cientos a miles. **Verificar en Fase 4**.

### 6.2 Config

- **Qué hace**: *configuration recording*. Registra snapshots de todos los recursos AWS y mantiene un histórico de cambios. Evalúa recursos contra **rules** (built-in o custom con Lambda).
- **Conformance packs**: colecciones de rules alineadas a NIST, PCI, CIS, HIPAA. Un conformance pack son ~50-200 rules que se activan juntas.
- **Costo (referencia)**: $0.003 por configuration item + $0.001 por evaluación de regla. Suena barato; con decenas de miles de recursos y rules activas, llega a cientos de dólares/mes.
- **Patrón DevSecOps**: encendido en todas las cuentas, delegado a `security-tooling`, con conformance pack mínimo (CIS AWS Foundations).

### 6.3 Security Hub

- **Qué hace**: agregador central de findings de GuardDuty, Inspector, Macie, Config, IAM Access Analyzer, y third-party. Un **dashboard único** de postura de seguridad.
- **Standards**: CIS AWS Foundations, AWS Foundational Security Best Practices, PCI DSS. Son estándares de **compliance** evaluados automáticamente a partir de findings.
- **Costo**: ~$0.0010 por check + ~$0.00003 por finding ingerido. Como agregador, el costo real lo generan los productores (GuardDuty, Config).

### 6.4 Patrón de activación

En una organización bien construida (`aws-15` + `aws-17`), estos tres servicios están **encendidos por defecto en todas las cuentas**, delegados a `security-tooling`, con findings consolidados en Security Hub. En este módulo **no desplegamos nada** — documentamos y razonamos.

---

## 7. Firma de imágenes con cosign y verificación en EKS

### 7.1 El problema

ECR scanning te dice "esta imagen no tiene CVEs conocidas". No te dice "esta imagen la construyó mi pipeline oficial". Un atacante que logre `docker push` a tu ECR (con una key filtrada o un path lateral) puede subir una imagen limpia pero **suya**.

La firma criptográfica cierra ese hueco: la imagen lleva una **signature** adjunta en el registry; antes de ejecutarla en EKS, un **admission controller** verifica que la firma es válida y la **identidad del firmante** es la pipeline oficial.

### 7.2 cosign (sigstore)

Herramienta estándar de facto. Dos modos:

- **Key-based**: generas un par `cosign.key` / `cosign.pub` y firmas con la privada. Tienes que custodiar la privada (p. ej. en KMS). Patrón más tradicional.
- **Keyless (OIDC)**: no hay key persistente. La identidad OIDC del firmante (p. ej. el JWT de GHA) se usa para firmar; la firma + un certificado efímero + un log transparente (**Rekor**) se publican. La verificación chequea que la identidad OIDC del firmante sea `repo:miorg/mirepo` en el ref correcto.

**Keyless es la opción recomendada** para pipelines CI porque no hay secretos que custodiar. Encaja perfectamente con OIDC-GHA.

### 7.3 Verificación en EKS: policy-controller vs Kyverno

Dos opciones de admission controller para verificar firmas:

| Dimensión | sigstore policy-controller | Kyverno |
|-----------|---------------------------|---------|
| Scope | Específico sigstore (verifica firmas) | General (verifica/muta cualquier policy K8s) |
| Instalación | Helm chart propio | Helm chart propio |
| Expresividad | ClusterImagePolicy (específico) | ClusterPolicy (muy expresivo) |
| Si solo quieres verificar firmas | **Más simple** | Más potente |
| Si ya usas Kyverno para otras policies | — | **Reutilizas** |

### 7.4 Flujo end-to-end

```
   GHA pipeline (OIDC)
       │
       │  1. docker build
       │  2. docker push → ECR
       │  3. cosign sign --keyless <image>
       │       (firma + sube a Rekor)
       ▼
   ECR (imagen + signature + attestation)
       │
       ▼
   kubectl apply → admission webhook (policy-controller / Kyverno)
       │
       │  verifica firma + identidad OIDC del firmante
       │  (debe ser repo:miorg/mirepo:ref:refs/heads/main)
       ▼
   admit / deny
```

---

## 8. AWS Security Reference Architecture (SRA)

El SRA es un documento oficial de AWS que recomienda un **layout de cuentas** y la ubicación de cada control de seguridad. Es prescriptivo y bueno.

Resumen operativo (compatible con lo que se cubre en `aws-15` y `aws-17`):

- **Management account**: solo billing y Organizations. **Nada más**. Nunca workloads.
- **Log archive account**: destino de CloudTrail organizacional, Config aggregator, logs de VPC Flow, logs de EKS audit. Bucket S3 con *object lock* y acceso restringido.
- **Security tooling account**: cuenta donde se delegan GuardDuty, Security Hub, Macie, Inspector, Config, IAM Access Analyzer. Centraliza findings.
- **Workload accounts** (dev/stg/prod): aquí viven las apps. Reciben las policies por SCP desde la OU.

Este módulo no construye el SRA — eso es `aws-15` y `aws-17`. Pero las decisiones DevSecOps **asumen** que esta separación existe.

---

## 9. IAM Access Analyzer, Macie, WAF — mención breve

- **IAM Access Analyzer**: analiza recursos (S3 buckets, IAM roles, KMS keys, Lambda, SQS, Secrets Manager) y detecta **external access** no intencionado. Genera findings cuando un recurso es accesible desde fuera de la cuenta/org. **Costo: $0** para análisis básico; "unused access analyzer" tiene costo por recurso analizado.
- **Macie**: descubre datos sensibles (PII, financial) en S3. Costo proporcional a GB analizados (~$1-5 por GB; verificar).
- **WAF**: web application firewall para ALB, CloudFront, API Gateway, AppSync. Reglas managed (OWASP Top 10) y custom. Costo: ~$5 por web ACL/mes + ~$1 por regla + ~$0.60 por millón de requests.

Ninguno se despliega en este módulo. Se mencionan para que sepas dónde encajan.

---

## 10. Trade-offs: cuándo *no* aplicar cada control

Un pipeline DevSecOps bien pensado **elige** qué controles aplicar según el contexto.

| Control | Cuándo *sí* | Cuándo *puede esperar* |
|---------|-------------|------------------------|
| OIDC GHA (sin keys) | **Siempre.** No hay excusa en 2025. | Nunca, es gratis y hoy. |
| IRSA / Pod Identity | Siempre que haya un workload EKS que llame AWS APIs. | Si tu Pod no llama AWS (puro HTTP interno), no es necesario. |
| Secrets Manager rotation | DB passwords en producción. | Credenciales de servicios SaaS externos (no soporta rotación nativa). |
| ECR basic scanning | **Siempre.** Gratis. | Nunca, es gratis. |
| ECR enhanced (Inspector) | Producción, imágenes con muchas dependencias de lenguaje. | Sandbox personal, imágenes raramente ejecutadas. |
| GuardDuty | **Siempre** en cuentas con workloads. | Sandbox puro sin datos. |
| Config + conformance pack | Compliance (PCI, HIPAA, SOC2) o cuentas con datos sensibles. | Cuenta puramente experimental sin datos ni acceso externo. |
| Cosign + admission | Producción, especialmente si hay riesgo de supply-chain. | Dev clusters efímeros. |
| WAF | Edge expuesto a internet con riesgo real. | Backends internos puros. |
| Macie | S3 con datos de usuarios o PII. | S3 solo con artifacts de build. |

El error típico es **encender todo porque sí** sin medir el costo. GuardDuty + Config + Security Hub + Macie en una cuenta grande pueden llegar a **miles de dólares/mes**. La decisión tiene que ser consciente.

---

## 11. Auditar un pipeline existente

Checklist para auditar un pipeline con lupa DevSecOps:

1. **¿Hay `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` en secrets?** Si sí, migra a OIDC. Es la primera línea.
2. **¿La `trust policy` del IAM Role pinnea `sub` a repo + ref?** Si usa `StringLike` con wildcards, es un hallazgo crítico.
3. **¿La `aud` está pinneada a `sts.amazonaws.com`?** Si falta, hallazgo medio.
4. **¿El workflow pide `permissions.id-token: write` solo en el job que lo necesita?** Si está global, `permissions:` debería estar por job.
5. **¿Hay un `cosign sign` tras el `docker push`?** Si no, no hay verificación posible en admisión.
6. **¿El `docker push` espera al scan y falla por severidad?** Si el deploy no espera findings, el scan es decorativo.
7. **¿Las imágenes vienen de un base image fijado por digest (`FROM alpine@sha256:...`) o por tag mutable (`FROM alpine:latest`)?** El tag mutable es un hallazgo alto.
8. **¿El Pod en EKS usa IRSA/Pod Identity o monta un `Secret` con access keys?** Monta de keys = hallazgo crítico.
9. **¿Las DB passwords vienen de Secrets Manager con rotación activa?** Si están en una `Secret` K8s estática, hallazgo alto.
10. **¿Hay WAF delante del ingress público?** Si no y hay internet, hallazgo medio.

Esta checklist es exactamente lo que vas a aplicar en la evaluación final del módulo.

---

## 12. Repítelo hasta que suene aburrido

- **Cero access keys humanas.** OIDC, IRSA, Pod Identity, Secrets Manager rotation. No hay plan B.
- **El `sub` claim pinneado es la frontera de seguridad del OIDC.** Pinnealo a `repo:ORG/REPO:ref:refs/heads/main` o a `:environment:prod`, nunca a `repo:*`.
- **Scan on push + gate en pipeline + firma + verificación en admisión** es la cadena mínima de supply-chain. Si falta algún eslabón, la cadena no vale.
- **GuardDuty, Config, Security Hub** se delegan a `security-tooling`, no se encienden por cuenta a mano.
- **El costo importa.** Enhanced scanning, Config conformance packs y GuardDuty en una cuenta grande son cientos a miles de dólares/mes. La decisión es consciente, no por defecto.

Ahora las dos actividades: construir el pipeline OIDC desde cero (actividad 01) y añadir el gate de ECR scanning (actividad 02). **Sin desplegar en AWS**. Terraform `validate`, Checkov/Trivy local y ADRs razonados.
