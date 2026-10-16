# REFERENCE — ADR del contrato de seguridad de la plataforma

> Referencia de autoevaluación. Compara tu `ADR-security-contract.md` contra este documento. No existe una única respuesta correcta; esta es *una* respuesta razonable y defendible.

---

# ADR-001 — Contrato de seguridad de la plataforma (gates, severidad, exceptions)

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** platform-security + 2 security champions + head of platform
- **Review cadence:** quarterly

## 1. Contexto

La organización opera ~40 servicios en producción. Cada equipo mantiene su `.github/workflows/`, con fragmentación de scanners *ad hoc*: unos corren Trivy, otros no; firmas de imagen inconsistentes; `.trivyignore` sin TTL ni approver; ninguna fuente única de verdad del inventario de dependencias.

Síntomas observados:
- Cuando salió `CVE-2024-XXXX` en `openssl 3.0.11`, averiguar *qué servicios lo cargaban* tomó 6 horas de grep manual.
- Dos incidentes P2 recientes porque una excepción "temporal" llevaba 18 meses.
- Variabilidad del p95 de pipeline entre 4 y 32 min (DX inconsistente).

## 2. Decisión

Adoptamos un **contrato de gates** con tres categorías (blocking / warn / nightly), una **política de severidad SLO-driven** (CVSS + EPSS + KEV), una **exception policy formal** (approver + TTL ≤ 90 días + revisor), y un **compromiso explícito de DX** (p95 ≤ 10 min, SARIF agregado, un solo panel).

Cada servicio consumirá la golden-path CI de la plataforma; los que no se adhieran quedan fuera de admisión al cluster `prod-*`.

## 3. Gates — categorización

| Gate                                 | Categoría   | Fail cuando                                                 |
|--------------------------------------|-------------|-------------------------------------------------------------|
| Secret scanning (gitleaks)           | blocking    | finding real en diff sin excepción vigente                  |
| SCA container (trivy)                | blocking    | CVE Critical en KEV o CVSS≥9 y EPSS≥0.5 sin excepción       |
| Image signed by permitted identity   | blocking    | admisión: pod referencia imagen no firmada por `platform-ci`|
| SBOM published                       | blocking    | la imagen no publicó CycloneDX al store                     |
| IaC policy (OPA/Checkov) deny        | blocking    | `terraform plan JSON` dispara regla deny                    |
| SAST (semgrep)                       | warn        | reglas confidence medium                                    |
| CodeQL deep queries                  | nightly     | fallo abre issue automático, no bloquea PR                  |
| Full-history secret scan             | nightly     | fallo escala a platform-security                            |
| Baseline rescan de imágenes          | nightly     | CVE DB cambió; abre findings nuevos                         |
| Policy drift (deployed vs git)       | nightly     | diferencia → alerta `#platform-sec`                         |

## 4. Política de severidad (CVSS + EPSS + KEV)

| Condición                                   | Tier     | SLA remediación |
|---------------------------------------------|----------|-----------------|
| En KEV                                      | Critical | 24 h            |
| CVSS ≥ 9.0 y EPSS ≥ 0.5                     | Critical | 24 h            |
| CVSS ≥ 7.0 y EPSS ≥ 0.1                     | High     | 7 d             |
| CVSS ≥ 7.0 y EPSS < 0.1                     | Medium   | 30 d            |
| CVSS 4.0–6.9                                | Medium   | 90 d            |
| CVSS < 4.0                                  | Low      | next release    |

Rescan diario con la base actualizada (NVD + GitHub Advisory + OSV).

## 5. Exception policy

- Toda excepción vive en `exceptions/EX-<N>.yaml` versionada en git (no en `.trivyignore` ad hoc).
- Campos obligatorios: `finding`, `scope`, `justification`, `compensating_control`, `approver` (security eng o security champion), `expires_at` (TTL ≤ 90 días), `reviewer_on_expiry`.
- Al expirar, el pipeline vuelve a bloquear automáticamente. Renovación requiere nueva justificación y nuevo approver.
- Dashboard muestra `expired_without_review` como SLO = 0.

## 6. Developer experience — compromisos

1. **Pipeline p95 ≤ 10 min** (medido últimos 7 días).
2. **Mensajes accionables**: cada regla bloqueante linkea a `docs/rules/<ID>.md` con *qué hiciste mal / por qué duele / cómo arreglarlo*.
3. **Un solo panel**: SARIF de todos los scanners agregado en GitHub Code Scanning, con `category:` por tool.
4. **Supresión self-service**: PR a `exceptions/`, approver nominado, no se necesita ticket.
5. **Backstage security tab** por servicio: findings abiertos, MTTR del servicio, cobertura.
6. **"No sorpresas en prod"**: lo que pasa CI pasa admisión. Divergencia = bug de plataforma P1.

## 7. Consecuencias

**Positivas:**
- Inventario único vía SBOM store → respuesta a nuevas CVE en minutos.
- MTTR auditable por tier (SLO Crit ≤ 24 h).
- Excepciones trazables y con fecha de muerte.

**Negativas / trade-offs:**
- Los primeros 90 días el p95 subirá temporalmente a ~12 min por la agregación SARIF; se mitiga con cache y jobs paralelos.
- Equipos acostumbrados a `# nosec` libres tendrán que abrir PRs de excepción; fricción inicial.
- Costo operativo: platform-security dedica 0.5 FTE a mantener el contrato, scripts de agregación y review quarterly.
- Riesgo: si el inventory store cae, no bloqueamos (modo degradado), pero la métrica `% SBOM coverage` cae y dispara alerta.

## 8. Alternativas consideradas (y descartadas)

- **"Dejar que cada equipo elija"**: produce la fragmentación actual; descartado.
- **"Todo blocking, severidad = Medium"**: experiencia empírica: quema a los equipos y empuja a `[skip ci]`; descartado.
- **"Severidad = sólo CVSS"**: ignora exploit probability; descartado a favor de CVSS + EPSS + KEV.
