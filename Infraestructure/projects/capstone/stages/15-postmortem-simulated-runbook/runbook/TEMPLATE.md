# Runbook — &lt;síntoma / título&gt;

> Un runbook arranca con el **síntoma** que verá la guardia, no con la causa.
> Si quien lo lee no reconoce el síntoma en los primeros 30 segundos, el runbook falla.
> Escrito para que un ingeniero que **no vivió el incidente** lo pueda ejecutar.

---

## Metadata

| Campo | Valor |
|---|---|
| Runbook ID | `RB-&lt;slug&gt;` |
| Última revisión | YYYY-MM-DD |
| Owner | &lt;rol o equipo&gt; |
| Services afectados | &lt;svc1, svc2&gt; |
| Severity típica | SEV-? |
| Postmortems relacionados | &lt;INC-...&gt; |

## 1. Symptoms

¿Cómo reconozco que **este** runbook es el correcto? Lista precisa de señales.

- Alerta disparada: `&lt;nombre exacto de la alerta&gt;`.
- Dashboard primario donde se ve: `&lt;link o path&gt;`.
- Patrón de métricas: &lt;p.ej. "latencia sube bruscamente, error rate sube con retraso"&gt;.
- Patrón de logs: &lt;texto literal clave para grep/LogQL&gt;.
- Qué **no** es (desambiguación con otros runbooks parecidos):
  - Si ves X además, es el runbook `&lt;otro-slug&gt;`.
  - Si ves Y, probablemente es el runbook `&lt;otro-slug&gt;`.

## 2. Diagnostics

Pruebas **rápidas** y **ordenadas** para confirmar que es este incidente antes de mitigar.
Cada paso debe:

- ser un comando ejecutable (no "revisa X"),
- tener un *expected* vs *bad* claros,
- tomar &lt; 60 s en resolverse.

### Diagnóstico 1 — &lt;nombre corto&gt;

```bash
&lt;comando exacto&gt;
```

- Expected: &lt;...&gt;.
- Bad: &lt;...&gt; (si ves esto, confirmado — pasa a Mitigations).

### Diagnóstico 2 — &lt;nombre corto&gt;

```bash
&lt;comando exacto&gt;
```

### Diagnóstico 3 — Descartes rápidos

Antes de mitigar, descarta en 1 min cada una de estas falsas pistas típicas:

- &lt;falsa pista 1 y cómo descartarla&gt;.
- &lt;falsa pista 2 y cómo descartarla&gt;.

## 3. Mitigations

Pasos **en orden**, del menos invasivo al más invasivo. Para cada uno:

- impacto esperado,
- tiempo esperado hasta ver efecto,
- qué NO hacer (anti-patrones observados en incidentes previos).

### Mitigación 1 — &lt;menos invasiva&gt;

```bash
&lt;comando&gt;
```

- Impacto: &lt;...&gt;.
- Efecto visible en: &lt;p.ej. "90 s en el panel X"&gt;.
- No hagas: &lt;...&gt;.

### Mitigación 2 — &lt;más invasiva&gt;

&lt;...&gt;

### Mitigación 3 — Last resort

&lt;p.ej. "poner el servicio en modo mantenimiento global"&gt;.

## 4. Escalation

- **¿Cuándo escalar?** Criterio cuantitativo (ej.: "si tras aplicar Mitigación 2 el
  síntoma persiste > 10 min").
- **¿A quién?** Rol / rotación, no persona.
  - L2: `&lt;equipo&gt;`.
  - L3 (DBA / vendor / plataforma): `&lt;equipo&gt;`.
- **Canal:** `&lt;slack / pager&gt;`.
- **Qué contexto llevar al escalar:** lista mínima (timeline hasta ahora, mitigaciones
  intentadas, dashboards abiertos).

## 5. Recovery

Pasos para pasar de *mitigado* a *resuelto definitivamente*. A diferencia de las
mitigaciones (que paran el sangrado), estos atacan la causa raíz.

- &lt;p.ej. "merge del índice en migración Alembic + deploy en ventana baja de tráfico"&gt;.
- &lt;p.ej. "re-habilitar feature flag en 10 % de tráfico vía Argo Rollouts"&gt;.

## 6. Verification

¿Cómo sé que **ya terminé**? Criterios *verificables*, no sensaciones.

- [ ] Alerta `&lt;...&gt;` resuelta en Alertmanager (no silenciada).
- [ ] p95 vuelve a &lt; X ms sostenido 10 min en el dashboard `&lt;...&gt;`.
- [ ] Error rate &lt; Y % sostenido 10 min.
- [ ] &lt;Chequeo específico del incidente, ej.: "connections in use &lt; 30 por réplica"&gt;.
- [ ] Comunicación: status page a Operational, war-room cerrado, resumen al stakeholder.

## 7. Post-incident

- [ ] Abrir el postmortem desde `postmortem/TEMPLATE.md` en &lt; 24 h.
- [ ] Revisar este runbook: ¿algún paso faltó, sobró o estuvo mal ordenado?
- [ ] Actualizar la sección de "What went wrong" del postmortem con hallazgos
      del propio runbook.

---

## Changelog del runbook

| Fecha | Autor | Cambio |
|---|---|---|
| YYYY-MM-DD | &lt;rol&gt; | Creado tras INC-... |
