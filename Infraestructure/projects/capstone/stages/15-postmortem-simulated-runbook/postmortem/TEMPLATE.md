# Postmortem — &lt;INC-YYYY-MMDD-NN&gt; &lt;título corto&gt;

> Plantilla **blameless** basada en Google SRE Workbook (cap. 10).
> Rellena todas las secciones; si una no aplica, escribe `N/A` y por qué.
> Prohibido nombrar a personas en términos de culpa — usa roles o sistemas.

---

## 1. Summary

Dos párrafos, máximo. ¿Qué pasó, cuándo, cómo se mitigó, qué impacto tuvo?
Escrito para que alguien que no estuvo pueda entenderlo en 60 segundos.

- **Severity:** SEV-? (?)
- **Status:** Mitigated / Resolved / Monitoring
- **Owner del postmortem:** &lt;rol o equipo&gt;
- **Fecha del incidente:** YYYY-MM-DD
- **Fecha del postmortem:** YYYY-MM-DD
- **Duración detectada → mitigada:** HH:MM

## 2. Impact

Cuantificado, no narrativo.

- Usuarios afectados: &lt;número o %&gt;
- Requests fallidas: &lt;número o %&gt;
- Revenue / coste: &lt;$ o N/A con justificación&gt;
- SLO burn: &lt;% de error budget consumido&gt;
- Datos perdidos / corruptos: &lt;sí/no + descripción&gt;

## 3. Timeline (UTC)

Formato tabular. Un evento por fila. Mínimo 6 filas.

| Hora (UTC) | Evento | Fuente |
|---|---|---|
| HH:MM | &lt;qué pasó&gt; | &lt;alerta/dashboard/log/persona&gt; |
| HH:MM | ... | ... |

## 4. Detection

- ¿Qué alerta disparó? (nombre exacto, severidad)
- ¿Fue proactiva (alerta) o reactiva (reporte de usuario)?
- *Time to detect* desde el inicio real del impacto: `?? min`.
- Si fue reactiva, ¿por qué no había alerta?

## 5. Trigger

El evento concreto que **inició** el incidente. No es lo mismo que la *root cause*.

Ejemplo: "Deploy de la versión X.Y.Z a las 13:45 UTC". El deploy en sí no es la causa raíz,
pero sin él no habría pasado.

## 6. Root cause

Formato *5 whys* o cadena causal. Mínimo dos niveles de "porque".

- Síntoma: &lt;qué vieron los usuarios&gt;
- Porque 1: &lt;...&gt;
- Porque 2: &lt;...&gt;
- Porque N (causa raíz técnica): &lt;...&gt;
- Causa raíz de proceso (opcional pero recomendado): &lt;qué proceso debería haberlo prevenido&gt;

## 7. Resolution

Pasos concretos que **mitigaron** el impacto, en orden. Incluye comandos reales si existen.

1. &lt;...&gt;
2. &lt;...&gt;

Diferencia entre *mitigation* (paró el sangrado) y *fix* (resuelve causa raíz).
Marca cuál fue cuál.

## 8. What went well

Entre 3 y 5 puntos. Es tan importante como "what went wrong".

- &lt;...&gt;

## 9. What went wrong

Entre 3 y 5 puntos. En términos de sistema / proceso, nunca de persona.

- &lt;...&gt;

## 10. Where we got lucky

Opcional pero muy útil: cosas que podrían haber empeorado el incidente y no lo hicieron
por azar, no por diseño. Son candidatos directos a *action items*.

## 11. Action items

Tabla. Cada ítem con dueño (rol o equipo), tipo (`corrective | preventive | detective`),
severidad (`P0 | P1 | P2`), due date y link al ticket.

| ID | Descripción | Tipo | Severidad | Owner | Due |
|---|---|---|---|---|---|
| AI-01 | &lt;...&gt; | corrective | P0 | &lt;equipo&gt; | YYYY-MM-DD |
| AI-02 | &lt;...&gt; | preventive | P1 | &lt;equipo&gt; | YYYY-MM-DD |

Al menos **uno** debe ser *preventive* (reduce probabilidad futura, no solo repara daño).

## 12. Lessons learned

Dos o tres párrafos. ¿Qué aprendimos como equipo? ¿Qué asumíamos que ya no asumimos?
No "fuimos buenos / fuimos malos" — qué *modelo mental* cambió.

## 13. Supporting data

Enlaces a:

- Dashboards (snapshot URL con tiempo congelado).
- Queries PromQL/LogQL ejecutadas (texto completo).
- PRs relacionados.
- Logs crudos relevantes (hashes o paths, no secretos).

---

## Checklist antes de publicar

- [ ] Ningún nombre propio en términos de culpa.
- [ ] Timeline ≥ 6 eventos con `HH:MM`.
- [ ] Impact cuantificado (no "muchos usuarios").
- [ ] ≥ 3 action items, cada uno con owner y due date, ≥ 1 preventive.
- [ ] Root cause llega a nivel de proceso, no solo técnico.
- [ ] Enlaces a dashboards y queries, no capturas sueltas.
