# sec-14 — Lección: platform patterns, gates, DX, inventory y vuln mgmt lifecycle

> 10 secciones. Mayoritariamente conceptual. Prerrequisitos: `sec-05`, `sec-09`, `sec-11`, `sec-13`.

---

## 1. El cambio de encuadre: de "scanners sueltos" a "plataforma con contrato"

Los módulos anteriores dejaron en pie **cada herramienta**: Trivy escanea CVEs, Semgrep y CodeQL hacen SAST, Checkov hace IaC, Kyverno gatea admisión, Vault custodia secretos. Si se dejan como *scanners sueltos* sin orquestación, el equipo de producto vive una experiencia muy mala:

- cada scanner con su propia UI y su propia severidad;
- un hallazgo "High" en Trivy puede ser inexplotable mientras un "Medium" en Semgrep es exfiltración directa;
- se suprime en el `.trivyignore` *ad hoc*, sin TTL, sin aprobador;
- cuando sale un CVE nuevo, nadie sabe qué servicios lo cargan: horas de investigación manual grep en Dockerfiles.

El cambio de encuadre es tratar DevSecOps como **plataforma con contrato explícito**. La plataforma expone:

- Un pipeline de referencia ("golden path") que **ya trae todos los gates**.
- Un contrato que dice **qué bloquea el merge** y qué solo informa.
- Un **inventario** (SBOM store) que responde preguntas de todo el fleet.
- Un **proceso** de vuln management con SLA tiers y MTTR como SLO.
- Un canal de **excepciones** con approver + TTL + auditoría.

> **Idea clave:** la seguridad no se "aplica" al producto; se **expone como plataforma**. Los equipos consumen una experiencia, no se enfrentan a 7 scanners.

---

## 2. Gates como contrato: blocking, warn, nightly

No todos los controles merecen el mismo tratamiento. Un error común es poner **todo como blocking**: el pipeline falla por un *Medium* en una dependencia transitiva que ni siquiera se carga, y los equipos aprenden a `--ignore-all`. El contrato distingue tres categorías:

### 2.1 Blocking (fail the build)

- Secret scanning: encuentra un secreto real en el diff → **fail**. No negociable.
- CVE **Critical** con **exploit activo (KEV)** o **EPSS alto**: fail salvo excepción vigente.
- Firma: imagen no firmada por un *identity* permitido → fail en admisión (no en CI).
- SBOM: no se generó → fail (la plataforma necesita el SBOM para el inventario).
- Policy as code (OPA/Rego): violaciones `deny` en IaC plan → fail.

### 2.2 Warn (annotate, do not fail)

- CVE High sin KEV y EPSS medio: anotar en el PR, no bloquear.
- SAST con confidence media: anotar.
- Base image desactualizada <30 días: anotar.
- Deuda de supresiones próximas a expirar (<14 días): anotar.

### 2.3 Nightly / out-of-band

- Full history secret scan.
- CodeQL deep queries.
- Baseline rescan de todas las imágenes publicadas (CVE DB cambia a diario).
- Drift de policies: comparar policies desplegadas vs. git.

**Regla de oro:** si no bloquea el merge, no cuenta como "gate" — cuenta como **telemetría**. Y cada *blocking* gate debe tener un **nombre** y un **responsable** del contrato.

---

## 3. Política de severidad: CVSS, EPSS, KEV

CVSS puro es engañoso como *gating signal*. Mide **severidad teórica**: cuán malo sería *si* fuera explotable. No dice **si alguien está explotándolo**.

- **CVSS v3.1**: 0.0–10.0; Critical ≥ 9.0, High 7.0–8.9, Medium 4.0–6.9, Low 0.1–3.9.
- **EPSS** (Exploit Prediction Scoring System, FIRST): 0–1; probabilidad de que la CVE sea explotada en los próximos 30 días. Un CVSS 9.8 con EPSS 0.001 es poco urgente; un CVSS 7.0 con EPSS 0.95 es incendio.
- **KEV** (Known Exploited Vulnerabilities, CISA): catálogo *curado* de CVEs **ya explotadas en el mundo real**. Si está en KEV, es prioridad absoluta.

### Umbral recomendado (ejemplo)

| Condición                                      | Acción       | SLA     |
|------------------------------------------------|--------------|---------|
| En KEV                                         | **Blocking** | 24 h    |
| CVSS ≥ 9.0 y EPSS ≥ 0.5                        | **Blocking** | 24 h    |
| CVSS ≥ 7.0 y EPSS ≥ 0.1                        | **Blocking** | 7 d     |
| CVSS ≥ 7.0 y EPSS < 0.1                        | Warn         | 30 d    |
| CVSS 4.0–6.9                                   | Warn         | 90 d    |
| CVSS < 4.0                                     | Info         | next release |

> Esta tabla es **ejemplo**; cada organización ajusta sus umbrales según perfil de riesgo. Lo importante es que los umbrales están **escritos** y son **auditables**.

