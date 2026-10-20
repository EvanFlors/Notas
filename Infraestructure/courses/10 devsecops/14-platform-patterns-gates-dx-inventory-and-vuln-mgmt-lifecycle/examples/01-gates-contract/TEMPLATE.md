# Contrato de seguridad de la plataforma — PLANTILLA

> Copia y adapta este template como `SECURITY-CONTRACT.md` en el repo de tu plataforma.
> Última revisión: `<YYYY-MM-DD>`. Owner: `platform-security@<org>`. Revisión quarterly.

## 1. Alcance

Este contrato aplica a: todos los servicios desplegados vía la golden-path CI que viven en el cluster `prod-*`. Servicios fuera de este alcance (POCs, legacy sin pipeline) **no** gozan de las garantías ni cargan con las obligaciones de este contrato.

## 2. Gates — categorización

### 2.1 Blocking (fail the build / fail the deploy)

| Gate                                    | Dónde       | Fail cuando                                                          |
|-----------------------------------------|-------------|----------------------------------------------------------------------|
| Secret scan (gitleaks)                  | CI          | finding en el diff sin excepción vigente                             |
| CVE Critical en KEV                     | CI (trivy)  | cualquier package afectado sin excepción                             |
| CVE Critical con EPSS ≥ 0.5             | CI (trivy)  | cualquier package afectado sin excepción                             |
| Image unsigned by permitted identity    | Admission   | pod referencia imagen sin firma válida (cosign + policy-controller)  |
| SBOM missing                            | CI (syft)   | la imagen no generó CycloneDX publicable                             |
| IaC `deny` policy violation             | CI (opa)    | `terraform show -json` dispara regla deny                            |

### 2.2 Warn (annotate, do not fail)

| Gate                                    | Dónde       | Comentario                                              |
|-----------------------------------------|-------------|---------------------------------------------------------|
| CVE High sin KEV, EPSS 0.1–0.5          | CI          | se anota en PR y en SARIF                               |
| SAST confidence media                   | CI          | Semgrep rule set `ci.ruleset=medium`                    |
| Base image desactualizada > 30 d        | CI          | aviso para planificar swap                              |
| Supresión próxima a expirar < 14 d      | CI          | bot recordatorio al approver                            |

### 2.3 Nightly / out-of-band

| Job                                     | Cadencia    | Owner                        |
|-----------------------------------------|-------------|------------------------------|
| Full-history secret scan                | daily 02:00 | platform-security            |
| CodeQL deep queries                     | daily 03:00 | platform-security            |
| Baseline rescan de todas las imágenes   | daily 04:00 | platform-security + products |
| Policy drift (deployed vs git)          | hourly      | platform-security            |

## 3. Política de severidad

Fuentes: CVSS v3.1, EPSS (FIRST), KEV (CISA). Rescan cada 24 h.

| Condición                                   | Tier     | SLA (desde `detected_at`) |
|---------------------------------------------|----------|---------------------------|
| En KEV                                      | Critical | 24 h                      |
| CVSS ≥ 9.0 y EPSS ≥ 0.5                     | Critical | 24 h                      |
| CVSS ≥ 7.0 y EPSS ≥ 0.1                     | High     | 7 d                       |
| CVSS ≥ 7.0 y EPSS < 0.1                     | Medium   | 30 d                      |
| CVSS 4.0–6.9                                | Medium   | 90 d                      |
| CVSS < 4.0                                  | Low      | next release              |

## 4. Exception policy

Toda excepción es un YAML en `exceptions/EX-<N>.yaml`:

```yaml
id: EX-123
finding: CVE-2024-XXXX
scope:
  service: payments-api
  image: ghcr.io/org/payments-api
  package: libfoo
justification: >
  La ruta vulnerable `foo.decrypt_v1` no se carga (coverage adjunto).
  Reemplazo planificado en Q3-sprint-07.
compensating_control: WAF rule WAF-42 bloquea /legacy/*
approver: alice@org   # security eng o security champion
requested_by: bob@org
created_at: 2026-10-16
expires_at: 2026-11-16        # <= 90 días
reviewer_on_expiry: alice@org
```

Al expirar: el pipeline vuelve a bloquear automáticamente. Renovar requiere nueva justificación.

## 5. Developer experience — compromisos de la plataforma

- Feedback de pipeline p95 **≤ 10 min**.
- Cada mensaje de fallo linkea a `docs/rules/<ID>.md`.
- SARIFs agregados en GitHub Code Scanning (único panel).
- Backstage security tab por servicio.
- Supresión self-service vía PR a `exceptions/`.

## 6. Métricas públicas (dashboard)

- MTTR por tier (SLO Critical ≤ 24 h, High ≤ 7 d).
- % imágenes firmadas (SLO ≥ 99 %).
- % builds green (SLO ≥ 90 %).
- % cobertura de SBOM (SLO = 100 %).
- Backlog Critical abierto (SLO = 0).
- Excepciones expiradas sin revisar (SLO = 0).
- Pipeline p95 (SLO ≤ 10 min).

## 7. Governance

- **Review quarterly** por platform-security + 2 security champions.
- **Deprecation window**: todo gate nuevo pasa 30 días en *warn* antes de volverse *blocking*.
- **Blast radius** de cada cambio documentado vía query al SBOM store.
- Cambios al contrato: PR en este repo, 2 aprobadores, anuncio en `#platform-announcements`.
