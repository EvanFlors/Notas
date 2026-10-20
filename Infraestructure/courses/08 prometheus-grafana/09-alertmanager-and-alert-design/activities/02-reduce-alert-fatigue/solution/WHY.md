# WHY.md — Solucion de referencia

## Mantenidas

- `ApiAvailabilityBelowSlo` — sintoma SLO directo. Si availability user-facing cae del 99.9%, un humano debe actuar antes de agotar el error budget mensual. Runbook describe triage.
- `ApiLatencyP95AboveSlo` — sintoma SLO user-facing. p95 >500ms sostenido 10m es percibible y correlaciona con quejas en soporte.
- `ApiErrorRateHigh` — sintoma SLO. Error rate >1% quema budget rapido; el on-call tiene playbook claro (rollback, feature flag).
- `ApiErrorBudgetBurnFast` — multi-window multi-burn-rate: dispara solo cuando el ritmo de consumo del error budget es tan alto que lo agota en <1h. Es el predictor mas limpio de incidente grave.
- `PostgresPrimaryDown` — causa, pero equivalente a sintoma: si el primary cae, toda la API cae. Permite respuesta especifica (failover) antes de que las 3 anteriores exploten en cascada. Inhibicion en Alertmanager hace el resto.

## Eliminadas

- `CpuHigh` — causa pura sin impacto user-facing demostrado; CPU alta no es un problema si latencia y errors estan OK.
- `CpuHighStaging` — alerta sobre staging; staging **no** se paginea.
- `MemoryHigh` — causa pura; cubierto por sintoma si causa impacto; si no, no.
- `DiskFillingUp` — mejor como ticket (severity=info) con burn-rate del disco (`predict_linear`), no page sobre umbral plano.
- `NetworkRxHigh` — RX alta es sintoma de uso, no de problema; sin impacto es ruido.
- `PodRestarts` — un restart aislado es parte normal (OOM, deploys); umbral `>0` dispara continuamente.
- `PodCrashLoop` — causa; si causa impacto user-facing lo detecta `ApiErrorRateHigh`; si no, es ruido.
- `NodeNotReady` — causa; inhibida por SLO alerts; monitorearlo como dashboard, no page.
- `TargetDown` — causa; `up==0` para un pod individual no implica incidente; cubierto por SLO.
- `HTTP4xx` — 4xx son errores del cliente, no de nuestro servicio; nunca paginar en 4xx (quiza ticket si spike raro, pero no page).