---

## 4. Exception policy formal

Sin un canal explícito, las excepciones toman atajos: `.trivyignore` con una línea sin fecha, un `# nosec` sin autor, un `kyverno exclude` eterno. Esto es cómo las excepciones se vuelven *regla implícita* y la plataforma pierde valor de señal.

La exception policy formal exige, por cada excepción:

- **ID único** (trazabilidad).
- **Finding ID** (CVE, regla Semgrep, policy violada).
- **Scope** (servicio/imagen/ruta específica, nunca "wildcard global").
- **Justificación técnica** (p.ej. "clase vulnerable no se carga: la ruta `AuthManager.decrypt_legacy` está muerta y verificable con coverage").
- **Compensating control** si aplica (WAF rule, feature flag).
- **Approver** nominado (security eng o security champion del equipo).
- **TTL** (fecha de expiración; max 90 días por defecto).
- **Revisor** al expirar.
- **Trazabilidad**: la excepción vive en el **repo** (`exceptions/EX-123.yaml`), no en el `.gitignore`.

Al expirar: el pipeline vuelve a bloquear automáticamente. No existe la "excepción permanente" — si realmente lo es, cambia la política.

---

## 5. SBOM como inventario (asset DB / CMDB-lite)

Un SBOM aislado por imagen es poco útil cuando sale un CVE nuevo. Un SBOM **publicado a un store centralizado** y **indexado** convierte la pregunta "¿quién corre log4j 2.14?" en una **query**.

### 5.1 El contrato de publicación

Cada build **genera y publica** su SBOM (CycloneDX JSON) a un store. Opciones típicas:

- **Dependency-Track** (OSS, OWASP): base de datos + UI con alertas automáticas cuando una CVE afecta a un proyecto.
- **GUAC** (Graph for Understanding Artifact Composition, OpenSSF): grafo que une SBOM + provenance + firmas.
- **Snyk / Mend / Dependency-Health**: comerciales.
- **Caso mínimo**: un bucket S3 + tabla Postgres indexada por `(service, image_digest, package, version)`.

### 5.2 Schema mínimo (CMDB-lite)

```sql
CREATE TABLE sbom_component (
    service_name    TEXT NOT NULL,
    image_digest    TEXT NOT NULL,   -- sha256:...
    package_name    TEXT NOT NULL,
    package_version TEXT NOT NULL,
    package_type    TEXT NOT NULL,   -- 'os' | 'lang:python' | 'lang:go' | ...
    first_seen      TIMESTAMPTZ NOT NULL,
    last_seen       TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (image_digest, package_name, package_version)
);
CREATE INDEX idx_component ON sbom_component (package_name, package_version);
```

### 5.3 La pregunta canónica

```sql
-- Cuando sale CVE-2024-XXXXX en openssl 3.0.x:
SELECT DISTINCT service_name
FROM sbom_component
WHERE package_name = 'openssl'
  AND package_version LIKE '3.0.%';
```

De horas de grep manual a **milisegundos**. Esa es la diferencia entre "sabemos qué tenemos" y "lo averiguamos después".

> **Idea clave:** SBOM es **inventario** (qué hay); provenance es **historia** (cómo se construyó). Son complementarios, no sustitutos.

---

## 6. Vuln management lifecycle

El ciclo tiene 6 etapas; cada una tiene owner y métrica:

```
┌─────────┐   ┌────────┐   ┌────────────┐   ┌─────────────┐   ┌────────┐   ┌────────┐
│ detect  │ → │ triage │ → │ prioritize │ → │ remediate   │ → │ verify │ → │ report │
└─────────┘   └────────┘   └────────────┘   └─────────────┘   └────────┘   └────────┘
   scan        is it           SLA tier       patch / fix       re-scan     metrics
   result      real?          (sec 3)         / exception       passes      & trends
```

### 6.1 Detect

Fuentes: pipeline scanners (per PR), nightly baseline scan (todas las imágenes publicadas), SBOM-driven alerting (nueva CVE afecta a X servicios en el store), bug bounty, pentest.

### 6.2 Triage

¿Es real? ¿Afecta a la ruta de código ejecutada? ¿La versión instalada es realmente la vulnerable? Dueño: security champion del equipo (no "el equipo de seguridad" como caja negra).

### 6.3 Prioritize

Aplica la política de severidad (sección 3). Resultado: un **tier** (Critical/High/Medium/Low) y una **SLA deadline**.

### 6.4 Remediate

Patch, upgrade, migración de base image, excepción con compensating control. Owner: **el equipo producto**, no seguridad (seguridad **asiste**, no **ejecuta**).

### 6.5 Verify

Rescan prueba que la vulnerabilidad desapareció. Test de regresión si procede.

### 6.6 Report

Métricas (sección 7) alimentan dashboards. Trends mensuales. Review quarterly con leadership.

