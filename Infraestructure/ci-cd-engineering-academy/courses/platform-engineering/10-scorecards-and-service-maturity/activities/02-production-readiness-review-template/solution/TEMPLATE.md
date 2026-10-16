# TEMPLATE — plat-10-02-production-readiness-review-template

> Una **plantilla modelo**. No es la única respuesta correcta — es un ejemplo defendible contra el que compararte.

---

## PRR-TEMPLATE.md (modelo)

```markdown
# Production Readiness Review — <nombre-servicio>

> Esta PRR **no repite** los chequeos del scorecard. Los cita.
> El bloqueo técnico para producción vive en el scorecard, no en una firma humana aquí.

## 1. Resumen y estado en el scorecard

- **Servicio:** <component:default/nombre>
- **Owner:** <team-x>
- **Dominio / Tier:** <payments / tier-1>
- **Scorecard:** <enlace a Backstage o herramienta equivalente>
- **Nivel actual:** silver
- **Gap al siguiente nivel (gold):** 2 chequeos — `no-critical-cves`, `psa-restricted`.

## 2. Dependencias

### 2.1 Upstream (de quién depende)

| Dependencia | Tipo | Qué pasa si cae | Tolerancia |
|---|---|---|---|
| postgres-pagos | DB stateful | lecturas y escrituras caen | 0 min |
| auth-service   | servicio interno | login falla, cola retiene | 5 min |
| stripe         | SaaS externo | payment failed; se degrada a pending | 15 min |

### 2.2 Downstream (quién depende de nosotros)

| Consumidor | Impacto si caemos |
|---|---|
| checkout-ui | no se puede completar compra |
| fraud-detector | pierde señal de contexto; sigue funcionando degradado |

## 3. Modos de fallo

| # | Modo | Detección | Blast radius |
|---|---|---|---|
| 1 | DB connection pool exhausted | p99 > 2s en `/checkout` + alerta `pool_full` | 100 % del tráfico |
| 2 | Stripe timeout | `payment_failed` metric sube | 20 % del tráfico (reintenta) |
| 3 | Deploy mete regresión | SLO burn rate rápido | 100 % hasta rollback |

## 4. Capacidad y escalado

- **Carga esperada:** 500 RPS steady, picos a 2.5k RPS (Black Friday).
- **Headroom actual:** 3x la carga pico medida.
- **Escalado:** HPA 2–20 réplicas, basado en CPU + requests_per_second.
- **Punto de dolor conocido:** DB al 70 % en Black Friday 2025.

## 5. Rollback y DR

- **Rollback:** `argocd app rollback checkout-api` → ~90 s.
- **RPO:** 5 min (replica streaming).
- **RTO:** 15 min (failover a réplica cross-region).
- **Último ejercicio de DR:** 2026-08-14; failover exitoso, RTO real 11 min.

## 6. Ownership on-call

- **Rotación:** `checkout-primary` en PagerDuty.
- **SLA de respuesta:** 5 min (tier-1).
- **Escalation:** manager de pagos → VP Engineering.
- **Última vez despertados:** 2026-10-02; `pool_full` resuelto en 20 min.

## 7. Archivo y revisión

- **Guardado en:** `services/checkout-api/docs/PRR.md` (repo del servicio).
- **Revisión:** semestral y tras incidente SEV ≥ 2.
- **Nota:** esta PRR **no bloquea el deploy**. El bloqueo técnico vive en el scorecard. Esto es evidencia histórica y ayuda al próximo on-call a entender el servicio.

## 8. (Opcional) Presupuesto / FinOps

- Costo mensual actual AWS: $X.
- Alerta de budget: 120 % del baseline.

## 9. (Opcional) Compliance

- SOC2: aplica, logs retenidos 90 días.
- GDPR: datos de usuario tokenizados en el producer.
```

---

## NOTES.md (modelo)

### Sección A — Qué mide la PRR que el scorecard no puede

1. **Blast radius** de un fallo específico ("si cae stripe, ¿cuánto del tráfico se degrada?").
2. **Opinión** del equipo sobre picos conocidos ("Black Friday rompió el pool en 2025").
3. **Dependencias externas** y su tolerancia operativa (minutos aceptables de caída).
4. **Última evidencia de ejercicio DR** real (vs promesa teórica).
5. **Historia reciente** del on-call (último despertar, patrón detectado).
6. **Modos de fallo priorizados** desde el conocimiento humano del dominio.

### Sección B — Qué mide el scorecard que la PRR no debería repetir

1. **`has-owner`** — la PRR lo cita en su sección 1, no lo re-chequea.
2. **`has-slo`** — enlace a dashboard; la PRR no copia el objetivo.
3. **`has-runbook`** — enlace; la PRR no reproduce el runbook.
4. **`image-signed`** — cita del scorecard; no se re-verifica aquí.
5. **`no-critical-cves`** — se cita como "gap"; la PRR no lista los CVEs.
6. **`psa-restricted`** — igual: cita del estado; no re-chequeo.

### Sección C — Flujo propuesto

```
┌──────────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
│ Scaffold nuevo   │ → │ Catalog & scorecard │ → │ Nivel calculado      │
│ servicio         │   │ automáticos         │   │ (bronze/silver/gold) │
└──────────────────┘   └─────────────────────┘   └──────────┬───────────┘
                                                            │
                                                            ▼
                                              ┌───────────────────────────┐
                                              │ Equipo escribe PRR        │
                                              │ (sec 2–7, cita el score)  │
                                              └───────────┬───────────────┘
                                                          │
                                                          ▼
                                              ┌───────────────────────────┐
                                              │ PRR archivada en el repo  │
                                              │ del servicio              │
                                              └───────────┬───────────────┘
                                                          │
                                                          ▼
                                              ┌───────────────────────────┐
                                              │ Revisión semestral        │
                                              │ o tras incidente SEV ≥ 2  │
                                              └───────────┬───────────────┘
                                                          │
                                     Si baja de silver ◄──┘
                                     se dispara re-revisión.
```

Lectura: la PRR **sigue** al scorecard; nunca lo precede ni lo reemplaza.

## Punto a repetir hasta que suene aburrido

> **El scorecard chequea lo automatizable continuamente. La PRR archiva el conocimiento cualitativo que el scorecard nunca sabrá. Juntos, sin solaparse.**
