# Ejercicio arquitectónico — DevSecOps para fintech en crecimiento

## Contexto

**Organización:** fintech regulada, 120 ingenieros distribuidos en 10 equipos de producto + 1 equipo plataforma de 6 personas.

**Stack:**

- 60 microservicios en Go/Python, build con `docker build`.
- CI: GitHub Actions, runners hosted por GitHub.
- Registry: GHCR (`ghcr.io/acme/*`).
- Runtime: 3 clusters EKS (`dev`, `stg`, `prod`), 1.29. Argo CD aplica manifests.
- Terraform para infra (VPC, EKS, RDS, S3). CI corre `terraform plan` por PR.
- Secretos: hoy conviven `kubernetes Secret` base64 (legacy) + AWS Secrets Manager + algunas env vars long-lived (deuda).

**Estado de seguridad actual:**

- Trivy corre en algunos repos (ad-hoc, severidad mixta).
- No hay firma de imágenes.
- No hay SBOM centralizado.
- Kyverno instalado pero solo con 2 policies informativas (`audit` mode).
- No hay exception policy formal; las excepciones viven en issues de Jira sin TTL.

**Presión de negocio:**

- CTO exige **merge-to-prod en ≤ 15 minutos end-to-end** (hoy promedio 40 min, el bottleneck es el pipeline).
- Regulador exige evidencia auditable de controles de supply chain para la próxima revisión en 6 meses.
- Dos incidentes en el último trimestre: (1) secreto AWS commiteado a repo privado, no detectado hasta pentest; (2) imagen con CVE crítico desplegada en prod porque "la alerta se perdió en Slack".

## Restricciones

- Presupuesto cloud: límite estricto, nada de Semgrep Pro ni Snyk comercial en Q1.
- No se puede exigir a los devs aprender Rego **en Q1** (sí en Q2).
- Debe funcionar con las versiones vigentes de GHA, Kyverno, cosign y Trivy a 2026.
- No se puede bloquear el pipeline en falsos positivos sin ruta de excepción rápida (< 2 h).
- Toda excepción debe tener TTL ≤ 90 días y approver nombrado.

## Entregables

### A1 — Contrato de gates (10 pts) → `architectural/gates-contract.md`

Define para **cada control** de la cadena (secret scan, SAST, SCA/container, IaC scan, SBOM, sign/attest, admission verifyImages, PSA, runtime Falco):

- ¿**Bloquea merge**, **warn**, o corre **nightly**?
- ¿Por qué esa clasificación? Justifica con el **trade-off velocidad vs riesgo** y, cuando aplique, con **EPSS/KEV** más que solo CVSS.
- ¿Cuánto tiempo añade al merge? (estimación en segundos; aceptable orden de magnitud).
- ¿Qué métrica mide su efectividad? (ej.: MTTR a CVE crítico, % imágenes firmadas, % pipelines con todos los gates verdes).

Produce una **tabla** más 1–2 páginas de prosa justificando las decisiones no obvias.

### A1-bis — Exception policy (dentro del mismo A1) → `architectural/exception-policy.md`

Diseña el proceso de excepción:

- Formato de la excepción (archivo-as-code preferido; sin excepciones por Slack).
- TTL máximo, approver, reviewer, canal de auditoría.
- Qué pasa cuando una excepción vence (gate vuelve a block, PR owner notificado, etc.).
- Self-service: cómo evitar que la mesa de ayuda de seguridad se vuelva el bottleneck.

### A2 — ADR tool de admisión (8 pts) → `architectural/adr-0001-admission-tool.md`

Formato ADR corto (Michael Nygard):

- **Contexto** (resumí el escenario; evita copy-paste).
- **Decisión** (una herramienta: Kyverno, OPA/Gatekeeper, sigstore policy-controller, o ValidatingAdmissionPolicy — o combinación justificada).
- **Consecuencias** (positivas y negativas, explícitas).
- **Alternativas descartadas** (al menos 2, con *por qué*).
- **Disparadores de revisión** (cuándo revisarías esta decisión; p. ej. "si VAP soporta `mutate` GA").

La decisión debe tener en cuenta:

- Que el equipo plataforma es chico (6 personas) y los devs no saben Rego.
- Que hay que verificar firmas cosign (`verifyImages`).
- Que PSA restricted ya es un requisito.
- Que el runtime (Falco/Tetragon) es out-of-scope de este ADR.

## Qué se evalúa

Ver rúbrica arquitectónica en `EXAM.md` §5.3. Resumen:

- Alineación con requisitos y restricciones del escenario.
- Trade-offs explícitos (idealmente cuantificados, aunque sea estimación).
- ADR como documento (estructura + alternativas descartadas + disparadores).
- Exception policy operable y auditable.

## Qué NO entregar

- Manifests Kyverno completos (eso es el ejercicio operativo, no éste).
- Diagramas de arquitectura cloud generales (fuera de scope).
- Comparativas de 10 páginas copiadas de blogs; preferible 1 página defendible.
- Secretos reales de ningún tipo, aun en ejemplos.
