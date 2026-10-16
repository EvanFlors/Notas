# REFERENCE — sec-03-01-pick-tooling-for-capstone

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Matriz (modelo)

| Capa                 | Herramienta elegida       | Punto de ejecución          | Justificación |
|----------------------|---------------------------|-----------------------------|---------------|
| SAST (código Python) | **Semgrep** (`r/python`, `r/python.flask`, reglas custom) + **CodeQL** nightly | pre-commit (quick), PR (full), nightly (CodeQL con dataflow) | Semgrep es rápido para gate; CodeQL añade dataflow donde Semgrep no llega. Bandit se descarta como primario por ser muy ruidoso; útil solo como complemento específico de Python. |
| SCA (deps Python)    | **Trivy fs** (`--scanners vuln` sobre `requirements.txt`/lockfile) | PR + CI + nightly | Trivy cubre múltiples fuentes (NVD + GHSA + OSV); Grype es equivalente — se elige Trivy porque ya cubre container e IaC. Snyk se descarta por costo salvo que ya haya licencia. |
| Secret scanning      | **gitleaks** (local) + **GitHub Secret Scanning + Push Protection** | pre-commit + push protection + CI full-history | gitleaks rápido y OSS para pre-commit; GH push protection evita que el secret llegue al remote. trufflehog como alternativa si se necesita verificación activa. |
| IaC (Terraform)      | **Checkov** sobre HCL + **Checkov sobre `terraform show -json tfplan`** | pre-commit (HCL quick), PR (plan JSON) | Checkov cubre TF, K8s, Dockerfile en el mismo tool. Scan sobre plan reduce FP (resuelve variables). tfsec descartado (en modo mantenimiento, fusionado con Trivy). |
| IaC (Helm/K8s)       | **Checkov** (misma pila) + **Trivy config** | pre-commit + PR | Checkov entiende Helm chart templates; Trivy config como segundo opinión rápido. |
| Container (imagen)   | **Trivy image** + salida SARIF a GitHub Code Scanning | CI build + registry push + Trivy Operator en admisión | Trivy es el estándar OSS más completo. Grype equivale, pero mantener dos scanners de imagen es overhead. Docker Scout si ya se usa Docker Desktop. |
| DAST (ALB público)   | **OWASP ZAP** (baseline en preview env; full nightly en staging) | preview env (baseline), nightly (full) | ZAP OSS; Burp descartado por licencia y porque un gate automatizado no necesita Burp. Nuclei como complemento de CVEs HTTP conocidos. |
| CSPM (AWS)           | **Prowler** nightly + **AWS Config** rules core (nativo) | nightly + continuo | Prowler cubre cientos de CIS checks sin dependencia enterprise. Wiz/Prisma descartados por costo en etapa inicial. Steampipe útil para queries ad-hoc. |

## Sección B — Pipeline (modelo)

```
### Pipeline (gates shift-left max)

pre-commit (dev local):
   gitleaks (quick), semgrep (ruleset rapido), checkov (HCL quick)
         │
         ▼
PR check (GH Actions):
   semgrep (full), trivy fs (SCA + secret), checkov on HCL + terraform plan JSON,
   trivy config (Helm/K8s)
         │
         ▼
CI build (GH Actions, main branch):
   docker build; trivy image <img> (fail en CRITICAL+KEV);
   SARIF upload a GH Code Scanning; syft genera SBOM
         │
         ▼
registry push (GHCR):
   webhook: trivy image contra registry; retro-scan de imagenes ya desplegadas
         │
         ▼
admision (EKS):
   Trivy Operator: VulnerabilityReport + ConfigAuditReport por workload
         │
         ▼
preview env (PR effimera):
   OWASP ZAP baseline (pasivo)
         │
         ▼
nightly:
   OWASP ZAP full contra staging; Prowler contra cuenta AWS;
   CodeQL full con dataflow; retro-SCA (nuevos CVEs publicados hoy)
```

## Sección C — Descartes y limitaciones (modelo)

Descartes explícitos:

1. **tfsec** como herramienta primaria: en modo mantenimiento, su funcionalidad vive dentro de **Trivy config** / **Checkov**. Elegirlo nuevo introduce deuda.
2. **Bandit** como SAST primario: muy ruidoso en código real; mejor como complemento específico de Python en PR, no como gate principal.
3. **Snyk** como pila principal: comercial, excelente, pero duplica funcionalidad de la pila OSS. Reservar para cuando la organización ya tenga licencia o necesite reachability analysis empresarial.
4. **Burp** en el pipeline automatizado: su valor es manual (pentesters); ZAP cubre el gate.
5. **Grype**: equivalente funcional a Trivy; mantener dos scanners de la misma categoría es overhead sin ganancia.

Lo que esta matriz **no cubre** (fuera de scope de `sec-03`):

- **Pentest manual** y bug bounty externo (no son scanning automatizado).
- **Runtime security** (Falco, Tetragon) → se verá en `sec-12`.
- **Admission policy enforcement** (Kyverno, OPA/Gatekeeper) → `sec-10`, `sec-11`.
- **SBOM + firma / attestations** (Syft completo, cosign) → `sec-08`, `sec-09`.
- **Threat modeling** del propio sistema → se cubrió en `sec-01`.
- **Revisión manual de código** de seguridad (code review enfocado a vulns), que ninguna herramienta sustituye.

## Nota pedagógica

- La elección "una herramienta por capa" es un punto de partida pedagógico. En producción es común tener **dos** scanners por capa de alta criticidad (p. ej. Trivy + Grype) para corroborar hallazgos y reducir falsos negativos — pero eso **duplica el trabajo de triage**. La decisión se toma con datos.
- La política de severidad (actividad `02-severity-policy-draft`) determina **qué hacer** con los hallazgos de esta matriz. Sin esa política, la matriz produce ruido sin acción.
