# Curso: DevSecOps toolkit

Roadmap especializado #12. Curso **integrado** que cubre las herramientas y prácticas de seguridad aplicada al ciclo CI/CD y a la operación cloud-native:

- **Scanning**: Trivy, Grype, Semgrep, CodeQL, Checkov, tfsec.
- **Secret scanning**: gitleaks, trufflehog, GitHub secret scanning.
- **Supply chain**: SBOM (Syft, CycloneDX/SPDX), SLSA provenance.
- **Firma de artefactos**: cosign + Sigstore (keyless, Fulcio, Rekor).
- **Policy as Code**: OPA/Rego + Conftest; Kyverno; ValidatingAdmissionPolicy.
- **Secrets at scale**: SOPS, External Secrets Operator, HashiCorp Vault.
- **Runtime security**: Falco, Tetragon (eBPF).
- **Platform governance**: diseño de gates en el pipeline sin dañar DX.

## 1. Introducción

### Qué es

**DevSecOps** no es una herramienta sino una **postura operativa**: la seguridad es responsabilidad compartida que se ejerce **continuamente** en cada fase del SDLC (plan, code, build, test, release, deploy, operate, monitor). Reemplaza el modelo de "security gate al final" por **controles automatizados** distribuidos a lo largo del pipeline y en runtime.

Dos ejes guían todo el curso:

1. **Shift-left**: mover controles lo más temprano posible (lint, SAST, SCA, IaC scan en el commit o PR). Barato detectar, barato arreglar.
2. **Shift-right / defense in depth**: aun con shift-left perfecto, agregar controles en admisión (Kyverno), en runtime (Falco), y auditoría continua. Un control fallido no debe comprometer todo el sistema.

### Historia (síntesis)

- **2008–2012** — Rugged DevOps, OWASP: la seguridad "intenta" alcanzar el ritmo DevOps.
- **2014+** — Shift-left es término estándar; aparece el *Rugged Manifesto*.
- **2016** — Clair (vuln scanning en contenedores) → el campo "container security" nace.
- **2019** — **Sigstore** se funda (Linux Foundation): firma de artefactos *keyless* con OIDC. Elimina la necesidad de distribuir y custodiar claves privadas de larga vida.
- **2020** — **SLSA** (Supply chain Levels for Software Artifacts) formaliza niveles de madurez de supply chain tras incidentes como SolarWinds.
- **2021** — **Executive Order 14028** (US) requiere SBOM para software vendido al gobierno federal → acelera adopción industrial.
- **2022** — Incidentes `log4shell`, `3cx`, luego `xz-utils` (2024), `tj-actions/changed-files` (2025) consolidan supply chain como preocupación de primer orden.
- **2023+** — eBPF (Tetragon) para runtime security sin kernel modules; OTel + security signals; attestations SLSA v1.0 nativas en GitHub Actions.

### Problemas que resuelve

- **Vulnerabilidades en dependencias** (SCA, container scanning, SBOM).
- **Secretos en el repo** (secret scanning + push protection).
- **Misconfigs en IaC y Kubernetes** (Checkov, tfsec, Trivy config, Kyverno).
- **Supply chain comprometida** (SBOM + firma + attestation + verificación en admisión).
- **Secretos filtrados** (gestión central con rotación y mínimo privilegio).
- **Comportamiento sospechoso en runtime** (Falco/Tetragon).

### Casos de uso

- Pipeline que falla el build si hay un CVE crítico sin excepción documentada.
- Admisión K8s que rechaza imágenes no firmadas.
- Dashboards de **inventario** de componentes (SBOM agregado) para responder "¿dónde corre openssl 3.0.x?" en minutos.
- Rotación automática de secretos de DB vía Vault + ESO.
- Detección en runtime de ejecución inesperada (`sh -c curl ...`) en un contenedor que no debería hacerlo.

### Arquitectura general del pipeline DevSecOps canónico

```
┌───────────────────────────────────────────────────────┐
│ Dev local                                             │
│  - pre-commit: gitleaks + lint + fmt                  │
└───────────────────────────────────────────────────────┘
          │ git push
          ▼
┌───────────────────────────────────────────────────────┐
│ CI (GitHub Actions)                                   │
│   - secret scan (full history)                        │
│   - SAST (Semgrep / CodeQL)                           │
│   - SCA (Trivy / Grype) + license check               │
│   - IaC scan (Checkov / Trivy config)                 │
│   - build image (BuildKit, pinned deps)               │
│   - SBOM (Syft)                                       │
│   - container vuln scan (Trivy)                       │
│   - sign + attest (cosign keyless via OIDC)           │
│   - push to GHCR / ECR / Artifact Registry            │
└───────────────────────────────────────────────────────┘
          │ bump image tag in infra repo
          ▼
┌───────────────────────────────────────────────────────┐
│ CD (Argo CD) + Admission (Kyverno)                    │
│   - verify signature + attestation                    │
│   - PSA restricted + custom policies                  │
│   - inject secrets (ESO / Vault Agent)                │
└───────────────────────────────────────────────────────┘
          │
          ▼
┌───────────────────────────────────────────────────────┐
│ Runtime                                               │
│   - Falco / Tetragon detection rules                  │
│   - audit logs centralizados                          │
│   - CSPM / Config / Security Hub (cloud)              │
└───────────────────────────────────────────────────────┘
```

