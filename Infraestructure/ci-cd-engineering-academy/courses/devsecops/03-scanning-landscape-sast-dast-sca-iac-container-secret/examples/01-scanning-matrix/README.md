# Ejemplo 01 — Matriz canónica de scanning

> Lectura y análisis. Sin ejecución. Objetivo: fijar la relación **categoría × herramienta × dónde corre × qué detecta × FP típicos** antes de la actividad `01-pick-tooling-for-capstone`.

## 1. La matriz

```
┌──────────────┬──────────────────────────────┬───────────────────────┬────────────────────────────┬────────────────────────────────────┐
│ Categoría    │ Qué detecta                  │ Dónde corre           │ Herramientas canónicas     │ Falsos positivos típicos            │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ SAST         │ patrones peligrosos en       │ pre-commit, PR, CI    │ Semgrep, CodeQL, Bandit,   │ regex sin dataflow confunde         │
│              │ código (eval, SQL concat,    │                       │ Snyk Code                  │ contextos; marca código test        │
│              │ taint source→sink)           │                       │                            │                                     │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ DAST         │ vulns en servicio corriendo  │ staging, nightly,     │ OWASP ZAP, Burp, Nuclei    │ rutas que requieren estado o auth   │
│              │ (fuzz HTTP, headers, TLS)    │ preview envs          │                            │ no cubiertas; depende del seed data │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ SCA          │ CVEs en dependencias 3P      │ PR, CI, nightly       │ Trivy, Grype, Snyk,        │ CVE marcado pero path vulnerable    │
│              │ (lockfiles, go.mod, package) │                       │ Dependabot/Renovate (bot)  │ no se usa (sin reachability)        │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ IaC scanning │ misconfig en HCL/YAML/CFN/   │ pre-commit, PR, CI    │ Checkov, Trivy config,     │ reglas CIS no aplicables al modelo  │
│              │ Dockerfile/Helm              │                       │ tfsec, Terrascan, KICS     │ de amenaza; variables sin resolver  │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ Container    │ CVEs OS + lang packages      │ build, registry push, │ Trivy, Grype, Clair,       │ base image hereda CVE no explotable │
│              │ + misconfig de imagen        │ admisión K8s          │ Docker Scout               │ en runtime (no-exec paths)          │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ Secret       │ credenciales filtradas en    │ pre-commit, CI full,  │ gitleaks, trufflehog,      │ dummy keys en tests, ejemplos en    │
│              │ código y git history         │ push protection       │ GH secret scanning,        │ docs, entropy en hashes legítimos   │
│              │                              │                       │ detect-secrets             │                                     │
├──────────────┼──────────────────────────────┼───────────────────────┼────────────────────────────┼────────────────────────────────────┤
│ CSPM         │ estado efectivo de la cuenta │ continuo, nightly     │ Prowler, Steampipe,        │ reglas CIS vs reglas de la org;     │
│              │ cloud (IAM, S3, SG, VPC)     │                       │ AWS Config/Security Hub,   │ recursos legacy fuera de inventario │
│              │                              │                       │ Wiz, Prisma Cloud          │                                     │
└──────────────┴──────────────────────────────┴───────────────────────┴────────────────────────────┴────────────────────────────────────┘
```

## 2. Punto de ejecución recomendado

Un mismo escáner puede correr en varias etapas; aquí la **primera** etapa donde conviene integrarlo (shift-left max):

```
   pre-commit → PR check → CI build → registry push → admisión K8s → runtime
      │           │          │            │                │             │
      ▼           ▼          ▼            ▼                ▼             ▼
   secret      SAST       SAST (full)   container       container     DAST
   (quick)     (quick)    SCA           (image CVE)     (verify sig)  (nightly)
   IaC (quick) SCA        IaC (plan)                                    CSPM
                                                                        (cont.)
```

## 3. Qué NO hacer (anti-patrones)

- Correr **solo SAST** y declarar victoria: no mira dependencias ni runtime.
- Correr **solo SCA** y ser laxo con secretos: la mayoría de breaches públicos empiezan por un secret filtrado.
- Correr DAST **en producción** sin coordinación: puede tumbar el servicio.
- Confundir **Dependabot** (bot que abre PRs) con **SCA** (scanner que reporta). Son complementarios: SCA te dice qué falta; Dependabot propone el fix.
- Confundir **IaC scanning** con **CSPM**: el primero es preventivo (antes del apply), el segundo detectivo (después). Son los dos lados de la misma moneda.

## 4. Qué se ve en la próxima lección

- Con esta matriz **memorizada**, la actividad `01-pick-tooling-for-capstone` se vuelve mecánica: capa × herramienta.
- La política de severidad (ejemplo `02-cvss-vs-epss-vs-kev`) te dice **qué hacer** con los hallazgos, no solo **qué scanner correr**.
