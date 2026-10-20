# sec-03 — Lección: panorama de scanning (SAST, DAST, SCA, IaC, container, secret, CSPM)

> 12 secciones. 100 % conceptual + taxonomía. Prerrequisito: `sec-01`.

---

## 1. Punto de partida: por qué hablamos de "panorama"

Cuando un equipo decide "poner seguridad en el pipeline", suele caer en una de dos trampas:

1. **Trampa del single-tool**: contratan Snyk (o Datadog Security, o GitHub Advanced Security) y asumen que *ese producto* cubre todo. No cubre. Ninguno cubre.
2. **Trampa del shotgun**: enchufan 7 scanners distintos sin política ni owner, el CI tarda 40 min, los dashboards tienen miles de hallazgos **Critical** sin triage, y nadie los mira. En la práctica, nada se arregla.

El **panorama** existe porque el software moderno es **multicapa**:

```
   ┌────────────────────────────────────────────────────┐
   │  Repositorio (código fuente, IaC, secrets)          │  ← SAST, secret, IaC
   │  Dependencias (requirements.txt, package.json)      │  ← SCA
   │  Imagen (Dockerfile, base image + layers)           │  ← container, SBOM
   │  Despliegue (K8s manifests, Helm charts)            │  ← IaC
   │  Servicio corriendo (HTTP, gRPC)                    │  ← DAST
   │  Cuenta cloud (IAM, S3, VPC, SecurityGroups)        │  ← CSPM
   └────────────────────────────────────────────────────┘
```

Cada capa tiene **su propio tipo de riesgo** y **su propio tipo de scanner**. Un SAST no mira dependencias. Un SCA no mira si `requests.get()` tiene timeout. Un DAST no mira si `S3Bucket.PublicAccessBlockConfiguration` está desactivado. Entender el panorama es entender qué pregunta responde cada scanner.

> **Idea clave que repetiremos:** cada scanner es un **sensor especializado**. Ponerlos juntos construye una **imagen compuesta**; usar uno solo te deja ciego a varias capas.

---

## 2. Las 7 categorías de un vistazo

| Categoría | Qué mira | Cuándo corre | Herramienta canónica | FP típicos |
|-----------|----------|--------------|----------------------|------------|
| **SAST** | código fuente (patrones peligrosos, taint) | pre-commit, PR, CI | Semgrep, CodeQL, Bandit | regex sin dataflow confunde contextos; marca código test |
| **DAST** | servicio corriendo (fuzz, probes HTTP) | staging, nightly | OWASP ZAP, Burp | depende de credenciales/estado; FP por rutas no autenticadas |
| **SCA** | dependencias (CVEs de 3P) | PR, CI, nightly | Trivy, Grype, Snyk | CVE marcado pero el path vulnerable no se usa |
| **IaC scanning** | HCL/YAML/CloudFormation (misconfig) | pre-commit, PR, CI | Checkov, Trivy config, tfsec | reglas CIS que no aplican a tu modelo de amenaza |
| **container scanning** | imagen (OS + lang packages + misconfig) | build, registry push | Trivy, Grype, Clair | base image heredando CVEs no explotables |
| **secret scanning** | código y git history (claves filtradas) | pre-commit, CI, push protection | gitleaks, trufflehog, GH secret scanning | dummy keys en tests, ejemplos de documentación |
| **CSPM (cloud posture)** | estado de la cuenta cloud | continuo | Prowler, Steampipe, Config, Security Hub | reglas CIS vs reglas de la organización |

Pequeño mapa mental:

```
   [código fuente] ──► SAST
   [dependencies]  ──► SCA
   [config IaC]    ──► IaC scanning
   [imagen OCI]    ──► container scanning
   [git history]   ──► secret scanning
   [app running]   ──► DAST
   [cuenta cloud]  ──► CSPM
```

En el resto de la lección cada categoría tiene su propia sección (§3–§9).

---

## 3. SAST — Static Application Security Testing

**Qué es.** Análisis del **código fuente sin ejecutarlo**. Busca patrones peligrosos (`eval()` sobre input de usuario, SQL concatenada, `subprocess.run(..., shell=True)`), llamadas a APIs criptográficas débiles (`md5`, `DES`), y, en los scanners más avanzados, **flujo de datos** (`taint analysis`): un dato marcado como "no confiable" (input HTTP) llega sin pasar por un sanitizer a un sink peligroso (SQL, shell, HTML).

**Herramientas canónicas.**

