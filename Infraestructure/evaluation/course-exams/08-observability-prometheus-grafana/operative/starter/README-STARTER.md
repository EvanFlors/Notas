# Starter — pistas (y pistas falsas)

- `prometheus.yml`: tiene **3** problemas plantados (uno es una pista falsa — el `external_labels.cluster=dev-local` está bien).
- `metrics.txt`: tiene **4** problemas plantados (A, B, C, D). Documenta cada uno en `solution/notes.md` como `metrics-fix.md`.
- `rules/rules.yml`: tiene **1** alerta ingenua (single-window). Rediseñar como MWMBR y añadir *ingredients* como recording rules.
- `alertmanager/alertmanager.yml`: route plano. Añadir child routes por severidad, grouping fino e inhibition.

No modifiques `starter/`. Trabaja en `solution/` que debes crear.
