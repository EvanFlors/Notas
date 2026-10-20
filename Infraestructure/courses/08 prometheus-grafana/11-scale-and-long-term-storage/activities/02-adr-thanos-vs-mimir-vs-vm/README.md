# Actividad 02 — ADR: Thanos vs Mimir vs VictoriaMetrics

## 1. Identificación

- **ID:** `obs-11-02-adr-thanos-vs-mimir-vs-vm`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `obs-11-scale-and-long-term-storage`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** architecture (independent)

## 2. Contexto

Te contratan como SRE/platform engineer. La organización `ACME Fintech` tiene este punto de partida:

- 1 cluster K8s por región, 3 regiones (`us-east-1`, `eu-west-1`, `ap-south-1`).
- ~800 pods instrumentados hoy; se espera doblar en 12 meses.
- Prometheus actual: 1 por cluster, retención 15 d, ~1.2 M series activas por cluster.
- 3 equipos de producto que piden dashboards segregados y permissions por tenant.
- Presupuesto anual LTS: **≤ 60 k USD/año** (storage + egress + compute).
- Equipo: 2 SRE y 1 platform engineer; comfortable con Helm, principiantes en operar microservicios.
- Compliance: 1 año de retención obligatoria para métricas de pagos (`billing_*`).

Tu entregable es un **ADR (Architecture Decision Record)** que compare **Thanos**, **Grafana Mimir** y **VictoriaMetrics**, elija uno y lo defienda. No se te pide implementar nada; se te pide **decidir y argumentar**.

## 3. Objetivos

Al terminar:
- Articulas 5+ criterios ponderados de decisión.
- Comparas las 3 opciones contra esos criterios con evidencia.
- Estimas coste anual aproximado de la opción elegida para `ACME Fintech`.
- Defines una **retention policy** por resolución (raw / 5m / 1h).
- Diseñas la **estrategia de rollout** (fases, rollback, métricas de éxito).
- Listas 3+ riesgos y mitigaciones.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo.
- Haber reproducido `examples/01-remote-write-to-victoriametrics/`.
- Haber leído los walkthroughs `examples/02-*` y `examples/03-*`.

**Costos**: ninguno (sólo escritura).

## 5. Instrucciones

### 5.1 Punto de partida

Copia el template:

```bash
mkdir -p /tmp/obs11-adr
cp starter/ADR-template.md /tmp/obs11-adr/ADR-001-long-term-metrics-store.md
cd /tmp/obs11-adr
```

### 5.2 Trabajo esperado

Edita `ADR-001-long-term-metrics-store.md` completando **todas** las secciones. No borres los `<!-- TODO -->` sin completarlos; el validador los cuenta.

Las secciones (resumidas):

1. **Contexto** — resume el estado actual de ACME y por qué este ADR existe.
2. **Fuerzas / drivers** — presupuesto, retention de compliance, tamaño de equipo, multi-tenant, multi-región.
3. **Opciones consideradas** — Thanos, Mimir, VictoriaMetrics (y menciona Cortex y por qué queda fuera).
4. **Criterios de decisión ponderados** — mínimo 5, con peso (1-5) y justificación.
5. **Comparación** — tabla de puntuación opción×criterio con totales ponderados.
6. **Decisión** — una opción, en una frase.
7. **Justificación** — por qué, con 3+ razones concretas ligadas a los drivers.
8. **Consecuencias** — qué ganamos, qué perdemos, qué queda abierto.
9. **Retention policy** — raw / 5m / 1h en años.
10. **Estimación de coste** — storage + egress + compute, aprox USD/año.
11. **Rollout plan** — fases, criterios de success y rollback.
12. **Riesgos y mitigaciones** — 3+ pares.

### 5.3 Reglas de calidad

- **Español prosa**, código/flags/URLs en inglés.
- Nada de "copio la tabla del `theory/lesson.md`": las puntuaciones deben estar **ligadas al caso ACME**.
- Las cifras económicas no tienen que ser exactas, pero sí **razonadas** (muestra la fórmula o la fuente).
- La decisión debe ser **una** opción, no "depende".

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/obs11-adr
```

El validador verifica que el ADR existe, pesa ≥ 150 líneas, menciona a las 3 opciones y a Cortex, y que no quedan placeholders `<!-- TODO -->`. Es un check **estructural**, no de calidad; la calidad se evalúa por auto-reflexión (sección 9) y revisión por un peer.

## 6. Resultado esperado

- Archivo `ADR-001-long-term-metrics-store.md` ≥ 150 líneas, bien estructurado, sin TODOs residuales.
- Decisión defendible frente a un VP ingeniería que te pregunte "¿y por qué no la otra opción?".

## 7. Criterios de aceptación

- [ ] 12 secciones completas.
- [ ] Decisión única, no "depende".
- [ ] Tabla de puntuación ponderada presente y numéricamente consistente.
- [ ] Estimación de coste con fórmula visible.
- [ ] Rollout plan con criterios de success + rollback.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs11-adr
```

Chequea:
- Archivo `ADR-001-long-term-metrics-store.md` existe.
- Longitud ≥ 150 líneas.
- Menciona `Thanos`, `Mimir`, `VictoriaMetrics` y `Cortex`.
- 0 ocurrencias de `<!-- TODO -->`.
- Contiene una tabla markdown (al menos una línea con `|---|`).

## 9. Preguntas de reflexión (auto-evaluación)

1. Si el presupuesto se recortara un 50 %, ¿seguiría siendo la misma decisión? ¿Por qué?
2. Si ACME duplicara regiones (de 3 a 6), ¿la decisión aguanta?
3. ¿Cómo migrarías de la opción elegida a otra si en 2 años cambia el contexto?
4. ¿Qué métrica concreta vigilarías para detectar que el LTS "se está quedando pequeño"?
5. ¿Qué parte del ADR cambiaría si ACME tuviera 10 SRE en vez de 2?

## 10. Extensiones (opcional)

- **E1** — Escribe un **mini runbook** de 1 página para "la cola de `remote_write` está desbordando".
- **E2** — Añade al ADR una comparación con **Grafana Cloud** (SaaS) y defiende por qué sí o por qué no.
- **E3** — Modela el **coste a 3 años** asumiendo crecimiento del 50 % anual.
- **E4** — Hazte revisar el ADR por un peer y añade un *appendix* con las objeciones y tu respuesta.

## 11. Limpieza

```bash
rm -rf /tmp/obs11-adr
```