- **Semgrep**: reglas declarativas en YAML (patrón-sintáctico multi-lenguaje). Rápido, OSS, registry público (`r/python.flask.security`, `r/javascript.lang.security`), extremadamente fácil escribir reglas custom. Ideal para **reglas de dominio de tu organización** (p. ej. "no `requests.get` sin `timeout=`").
- **CodeQL** (GitHub). Trata el código como una **base de datos** sobre la que se escriben consultas en un lenguaje tipo SQL/Datalog. Incluye **dataflow** y **taint tracking**. Más potente, más lento, requiere un `codeql-analyze` que compila el proyecto. Integración nativa en GitHub como "Code Scanning".
- **Bandit** (Python): reglas canónicas de seguridad en Python. Simple, muy ruidoso en código real.
- **Snyk Code** (comercial): similar enfoque, dataflow + ML.

**Dónde corre.** Pre-commit (reglas rápidas), PR check (completo), nightly (full history diff).

**Qué NO ve.** Vulnerabilidades que solo existen en **runtime** (desencadenadas por entrada específica), CVEs en librerías de 3P (eso es SCA), misconfigs en IaC (eso es IaC scanning).

**Fundamento interno.** SAST **sin dataflow** marca cualquier `.format(user_input)` como posible SQL injection — tiene **mucho FP** porque no sabe si `user_input` viene de un controlador HTTP o de un string literal. SAST **con dataflow** (CodeQL) sigue el camino desde `source` hasta `sink` y reduce FP drásticamente, a costa de ser 10×–100× más lento y requerir configuración.

---

## 4. DAST — Dynamic Application Security Testing

**Qué es.** El scanner **habla con el servicio corriendo**. Hace probes HTTP, fuzz de inputs, intentos de inyección (`'; DROP TABLE--`, `../../etc/passwd`), prueba configuraciones TLS, mira headers de seguridad (`Content-Security-Policy`, `X-Frame-Options`). No ve el código.

**Herramientas canónicas.**

- **OWASP ZAP** (OSS): proxy + spider + fuzzer. Modo baseline (pasivo), modo full (activo, lanza ataques). Pensado para integrarse en CI contra una app en staging.
- **Burp Suite** (comercial): el estándar de pentesting manual + modo scanner. Más caro, más potente.
- **Nuclei** (ProjectDiscovery): templates YAML de CVEs conocidos y misconfigs, muy rápido.

**Dónde corre.** Contra un **entorno levantado** (nightly contra staging; en PR contra una preview environment efímera). **No** se puede correr contra producción sin cuidado — un fuzzer activo puede tirar el servicio.

**Qué NO ve.** Vulnerabilidades que no se disparan sin **estado o credenciales específicas**. Un DAST sin autenticarse ni ver carrito de compra lleno **no** detecta una IDOR en `/order/{id}` entre usuarios distintos.

**Fundamento interno.** DAST es "**el ataque externo que no sabe nada del código**". Es la mejor forma de encontrar lo que SAST se perdió por limitaciones de modelo, pero requiere **un entorno vivo** y **tiempo real de ejecución** (minutos a horas). Por eso casi nunca corre en PR gate; corre nightly o pre-release.

---

## 5. SCA — Software Composition Analysis

**Qué es.** Lista las dependencias de tu proyecto (`requirements.txt`, `package.json`, `go.mod`, `pom.xml`, `Cargo.toml`) y las cruza contra una **base de datos de CVEs** (NVD, GitHub Advisory, OSV, GitLab Advisory DB). Reporta "esta versión de `requests` tiene CVE-2024-XXXX, severidad HIGH".

**Herramientas canónicas.**

- **Trivy** (Aqua, OSS): multi-propósito; para SCA hace `trivy fs .` o `trivy image <img>`. Lee lockfiles de todos los lenguajes mayores.
- **Grype** (Anchore, OSS): foco en imágenes y repos; integra con **Syft** para SBOM.
- **Snyk** (comercial): base de datos propietaria con enriquecimiento, muy popular en PR comments.
- **Dependabot / Renovate**: no son scanners estrictos — son *bots que abren PRs* para subir versiones. Complementan al scanner.

**Dónde corre.** PR check (bloquear nueva dependencia vulnerable), CI (release gate), nightly (CVEs publicados **después** de merge — tu código no cambió pero el mundo sí).

**Qué NO ve.** CVEs cuyo **path vulnerable no se usa** desde tu código — todas las herramientas básicas marcan la librería, no si tu código llama a la función afectada. **Reachability analysis** (Snyk, Endor, Semgrep SSC) intenta responder esto, aún joven.

