# REFERENCE — Proceso operativo del vuln management lifecycle

> Referencia de autoevaluación. Compara tu `VULN-MGMT-PROCESS.md` contra este documento.

---

# VULN-MGMT-PROCESS — v1

## 1. Lifecycle (6 etapas)

| # | Etapa       | Entrada                                   | Salida                             | Owner                             | Métrica                          |
|---|-------------|-------------------------------------------|------------------------------------|-----------------------------------|----------------------------------|
| 1 | Detect      | pipeline per PR, nightly baseline, SBOM-driven alert, pentest, bug bounty | finding con `detected_at`          | platform-security (scanners), security champion (triage inicial) | #findings/día                    |
| 2 | Triage      | finding bruto                             | `is_real: true/false`, scope real  | security champion del equipo       | % false positive                 |
| 3 | Prioritize  | finding real                              | tier (Crit/High/Med/Low) + SLA     | security champion + política automática (CVSS+EPSS+KEV) | distribución por tier            |
| 4 | Remediate   | finding con tier                          | patch / upgrade / excepción con compensating control | **equipo producto** (seguridad asiste)  | MTTR por tier                    |
| 5 | Verify      | fix mergeado                              | rescan verde + regression test     | CI de la golden-path              | % verificados a tiempo           |
| 6 | Report      | finding `fixed`                           | métricas al dashboard, trend mensual | platform-security + stakeholders  | tendencia MTTR, backlog Crit     |

Ownership explícito: *seguridad asiste, producto remedia*. "El equipo de seguridad arregla los CVEs" es un antipatrón.

## 2. SLA por tier

| Tier     | Trigger                                              | SLA remediación |
|----------|------------------------------------------------------|-----------------|
| Critical | KEV o CVSS ≥ 9.0 y EPSS ≥ 0.5                        | 24 h            |
| High     | CVSS ≥ 7.0 y EPSS ≥ 0.1                              | 7 d             |
| Medium   | CVSS ≥ 7.0 y EPSS < 0.1, o CVSS 4.0–6.9              | 30–90 d         |
| Low      | CVSS < 4.0                                           | next release    |

Breach de SLA → escalado automático a leadership + abre postmortem si Critical.

## 3. Métricas (SLO)

| # | Métrica                               | Fórmula                                            | SLO             |
|---|---------------------------------------|----------------------------------------------------|-----------------|
| 1 | MTTR por tier                         | `AVG(fixed_at - detected_at)` filtrado por tier    | Crit ≤ 24 h     |
| 2 | % imágenes firmadas                   | `signed / total` en `image_build`                  | ≥ 99 %          |
| 3 | % builds green                        | `green / total` últimos 7 d                        | ≥ 90 %          |
| 4 | % cobertura SBOM                      | `images_with_sbom / total`                         | 100 %           |
| 5 | Backlog Critical abierto              | `COUNT(open AND tier=Critical)`                    | = 0             |
| 6 | Pipeline p95                          | `p95(duration_seconds)` últimos 7 d                | ≤ 600 s         |
| 7 | Excepciones expiradas sin revisar     | `COUNT(expired_at < now())`                        | = 0             |

MTTR por tier es la métrica *reina*. Breach dispara conversación concreta.

## 4. Escenario end-to-end — "CVE-2024-XXXX en openssl 3.0.x"

**Lunes 03:14** — CISA publica KEV update añadiendo CVE-2024-XXXX con exploit activo en openssl 3.0.0–3.0.13.

### Etapa 1 — Detect

Nightly baseline scan al terminar (ejecutándose cada día 04:00) marca 17 imágenes afectadas. Simultáneamente, el feed KEV-watcher dispara un alert inmediato con query al **SBOM store**:

```sql
SELECT DISTINCT ib.service_name, ib.tag
FROM sbom_component c
JOIN image_build ib USING (image_digest)
WHERE c.package_name = 'openssl'
  AND c.package_version LIKE '3.0.%';
```

Resultado: 11 servicios distintos, 17 imágenes.

### Etapa 2 — Triage

Security eng de guardia confirma: la CVE afecta a `openssl` 3.0.0–3.0.13 inclusive; `3.0.14+` corrige. De los 17, 3 corren `3.0.14` por un bump reciente (falsos positivos del scan — mismo paquete, versión distinta); 14 necesitan acción real.

### Etapa 3 — Prioritize

Está en KEV → **Critical, SLA 24 h** para los 14 restantes. Se abren 14 findings en el tracker con `detected_at = 2026-10-16T03:14Z`.

### Etapa 4 — Remediate

Platform-security publica base image `app-base:3.19.1` con openssl 3.0.14. Cada equipo producto hace un PR que bumpea su `Dockerfile FROM`. En paralelo, para 2 servicios cuya rebase es compleja, el equipo abre excepción `EX-301` con compensating control (regla WAF que bloquea el vector) y TTL 72 h.

### Etapa 5 — Verify

Rescan nocturno del día siguiente: 12/14 servicios green. Los 2 con excepción siguen marcados pero con `has_valid_exception: true`. MTTR final: 19 h (dentro de SLO).

### Etapa 6 — Report

Dashboard muestra: Crit backlog 0, MTTR Crit mes = 21 h (SLO 24 h, OK). Platform-security hace writeup corto en `#platform-security` con lecciones (p.ej. 3 servicios no tenían alerta por falta de SBOM publicado → gap identificado para la golden-path).

## 5. Antipatrones (y cómo el proceso los previene)

1. **Excepciones sin TTL ni approver.**
   - *Síntoma*: `.trivyignore` con una línea sin fecha ni autor.
   - *Prevención*: toda excepción es un YAML en `exceptions/` con `expires_at` y `approver`. Al expirar, el pipeline vuelve a bloquear automáticamente.

2. **Métricas vanity ("total CVEs escaneados").**
   - *Síntoma*: dashboards impresionan en all-hands pero no cambian decisiones.
   - *Prevención*: cada métrica tiene SLO y owner. Si breach no dispara acción, se elimina.

3. **"El equipo de seguridad arregla los CVEs".**
   - *Síntoma*: queue de PRs de seguridad que nadie prioriza; seguridad bottleneck.
   - *Prevención*: lifecycle define ownership: *producto remedia, seguridad asiste*. SLA es responsabilidad del equipo que posee el servicio.

4. **Scanners en silos (cada equipo elige el suyo).**
   - *Síntoma*: inventario incompleto; cuando sale una CVE no se sabe quién la carga.
   - *Prevención*: golden-path CI única + SBOM store único + admission gate que exige SBOM publicado.

5. **"Fallar en Medium" como gating signal.**
   - *Síntoma*: equipos aprenden a `--ignore-all`.
   - *Prevención*: la política usa CVSS + EPSS + KEV; Medium es *warn*, no *blocking*, salvo que entre en KEV.