---

## 7. Métricas DevSecOps (SLOs, no vanity)

Sin métricas no hay plataforma: hay una lista de buenas intenciones.

| Métrica                                   | Fórmula                                              | SLO ejemplo |
|-------------------------------------------|------------------------------------------------------|-------------|
| MTTR por tier                             | `AVG(fixed_at - detected_at)` por tier               | Crit ≤ 24 h |
| % imágenes firmadas (del fleet)           | `signed_images / total_images`                       | ≥ 99 %      |
| % builds con todos los gates verdes       | `green_builds / total_builds`                        | ≥ 90 %      |
| % cobertura de SBOM                       | `images_with_sbom / total_images`                    | 100 %       |
| Backlog crítico abierto                   | `COUNT(open_findings WHERE tier=Critical)`           | = 0         |
| Tiempo medio de feedback (p95)            | `p95(pipeline_duration_seconds)`                     | ≤ 10 min    |
| Excepciones expiradas sin revisar        | `COUNT(exceptions WHERE expired_at < now())`         | = 0         |

**MTTR** por tier es la métrica *reina*. Un MTTR Crit de 48 h con SLO 24 h es más procesable que "tenemos 12 CVEs". Fuerza conversaciones concretas.

---

## 8. Developer experience: la plataforma debe ser *amable*

Si los equipos *odian* el pipeline, lo esquivan: `[skip ci]`, forks sin gates, builds locales que *parecen* passing. Principios de DX:

- **Feedback <10 min** p95. Si el pipeline tarda 40 min, los PRs se acumulan y la gente deja de leer el output.
- **Mensajes accionables**: "fix: upgrade openssl to ≥3.0.14 (`apk upgrade openssl`)". No "CVE-2024-XXXX High".
- **Supresión self-service con justificación auditable**: el equipo puede abrir un PR a `exceptions/` con approver + TTL, sin esperar un ticket.
- **"No sorpresas en prod"**: lo que pasa en CI pasa en admission. Si CI dice OK y admission falla, es un bug de la plataforma.
- **Docs excelentes**: cada regla bloqueante linkea a un `docs/rules/<ID>.md` con *qué hiciste mal*, *por qué duele*, *cómo arreglarlo*.
- **Un solo panel**: SARIF agregado en GitHub Code Scanning (o equivalente). Los equipos no deben saltar entre 7 UIs.
- **Integración con IDP** (Backstage): cada servicio tiene un *security tab* con sus findings abiertos, MTTR, cobertura.

> **Idea clave:** la plataforma seguridad compite con "no usar la plataforma". Si no es la ruta más fácil, pierde.

---

## 9. Golden path CI de referencia

Un pipeline mínimo que agrupa todos los gates y **sube SARIF agregado** a GitHub Code Scanning:

- `secret-scan` (gitleaks) → bloqueante.
- `sast` (semgrep) → SARIF out.
- `sca-container` (trivy image) → SARIF out, bloquea en Critical+KEV.
- `iac-scan` (checkov o trivy config) → SARIF out.
- `sbom` (syft) → publica a store.
- `sign + attest` (cosign) → bloquea publicación si falla.
- `upload-sarif` → agrega todos los SARIFs en un solo *category* por tool y los sube con `github/codeql-action/upload-sarif`.

Ver `examples/01-gates-contract/golden-path.yml` para una referencia completa.

---

## 10. Gobernanza

- **Review quarterly** del contrato: ¿los umbrales son correctos? ¿hay reglas que generan 90 % de FP?
- **Policy drift**: ¿las policies desplegadas coinciden con el repo? Alertar si no.
- **Deprecation window**: cuando se añade un gate nuevo, pasa primero por *warn-only* por 30 días antes de volverse blocking.
- **Blast radius de un cambio**: un cambio al contrato debe listar qué servicios se verían afectados (query al SBOM store).

### Antipatrones comunes

- "Fallar en Medium" → quema a los equipos; reemplaza por EPSS+KEV.
- Excepciones sin TTL → se vuelven regla implícita.
- Dashboards sin owner → nadie los lee.
- Scanners en silos (cada equipo instala el suyo) → sin inventario centralizado.
- Métricas vanity (`total CVEs scanned`) → cuenta volumen, no outcome.

---

## Resumen operativo

- **Gates como contrato**: blocking / warn / nightly.
- **Severidad SLO-driven**: CVSS + EPSS + KEV.
- **Exception policy formal**: approver + TTL + revisor + justificación en repo.
- **SBOM inventory**: query en lugar de grep.
- **Lifecycle**: detect → triage → prioritize → remediate → verify → report.
- **Métricas**: MTTR por tier como SLO reina.
- **DX**: feedback <10 min, mensajes accionables, un solo panel.
- **Golden path**: pipeline único, SARIF agregado, IDP integration.
- **Gobernanza**: review quarterly, deprecation window, blast radius conocido.
