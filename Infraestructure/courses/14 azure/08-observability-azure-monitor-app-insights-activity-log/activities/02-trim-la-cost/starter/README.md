# Starter — Plan de reducción de coste del Log Analytics Workspace

Produce bajo `/tmp/az-08-02/`:

1. `cost-trim-plan.md` — plan con las 5 palancas (filtrado de categorías, Basic Logs, Archive, sampling, dailyQuotaGb) + % estimado de ahorro.
2. `diagnostic-settings.json` — ARM con al menos una `category` deshabilitada y `AllMetrics: enabled=false`.
3. `la-cost-queries.kql` — ≥3 queries sobre la tabla `Usage` (`sum(Quantity)`, `by DataType`, `IsBillable == true`).
4. `README-INTENT.md` — intención, hipótesis y menciones a `Diagnostic Settings`, `sampling`, `Basic Logs`, `Archive`.

Consulta `solution/REFERENCE.md` cuando necesites validarte contra el modelo.
