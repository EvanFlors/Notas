# Dashboard de vuln management — referencia

## 1. Las 7 métricas base

| #  | Métrica                              | Fórmula / cálculo                                               | SLO                   |
|----|--------------------------------------|-----------------------------------------------------------------|-----------------------|
| M1 | MTTR por tier                        | `AVG(fixed_at - detected_at)` filtrado por tier                 | Crit ≤ 24 h, High ≤ 7 d |
| M2 | % imágenes firmadas                  | `signed / total` en `image_build`                               | ≥ 99 %                |
| M3 | % builds green (todos los gates)     | `green_builds / total_builds` en últimos 7 d                    | ≥ 90 %                |
| M4 | % cobertura de SBOM                  | `images_with_sbom / total_images`                               | 100 %                 |
| M5 | Backlog Critical abierto             | `COUNT(findings WHERE tier=Critical AND state=open)`            | = 0                   |
| M6 | Pipeline duration p95                | `p95(pipeline_duration_seconds)` últimos 7 d                    | ≤ 600 s (10 min)      |
| M7 | Excepciones expiradas sin revisar    | `COUNT(exceptions WHERE expires_at < now())`                    | = 0                   |

## 2. Qué conversación dispara cada incumplimiento

- **M1 Crit > 24 h** → leadership + on-call: ¿por qué?, ¿falta runbook?, ¿base image rota?
- **M2 < 99 %** → ¿qué servicio no firma? probablemente deploy fuera de la golden-path.
- **M3 < 90 %** → o la plataforma tiene flakies o los gates son irrealistas.
- **M4 < 100 %** → un servicio deploya sin SBOM → **inventario incompleto** → ceguera a nuevas CVEs.
- **M5 > 0 por > 24 h** → escalado automático: notifica a owner + security eng.
- **M6 > 10 min** → la plataforma está matando la DX. Investigar caches, paralelismo.
- **M7 > 0** → excepciones zombie: audit de la exception policy fallando.

## 3. Layout ASCII del dashboard

```
┌─────────────────────── DevSecOps — Platform Health ───────────────────────┐
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐    │
│  │  M1 MTTR tiers   │  │  M5 Backlog Crit │  │  M6 Pipeline p95       │    │
│  │  Crit:  18h  OK  │  │  Open:   0   OK  │  │   8m 42s           OK  │    │
│  │  High:   4d  OK  │  │  Target: 0       │  │   SLO ≤ 10m            │    │
│  │  Med:   22d  OK  │  │                  │  │                        │    │
│  └──────────────────┘  └──────────────────┘  └───────────────────────┘    │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐    │
│  │  M2 Signed       │  │  M3 Green builds │  │  M4 SBOM coverage      │    │
│  │   99.4 %     OK  │  │   91.2 %     OK  │  │   100 %            OK  │    │
│  │   (247 / 248)    │  │   (last 7d)      │  │                        │    │
│  └──────────────────┘  └──────────────────┘  └───────────────────────┘    │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │  M7 Excepciones expiradas sin revisar: 0  (SLO = 0)                │    │
│  │  Próximas a expirar (<14d): EX-118, EX-121                         │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  Trend últimos 30 d:                                                      │
│    MTTR Crit  ▁▂▁▃▂▁▁▂▁▁▁▂▁▂▁▁▁▁▁▁▁▁▁▂▁▁▁▁▁▁                               │
│    % green    ▇▇▇▆▇▇▇▇▇▇▆▇▇▇▇▇▇▇▇▇▇▇▆▇▇▇▇▇▇▇                               │
└───────────────────────────────────────────────────────────────────────────┘
```

## 4. Query de ejemplo (MTTR Critical)

```sql
SELECT AVG(EXTRACT(EPOCH FROM (fixed_at - detected_at)) / 3600) AS mttr_hours
FROM findings
WHERE tier = 'Critical'
  AND state = 'fixed'
  AND fixed_at >= now() - interval '30 days';
```

## 5. Antipatrones de dashboard

- Vanity: "total scans ejecutados hoy".
- Sin SLO: una métrica sin umbral es decoración.
- Sin owner: nadie revisa, nadie actúa.
- Granularidad equivocada: "backlog total" oculta que 100 son Low y 2 son Crit.
