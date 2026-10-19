# REFERENCE — az-08-02 (puntero)

> El contenido semántico de referencia vive en los archivos adjuntos de este `solution/`:
>
> - `cost-trim-plan.md`
> - `diagnostic-settings.json`
> - `la-cost-queries.kql`
> - `README-INTENT.md`
>
> Compara los tuyos con esos después de haber producido tu propia versión.

## Puntos de autoevaluación

- ¿Tu plan cita **las cinco palancas** (filtrado, Basic Logs, Archive, sampling, dailyQuotaGb) con un número de impacto estimado?
- ¿Tu `diagnostic-settings.json` demuestra categorización (al menos una `enabled: false`) y apaga `AllMetrics`?
- ¿Tus queries incluyen top ranking, serie temporal y detección de "agente que creció"?
- ¿`README-INTENT.md` tiene una sección por archivo y menciona `Log Analytics`, `Diagnostic Settings`, `KQL` y la tabla `Usage`?
- ¿No hay ningún GUID real de tenant/suscripción en los archivos?