**Fundamento interno.** La mayoría de hallazgos SCA en una app típica son **CVEs en dependencias transitivas** de las que ni sabías. La fuente de verdad **no es NVD solo** — NVD tarda semanas en indexar CVEs; **OSV** y **GitHub Advisory** suelen tener primero. Tener múltiples fuentes reduce falsos negativos.

---

## 6. IaC scanning

**Qué es.** Mira **Terraform (HCL)**, **CloudFormation (YAML/JSON)**, **Kubernetes manifests**, **Helm charts**, **Dockerfile**, **ARM**, buscando **misconfigs**: `S3Bucket` público, `SecurityGroup` abierto a `0.0.0.0/0:22`, `Pod` sin `securityContext`, `runAsRoot: true`, `latest` tag, falta de `limits`.

**Herramientas canónicas.**

- **Checkov** (Bridgecrew/Prisma Cloud, OSS): soporta TF, CFN, K8s, Dockerfile, ARM, Helm, Serverless. Policies built-in + custom en Python o Rego. Mapping a CIS, PCI-DSS, HIPAA.
- **Trivy config**: subset de IaC scanning, muy rápido, misma base de reglas que `tfsec` (fusionados).
- **tfsec** (ahora dentro de Trivy): en modo mantenimiento.
- **Terrascan** (Tenable): basado en OPA/Rego.
- **KICS** (Checkmarx): similar enfoque, extensa cobertura.

**Dónde corre.** Pre-commit (reglas rápidas sobre HCL), PR (sobre HCL **y** sobre `terraform plan -out tfplan && terraform show -json tfplan`), CI release gate.

**Fundamento interno.** HCL **puro** tiene incognitas: `region = var.region` no se puede evaluar sin saber el valor. El **plan JSON** ya resolvió variables, data sources y locals — tiene valores concretos. **IaC scanning sobre el plan es más preciso** (menos FP, detecta regresiones por cambios en data sources). El scanning sobre HCL crudo es útil como gate rápido pre-plan.

---

## 7. Container scanning

**Qué es.** Toma una **imagen OCI** y la analiza en tres ejes:

1. **CVEs de OS packages** (`apt`, `apk`, `yum`): "Debian bookworm trae `openssl` con CVE-X".
2. **CVEs de language packages** copiados dentro de la imagen (`site-packages` de Python, `node_modules`).
3. **Misconfig de la imagen misma**: `USER root`, puertos expuestos innecesarios, secretos olvidados en layers.

**Herramientas canónicas.**

- **Trivy image**: `trivy image <imagen>` — scanner multi-fuente, formato tabla/JSON/SARIF.
- **Grype**: igual pero de Anchore.
- **Clair**: antes muy popular, hoy menos.
- **Docker Scout**: integrado en Docker Desktop.

**Dónde corre.** Build (post `docker build`), push al registry (webhook), nightly contra imágenes ya desplegadas (CVEs nuevas sobre imagen vieja), **admisión K8s** (admission controller con Trivy Operator).

**Fundamento interno.** Base images "slim" (debian-slim, python:3.12-slim) acumulan **menos CVEs** porque incluyen menos paquetes. **Distroless** (gcr.io/distroless) y **Chainguard** son el siguiente paso: imagen mínima **sin shell, sin paquete manager**, sin fallback para debugging — reduce dramáticamente la superficie, pero complica el troubleshooting. **Actualizar la base image es casi siempre más barato que parchar un CVE puntual**.

---

## 8. Secret scanning

**Qué es.** Busca **patrones de credenciales** en código y en el **git history**: `AKIA[0-9A-Z]{16}` (AWS access key), `ghp_[A-Za-z0-9]{36}` (GitHub PAT), `-----BEGIN PRIVATE KEY-----` (clave privada), tokens Slack/Stripe/Twilio con prefijos específicos.

**Herramientas canónicas.**

- **gitleaks**: reglas regex + entropy. Rápido, muy popular en pre-commit.
- **trufflehog**: similar + capacidades de **verificación activa** (intenta usar el secret contra el provider para confirmar si está vivo).
- **GitHub Secret Scanning**: gratis en repos públicos; con **Advanced Security** en privados. **Push protection** bloquea el push si detecta un secret conocido.
- **detect-secrets** (Yelp): simple, baseline-based.

**Dónde corre.** Pre-commit (bloquear antes del commit), CI (**sobre toda la historia** — borrar un archivo con un secret **no** lo quita de la historia de Git), push protection (bloquear antes de que llegue al remote).