### Alternativas (SaaS integrado)

- **Snyk**, **Sysdig**, **Prisma Cloud** (Palo Alto), **Aqua**, **Lacework**, **Wiz**: cubren varias capas (SCA + container + IaC + runtime + CSPM) con una sola UI y pricing comercial.
- **Dependabot** y **GitHub Advanced Security** (CodeQL, secret scanning, Dependabot): nativos en GitHub, parcial pero muy conveniente.

El programa prioriza el **toolkit abierto** (reemplazable, portable, sin lock-in) y menciona SaaS como alternativa pragmática.

### Ventajas / limitaciones

**Ventajas**: cada herramienta hace una cosa bien; se componen; portables entre pipelines; comunidad activa; sin lock-in.

**Limitaciones / riesgos**:
- **Alerting fatigue**: cada scanner produce ruido. Sin triage y supresión disciplinada, los equipos aprenden a ignorar.
- **Gates duros matan DX**: fallar builds por CVEs medios bloquea trabajo legítimo; política de severidad + ventanas de gracia es esencial.
- **Falsa sensación de seguridad**: tener Trivy en CI no implica un sistema seguro.
- **Secretos y policy a escala** requieren inversión en plataforma (Vault, ESO, Kyverno bien operados).
- **Supply chain** solo es útil si *se verifica* la firma en el consumidor, no solo si *se firma* en el productor.

### Relación con el programa

- Aterriza en **GitHub Actions** (controles como steps y como required workflows).
- Aterriza en **Kubernetes** (admisión, Pod Security, runtime).
- Aterriza en **Argo CD / GitOps** (verificación en admisión antes de aplicar).
- Aterriza en **AWS / GCP** (secrets managers, firma de imágenes en ECR/Artifact Registry, Config/Security Command Center).
- Es el **tejido transversal** que cierra la cadena de confianza del capstone.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Cursos **docker**, **github-actions**, **kubernetes** ≥ Nivel 2. T-9.1 (threat modeling conceptual). |
| Recomendados | Curso **argocd-gitops** (para el eslabón "verify en admisión"). Curso **terraform** (para IaC scanning). Curso **aws** y/o **gcp** (para secret managers y KMS). |
| Complementarios | Curso **helm** (para firmar charts). |

## 3. Organización (4 niveles)

El curso tiene **14 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (3): principios DevSecOps + threat modeling + visión supply chain (SLSA/SBOM), overview de secretos y de scanning (SAST/DAST/SCA/IaC/container/secret).
- **Nivel 2 — Intermedio** (4): secret scanning práctico, SCA + container scanning con Trivy, SAST con Semgrep + CodeQL, IaC scanning (Checkov/Trivy config/tfsec).
- **Nivel 3 — Avanzado** (4): SBOM y SLSA en profundidad, firma y attestations con cosign + Sigstore, Policy as Code (OPA/Rego + Conftest), admisión K8s (Kyverno + sigstore policy-controller + ValidatingAdmissionPolicy).
- **Nivel 4 — Producción empresarial** (3): runtime security (Falco + Tetragon), secrets a escala (Vault + ESO + workload identity), platform patterns (gates sin daño DX, inventory de SBOMs, vuln management lifecycle, excepciones).

## 4. Entregables del curso

- Pipeline GHA del capstone con secret scan + SAST + SCA + IaC scan + container scan + SBOM + sign + attest.
- Políticas Kyverno en el cluster que: exigen imágenes firmadas, Pod Security `restricted`, atributos obligatorios (owner, team).
- Capstone con secretos gestionados vía **ESO** respaldados por Vault o cloud secret manager.
- Falco desplegado y detectando patrones concretos (shell en contenedor que no debería ejecutar shell).
- ADR "política de severidad y excepciones" + proceso de vuln management.
- Repositorio con **SBOM** publicado como attestation; verificación demostrada en entorno limpio.

## 5. Evaluación

- **Conceptual**: SLSA niveles 1–4 y qué controla cada uno; qué garantiza cosign keyless y qué no; diferencia OPA/Rego vs Kyverno/CRDs; principio de rotación y por qué los secrets como env vars son frágiles.
- **Operativa**: integrar Trivy en CI con política de severidad; firmar y verificar imagen con cosign; escribir una ConstraintTemplate/ClusterPolicy; cargar un secreto Vault en un Pod via ESO.
- **Arquitectónica**: diseñar la cadena de confianza del productor al consumidor; política de excepciones; estrategia de rotación de secretos; cómo medir "sistema seguro" sin generar ruido.

## 6. Recursos

A verificar en Fase 4:

- **SLSA** spec (`slsa.dev`).
- **Sigstore** docs (`docs.sigstore.dev`) y cosign.
- **CycloneDX** y **SPDX** specs.
- Trivy, Grype, Syft (Anchore / Aqua).
- Semgrep, CodeQL docs.
- Checkov, tfsec, Trivy config.
- OPA + Rego, Conftest.
- Kyverno docs; sigstore policy-controller.
- HashiCorp Vault docs; External Secrets Operator; Secrets Store CSI Driver.
- Falco, Tetragon docs.
- CIS Benchmarks (Docker, Kubernetes, cloud).
- *The Phoenix Project* y *The DevOps Handbook* (contexto cultural, no técnico).
