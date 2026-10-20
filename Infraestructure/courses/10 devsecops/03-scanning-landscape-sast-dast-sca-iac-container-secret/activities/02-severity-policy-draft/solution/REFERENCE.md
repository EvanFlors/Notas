# REFERENCE — sec-03-02-severity-policy-draft

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Taxonomía de prioridades (modelo)

### P0 — remediación inmediata (24–72 h)

Hallazgo activo con **exposición externa** y **evidencia de explotación** (CVE en KEV **o** PoC público reciente). Prioridad absoluta.

- SLA: parche o compensating control en **24–72 h**.
- Comunicación: canal `#sec-incident`, Security Officer y product owner en loop. Posible incident declaration.
- Comportamiento CI: **bloquea** merges y deploys hasta mitigación.

### P1 — alta (7 días)

Severidad teórica alta (CVSS ≥ 9.0) **y** probabilidad real (EPSS > 0.5), pero sin exposición directa confirmada o sin uso activo conocido.

- SLA: **7 días**.
- Comunicación: ticket al equipo owner; sync semanal.
- Comportamiento CI: bloquea PR que **introduce** el hallazgo; existente queda en backlog con SLA.

### P2 — media (30 días)

CVSS ≥ 7.0 **o** CVE en KEV sin exposición externa. Importante, no urgente.

- SLA: **30 días**.
- Comunicación: dashboard; review en retro mensual.
- Comportamiento CI: warning; no bloquea.

### P3 — baja (60–90 días)

CVSS 4.0–6.9, EPSS bajo (< 0.01), no KEV, exposición limitada.

- SLA: **60–90 días**. Se agrupan en "deuda de seguridad" para batch.
- Comunicación: solo dashboard.
- Comportamiento CI: solo informativo.

(Opcional) **Informativo**: CVSS < 4.0 o only-dev-tools. No tiene SLA.

## Sección B — Matriz de asignación (modelo)

| Condición                                                      | Prioridad   | SLA         |
|----------------------------------------------------------------|-------------|-------------|
| CVE en KEV y exposición externa confirmada                     | **P0**      | 24–72 h     |
| CVSS ≥ 9.0 y EPSS > 0.5                                        | **P1**      | 7 días      |
| CVSS ≥ 7.0 o CVE en KEV (sin exposición externa)               | **P2**      | 30 días     |
| CVSS 4.0–6.9 y EPSS < 0.01 y no KEV                            | **P3**      | 60–90 días  |
| CVSS < 4.0                                                     | informativo | n/a         |
| Hallazgo en path **no ejecutable** (ej. jar en dev-tools layer) | suppression | n/a (ver C) |

Reglas de desempate:

- Si el componente afectado está en el **camino caliente** (gateway, auth, ingestión), subir **una prioridad**.
- Si está en dev-only / tooling / build-time: bajar una prioridad o considerar suppression.
- KEV tiene precedencia: cualquier KEV + exposición externa es P0, independientemente del CVSS.

## Sección C — Suppressions vs Exceptions (modelo)

### Suppression (falso positivo técnico)

Campos obligatorios:

| Campo              | Obligatorio | Notas |
|--------------------|:-----------:|-------|
| `scanner`          | sí          | Semgrep, Trivy, Checkov, gitleaks, etc. |
| `finding_id`       | sí          | CVE, rule id |
| `razón`            | sí          | texto concreto; **nunca** "FP" solo |
| `reviewed_until`   | recomendado | fecha de re-review (default 90 d) |

Ejemplo:

```
# .trivyignore
CVE-2023-99999  # path not reachable: fn X never called from app
                # (reviewed_until 2026-04-30)
```

### Exception (riesgo real aceptado)

Campos obligatorios (**todos**):

| Campo                 | Obligatorio | Notas |
|-----------------------|:-----------:|-------|
| `id`                  | sí          | EXC-YYYY-NNN |
| `finding` / `cve`     | sí          |  |
| `severity`            | sí          | de la matriz |
| `cvss`, `epss`, `kev` | sí          | para auditar la decisión |
| `justification`       | sí          | por qué no se arregla ahora |
| `compensating_control`| sí          | qué mitiga mientras tanto |
| `owner`               | sí          | persona/equipo responsable |
| `approver`            | sí          | **distinto** del owner |
| `created_at`          | sí          |  |
| `expires_at`          | **sí**      | fecha concreta ≤ 180 días (salvo caso) |
| `review_cadence_days` | sí          | re-review (default 30–60) |

Ejemplo (ver también `examples/03-exception-policy-sample/`):

```yaml
- id: EXC-2026-007
  finding: CVE-2024-12345
  scanner: trivy
  severity: HIGH
  cvss: 7.8
  epss: 0.04
  kev: false
  justification: >
    Upstream fix pendiente (libfoo 2.4.1 ETA Q2 2026).
    No podemos bumpear a 2.5 por breaking changes.
  compensating_control: >
    WAF rule 'block-foo-vector' habilitada en el edge.
  owner: team-platform
  approver: ciso
  created_at: 2026-01-15
  expires_at: 2026-06-30
  review_cadence_days: 30
```

## Sección D — Proceso y métricas (modelo)

### Proceso

```
hallazgo nuevo
   │
   ▼
¿FP tecnico? ─ SI → suppression en archivo del scanner + razon + reviewed_until
   │                 (merge sin ticket, revisado en PR normal)
   NO
   ▼
¿Hay fix viable este sprint? ─ SI → arreglar (no exception)
   │
   NO
   ▼
abrir ticket EXC-YYYY-NNN
   ↓
PR a security/exceptions.yaml con todos los campos
   ↓
review de security lead (approver != owner)
   ↓
merge; scanner lee el registro y deja pasar hasta expires_at
   ↓
3 d antes de expires_at: notificacion al owner
   ↓
en expires_at: si no renovado, el scanner vuelve a fallar el gate
```

### Re-review

- Cada **30–60 días** security lead revisa la lista completa.
- Exceptions con **edad > 6 meses** entran en revisión obligatoria del CISO.
- Suppressions sin `reviewed_until` → se agendan review automática cada 90 días.

### Métricas (dashboard)

1. **Exceptions activas por severidad** (debe ser estable; crecimiento = problema).
2. **Exceptions expiradas sin renovar** (debe ser **0**; si no, el proceso no cierra).
3. **Edad media de exceptions** (si crece, acumulas deuda).
4. **Hallazgos nuevos por semana** (tendencia; baseline semanal).
5. **Mean time to remediation (MTTR)** por prioridad vs SLA.

### Comportamiento del CI (resumen)

- **P0, P1**: el PR que introduce el hallazgo **falla**; el existente ya está en backlog con SLA.
- **P2**: warning en PR; informe diario al owner.
- **P3, informativo**: solo dashboard.

## Nota pedagógica

- La política debe caber en **una página**. Si no cabe, nadie la lee ni la aplica.
- Los números concretos (72 h, 7 d, 30 d) son defaults razonables; cada organización los ajusta.
- Sin **expires_at obligatorio** y **approver distinto**, la política de exceptions es decorativa.