**Fundamento interno.** Una vez un secret está en la historia de Git, **se asume *leaked*** (lo clonaron, lo cachearon, lo indexaron). Purgar la historia (BFG, `git filter-repo`) reduce exposición futura pero **no cambia** que ese secret fue público. **La rotación del secret es irrevocable**: rotar primero, limpiar segundo.

---

## 9. CSPM — Cloud Security Posture Management

**Qué es.** Scanner que mira **el estado efectivo** de tu cuenta cloud (AWS, GCP, Azure) y evalúa contra benchmarks (CIS AWS, PCI-DSS, NIST). "Hay un bucket S3 público", "hay un IAM user con `AdministratorAccess` sin MFA", "hay una VPC sin flow logs".

**Herramientas canónicas.**

- **Prowler** (OSS): CLI que corre cientos de checks CIS. AWS, GCP, Azure.
- **Steampipe** (Turbot, OSS): expone APIs cloud como **tablas SQL** — queries declarativas sobre tu infra ("select buckets where public_access_enabled = true").
- **AWS Config** + **Security Hub** (nativos): checks continuos, caros a escala.
- **Wiz, Prisma Cloud, Lacework** (comerciales enterprise): CSPM + CNAPP (graph de riesgo).

**Dónde corre.** Nightly contra la cuenta; continuo si usas Config/Security Hub.

**Diferencia con IaC scanning.** IaC mira **lo que vas a aplicar** (preventivo). CSPM mira **lo que está aplicado** (detectivo). Son **complementarios**: IaC previene regresiones; CSPM detecta drift y recursos creados fuera de pipeline (ClickOps).

---

## 10. Severidad: CVSS, EPSS, KEV

El error más común en política de scanning es "fallar en CRITICAL+HIGH, pasar lo demás". Suena razonable; **no lo es**. CVSS mide una cosa, EPSS otra, KEV otra. Usarlas combinadas es lo que distingue una política madura.

### 10.1 CVSS (Common Vulnerability Scoring System)

Score de **0 a 10** que mide la **severidad teórica** de una vulnerabilidad: facilidad de explotación (vector), privilegios requeridos, impacto en C/I/A (confidencialidad/integridad/disponibilidad). Mantenido por FIRST.

```
    None     Low     Medium   High   Critical
     0.0    0.1–3.9  4.0–6.9 7.0–8.9 9.0–10.0
```

**Fortaleza:** estándar, universal, calculable a partir del vector.
**Debilidad:** mide **potencial**, no **realidad**. Un CVSS 9.8 en una librería que nadie usa es menos urgente que un CVSS 6.5 en una que está en el camino caliente de tu API pública.

### 10.2 EPSS (Exploit Prediction Scoring System)

Score **de 0 a 1** (probabilidad) que FIRST publica diariamente, basado en datos reales: menciones en exploit-db, actividad en honeypots, discussion en foros. Predice la **probabilidad de que una vulnerabilidad sea explotada en los próximos 30 días**.

- EPSS 0.95 en un CVE CVSS 6.5 → **urgente** (alta probabilidad de ataque real).
- EPSS 0.001 en un CVE CVSS 9.8 → importante, no quemado.

### 10.3 KEV (Known Exploited Vulnerabilities)

Catálogo mantenido por **CISA** con las CVEs que han sido **efectivamente explotadas en el mundo real**. Es un **sí/no** binario, no un score.

- Si una CVE está en KEV, es la **señal más fuerte** de que hay que remediar ya — alguien está siendo atacado con ella *ahora*.

### 10.4 Cómo combinarlos

```
   urgency = f(CVSS, EPSS, KEV, exposición_del_sistema)

   Regla práctica:
   - CVE en KEV y expuesto externamente       → P0, remediar en 24–72 h
   - CVSS Critical AND EPSS > 0.5             → P1, remediar en 7 días
   - CVSS High                                 → P2, remediar en 30 días
   - CVSS Medium AND EPSS < 0.01 AND no-KEV   → P3, backlog con SLA 90 días
   - CVSS Low                                  → informativo, acumular para batch
```

La **exposición** importa: una CVE en un servicio interno sin ingress no es lo mismo que la misma CVE en el API gateway.

---

## 11. Señal vs ruido: triage es el trabajo

Un scanner recién instalado en un repo mediano produce fácil **200–2000 hallazgos** la primera corrida. **Si todos son P0, ninguno es P0**. El trabajo real es:

1. **Baseline inicial**: marcar como "aceptado hoy" todo lo que no vas a arreglar esta semana (con fecha de expiración). Esto convierte el ruido histórico en un `.gitleaks.toml` / `.trivyignore` / `.semgrepignore` **documentado** y auditable.
2. **Política por severidad**: lo nuevo falla el PR si entra en la banda que la política marque como bloqueante. Lo viejo no se arregla por decreto; se arregla por *roadmap*.
3. **Dashboard de "tendencia", no "total"**: el número que importa es "cuántos hallazgos **nuevos** entraron esta semana", no "cuántos hallazgos **existen**".
4. **Owner por capa**: SAST → equipo de la app; SCA → mismo + plataforma; IaC → plataforma; CSPM → cloud ops. Si no hay owner, no hay fix.

Dos reglas pedagógicas:

- **"Si tu dashboard tiene miles de Criticals y no te asustas, tu dashboard no está midiendo lo que crees"**. Probablemente el 95 % son FP, dependencies transitivas no explotables, o ruido legacy.
- **"Un scanner bien tuneado con 20 hallazgos reales > scanner default con 2000 hallazgos ruidosos"**. Es mejor cobertura baja + alta precisión que lo contrario.

---

## 12. Suppressions vs exceptions

Hay dos formas de "ignorar" un hallazgo. **No son equivalentes.**

### 12.1 Suppression (silenciar un FP)

El hallazgo **no es un riesgo real**. Es un falso positivo del scanner:

- Regla de Semgrep que detecta `eval()` pero es `ast.literal_eval()` (seguro).
- CVE en dependencia que tu código no llama.
- Dummy key en `tests/fixtures/`.

Marcadores típicos:

```python
foo = eval(blob)  # nosemgrep: python.lang.security.audit.eval-detected
```

```
# .trivyignore
CVE-2023-99999  # not reachable: fn X never called from app
```

**Reglas**:

- Comentario con **razón concreta** (no "FP").
- Idealmente **expiración** o re-review periódico — las bases cambian; algo que era FP puede dejar de serlo.

### 12.2 Exception (aceptar un riesgo real con proceso)

El hallazgo **es un riesgo real**, pero **ahora no se arregla** por una razón explícita (coste, dependencia upstream sin fix, roadmap). Esto **no** es un FP — es una **decisión de negocio**.

Debe tener:

- **Justificación técnica**: por qué no se arregla ahora.
- **Compensating control**: qué mitiga el riesgo mientras tanto (WAF rule, network policy, feature flag off, etc.).
- **Owner**: quién responde cuando esto explote.
- **Expiración**: fecha concreta a la que vuelve a aparecer. **Sin expiración es deuda invisible**.
- **Approver**: no el mismo que lo introdujo; separation of duties.

Formato ejemplar (ver `examples/03-exception-policy-sample/`):

```yaml
- id: EXC-2026-007
  cve: CVE-2024-12345
  severity: HIGH
  justification: >
    Upstream fix pendiente (libfoo 2.4.1 ETA Q2 2026).
    No podemos bumpear a 2.5 por breaking changes.
  compensating_control: WAF rule 'block-foo-vector' habilitada
  owner: team-platform
  approver: ciso
  expires_at: 2026-06-30
```

### 12.3 Lo que NO es aceptable

- `# noqa` sin comentario.
- `.trivyignore` vacío de razones.
- Suppression **global** ("ignorar HIGH en todo el repo durante este sprint").
- Exception **sin fecha**.

> Un hallazgo silenciado sin razón ni expiración es un hallazgo que **nadie va a arreglar jamás** — y es por donde entra el próximo incidente.

---

## Cierre

El panorama de scanning es ancho (**siete categorías**), pero cada categoría responde a **una pregunta distinta**. Elegir herramientas sin entender esto lleva al single-tool o al shotgun. La **política de severidad** (CVSS + EPSS + KEV + exposición) es el mecanismo que convierte miles de hallazgos ruidosos en una **cola priorizada accionable**. **Suppressions** y **exceptions** son dos herramientas distintas con reglas distintas — confundirlas es cómo nacen las "cuentas de ignore" que esconden deuda.

En los siguientes módulos vamos a **instalar y correr** los scanners (`sec-04` secrets, `sec-05` SCA/container con Trivy, `sec-06` SAST, `sec-07` IaC). Pero sin este mapa mental, cada scanner se siente aislado. **Volvé a esta lección** si en algún momento no sabés "a qué categoría pertenece lo que estoy mirando".
